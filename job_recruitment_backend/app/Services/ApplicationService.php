<?php

namespace App\Services;

use App\Models\Application;
use App\Models\ApplicationStatusHistory;
use App\Models\Document;
use App\Models\Job;
use App\Models\JobSeekerProfile;
use App\Models\Notification;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ApplicationService
{
    /**
     * Submit an application enforcing rules:
     * - DBR-008: duplicate validation
     * - DBR-011: CV document ownership
     * - DBR-014: non-expired, active vacancy
     */
    public function submitApplication(JobSeekerProfile $profile, int $jobId, int $cvDocumentId, ?string $coverLetter = null, array $screeningAnswers = []): Application
    {
        $job = Job::with('screeningQuestions')->findOrFail($jobId);

        if ($job->status !== 'published') {
            throw ValidationException::withMessages([
                'job' => ['This vacancy is not open for applications.'],
            ]);
        }

        if ($job->deadline < now()->toDateString()) {
            throw ValidationException::withMessages([
                'deadline' => ['The application deadline for this job has expired.'],
            ]);
        }

        // Prevent duplicate application
        $exists = Application::where('job_id', $jobId)
            ->where('profile_id', $profile->id)
            ->exists();

        if ($exists) {
            throw ValidationException::withMessages([
                'application' => ['You have already applied for this vacancy.'],
            ]);
        }

        // Validate CV belongs to applicant's user account
        $cv = Document::where('id', $cvDocumentId)
            ->where('user_id', $profile->user_id)
            ->first();

        if (!$cv) {
            throw ValidationException::withMessages([
                'cv_document_id' => ['The specified CV document does not exist or does not belong to your account.'],
            ]);
        }

        return DB::transaction(function () use ($job, $profile, $cvDocumentId, $coverLetter, $screeningAnswers) {
            $questions = $job->screeningQuestions ?? collect();
            $knockedOut = false;
            $status = 'submitted';
            $statusNote = 'Application submitted by candidate.';

            // Check knockout criteria
            foreach ($questions as $q) {
                $userAns = null;
                foreach ($screeningAnswers as $ans) {
                    if (isset($ans['question_id']) && $ans['question_id'] == $q->id) {
                        $userAns = filter_var($ans['answer'] ?? false, FILTER_VALIDATE_BOOLEAN);
                        break;
                    }
                }

                if ($userAns !== null && $q->is_knockout) {
                    if ($userAns !== (bool)$q->expected_boolean) {
                        $knockedOut = true;
                    }
                }
            }

            if ($knockedOut) {
                $status = 'rejected';
                $statusNote = 'Application auto-routed to disqualified pipeline based on knockout screening criteria.';
            }

            $application = Application::create([
                'job_id' => $job->id,
                'profile_id' => $profile->id,
                'cv_document_id' => $cvDocumentId,
                'cover_letter' => $coverLetter,
                'status' => $status,
                'applied_at' => now(),
            ]);

            ApplicationStatusHistory::create([
                'application_id' => $application->id,
                'changed_by' => $profile->user_id,
                'old_status' => null,
                'new_status' => $status,
                'notes' => $statusNote,
            ]);

            // Save screening answers
            foreach ($questions as $q) {
                $userAns = null;
                foreach ($screeningAnswers as $ans) {
                    if (isset($ans['question_id']) && $ans['question_id'] == $q->id) {
                        $userAns = filter_var($ans['answer'] ?? false, FILTER_VALIDATE_BOOLEAN);
                        break;
                    }
                }

                if ($userAns !== null) {
                    \App\Models\ApplicationScreeningAnswer::create([
                        'application_id' => $application->id,
                        'question_id' => $q->id,
                        'answer_boolean' => $userAns,
                        'passed' => ($userAns === (bool)$q->expected_boolean),
                    ]);
                }
            }

            // Notify employer members
            $employerMembers = $job->employer->users;
            foreach ($employerMembers as $member) {
                Notification::create([
                    'user_id' => $member->id,
                    'title' => 'New Applicant: ' . $job->title,
                    'message' => "A new applicant ({$profile->user->name}) submitted an application for {$job->title}.",
                    'notification_type' => 'application_received',
                    'is_read' => false,
                ]);
            }

            return $application->load(['job.employer', 'cvDocument', 'profile.user', 'screeningAnswers']);
        });
    }

    /**
     * Update application recruitment status (e.g., shortlisted, interview, accepted, rejected).
     */
    public function updateStatus(Application $application, string $newStatus, User $actor, ?string $notes = null): Application
    {
        $validStatuses = ['submitted', 'under_review', 'shortlisted', 'interview', 'accepted', 'rejected', 'withdrawn'];
        if (!in_array($newStatus, $validStatuses)) {
            throw ValidationException::withMessages(['status' => ['Invalid application status.']]);
        }

        return DB::transaction(function () use ($application, $newStatus, $actor, $notes) {
            $oldStatus = $application->status;
            $application->status = $newStatus;
            $application->save();

            ApplicationStatusHistory::create([
                'application_id' => $application->id,
                'changed_by' => $actor->id,
                'old_status' => $oldStatus,
                'new_status' => $newStatus,
                'notes' => $notes ?? "Status updated to {$newStatus}.",
            ]);

            // Notify candidate
            $candidateUser = $application->profile->user;
            if ($candidateUser) {
                Notification::create([
                    'user_id' => $candidateUser->id,
                    'title' => "Application Update: {$application->job->title}",
                    'message' => "Your application status for {$application->job->title} has been updated to: " . strtoupper($newStatus),
                    'notification_type' => 'status_change',
                    'is_read' => false,
                ]);
            }

            return $application->load(['job.employer', 'statusHistories.changedBy']);
        });
    }

    /**
     * Withdraw application by candidate.
     */
    public function withdraw(Application $application, User $user): Application
    {
        if ($application->profile->user_id !== $user->id) {
            throw ValidationException::withMessages(['unauthorized' => ['You can only withdraw your own applications.']]);
        }

        if ($application->status === 'withdrawn') {
            throw ValidationException::withMessages(['status' => ['Application is already withdrawn.']]);
        }

        return $this->updateStatus($application, 'withdrawn', $user, 'Application withdrawn by applicant.');
    }

    /**
     * Schedule / Book an interview for an applicant.
     */
    public function scheduleInterview(Application $application, array $data, User $actor): Application
    {
        return DB::transaction(function () use ($application, $data, $actor) {
            $oldStatus = $application->status;
            $application->status = 'interview';
            $application->interview_at = $data['interview_at'];
            $application->interview_type = $data['interview_type'] ?? 'video';
            $application->interview_location = $data['interview_location'] ?? 'Online Meeting';
            $application->interview_notes = $data['interview_notes'] ?? null;
            $application->interview_status = 'scheduled';
            $application->save();

            ApplicationStatusHistory::create([
                'application_id' => $application->id,
                'changed_by' => $actor->id,
                'old_status' => $oldStatus,
                'new_status' => 'interview',
                'notes' => "Interview scheduled for {$data['interview_at']} ({$application->interview_type}). Note: {$application->interview_notes}",
            ]);

            // Notify candidate
            $candidateUser = $application->profile->user;
            if ($candidateUser) {
                Notification::create([
                    'user_id' => $candidateUser->id,
                    'title' => "Interview Invitation: {$application->job->title}",
                    'message' => "You have been invited to an interview for {$application->job->title} on {$data['interview_at']}. Location/Link: {$application->interview_location}",
                    'notification_type' => 'interview_scheduled',
                    'is_read' => false,
                ]);
            }

            return $application->fresh(['job.employer', 'statusHistories.changedBy', 'cvDocument']);
        });
    }

    /**
     * Confirm attendance for scheduled interview.
     */
    public function confirmInterview(Application $application, User $user): Application
    {
        if ($application->profile->user_id !== $user->id) {
            throw ValidationException::withMessages(['unauthorized' => ['Only the candidate can confirm attendance.']]);
        }

        $application->interview_status = 'confirmed';
        $application->save();

        ApplicationStatusHistory::create([
            'application_id' => $application->id,
            'changed_by' => $user->id,
            'old_status' => $application->status,
            'new_status' => $application->status,
            'notes' => 'Candidate confirmed attendance for scheduled interview.',
        ]);

        // Notify employer members
        foreach ($application->job->employer->users as $member) {
            Notification::create([
                'user_id' => $member->id,
                'title' => "Interview Confirmed: {$application->profile->user->name}",
                'message' => "Candidate {$application->profile->user->name} has confirmed attendance for the {$application->job->title} interview.",
                'notification_type' => 'interview_confirmed',
                'is_read' => false,
            ]);
        }

        return $application->fresh(['job.employer', 'statusHistories.changedBy', 'cvDocument']);
    }

    /**
     * Reschedule interview request.
     */
    public function rescheduleInterview(Application $application, array $data, User $actor): Application
    {
        $application->interview_status = 'rescheduled';
        if (!empty($data['interview_at'])) {
            $application->interview_at = $data['interview_at'];
        }
        if (!empty($data['interview_notes'])) {
            $application->interview_notes = $data['interview_notes'];
        }
        $application->save();

        ApplicationStatusHistory::create([
            'application_id' => $application->id,
            'changed_by' => $actor->id,
            'old_status' => $application->status,
            'new_status' => $application->status,
            'notes' => "Interview reschedule requested: " . ($data['reason'] ?? $data['interview_notes'] ?? 'Time conflict'),
        ]);

        return $application->fresh(['job.employer', 'statusHistories.changedBy', 'cvDocument']);
    }
}
