<?php

namespace App\Http\Controllers\Api;

use App\Models\Application;
use App\Models\ApplicationStatusHistory;
use App\Models\AuditLog;
use App\Models\Job;
use App\Models\Notification;
use App\Services\ApplicationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ApplicationController extends BaseApiController
{
    public function __construct(
        protected ApplicationService $applicationService
    ) {}

    /**
     * Submit an application.
     */
    public function store(Request $request, int $jobId): JsonResponse
    {
        $user = $request->user();
        $profile = $user->jobSeekerProfile ?? \App\Models\JobSeekerProfile::firstOrCreate(['user_id' => $user->id]);

        if (!$profile) {
            return $this->errorResponse('Job seeker profile required to apply.', 403);
        }

        // Handle uploaded CV file or auto-resolve document if not explicitly passed
        if ($request->hasFile('cv_file')) {
            try {
                $docService = app(\App\Services\DocumentService::class);
                $uploadedDoc = $docService->uploadDocument($user, $request->file('cv_file'), 'cv');
                $request->merge(['cv_document_id' => $uploadedDoc->id]);
            } catch (\Throwable $e) {
                return $this->errorResponse('Failed to upload CV document: ' . $e->getMessage(), 422);
            }
        } elseif (!$request->filled('cv_document_id')) {
            $existingDoc = \App\Models\Document::where('user_id', $user->id)
                ->whereIn('document_type', ['cv', 'resume', 'other'])
                ->latest()
                ->first();

            if ($existingDoc) {
                $request->merge(['cv_document_id' => $existingDoc->id]);
            } else {
                // Auto-generate text CV from request or profile
                $resumeContent = $request->input('resume_text');
                if (empty($resumeContent)) {
                    $resumeContent = "=== CURRICULUM VITAE ===\n" .
                        "Name: " . $user->name . "\n" .
                        "Email: " . $user->email . "\n" .
                        "Phone: " . ($user->phone ?? 'N/A') . "\n" .
                        "Headline: " . ($profile->headline ?? 'Job Seeker') . "\n" .
                        "Bio: " . ($profile->bio ?? '') . "\n";
                }

                $filename = 'Profile_CV_' . time() . '.txt';
                $storagePath = 'documents/' . $user->id . '/' . \Illuminate\Support\Str::uuid() . '.txt';
                \Illuminate\Support\Facades\Storage::disk('private')->makeDirectory('documents/' . $user->id);
                \Illuminate\Support\Facades\Storage::disk('private')->put($storagePath, $resumeContent);

                $newDoc = \App\Models\Document::create([
                    'user_id' => $user->id,
                    'original_name' => $filename,
                    'storage_path' => $storagePath,
                    'mime_type' => 'text/plain',
                    'file_size' => strlen($resumeContent),
                    'document_type' => 'cv',
                ]);

                $request->merge(['cv_document_id' => $newDoc->id]);
            }
        } else {
            // Verify CV document belongs to the authenticated applicant
            $doc = \App\Models\Document::find($request->input('cv_document_id'));
            if ($doc && $doc->user_id !== $user->id && !$user->isAdmin()) {
                return $this->errorResponse('Access denied. The specified CV document does not belong to your account.', 403);
            }
        }

        $validated = $request->validate([
            'cv_document_id' => 'required|integer|exists:documents,id',
            'cover_letter' => 'nullable|string',
            'screening_answers' => 'nullable|array',
            'screening_answers.*.question_id' => 'required_with:screening_answers|integer',
            'screening_answers.*.answer' => 'required_with:screening_answers|boolean',
        ]);

        try {
            $application = $this->applicationService->submitApplication(
                $profile,
                $jobId,
                $validated['cv_document_id'],
                $validated['cover_letter'] ?? null,
                $validated['screening_answers'] ?? []
            );

            return $this->successResponse($application, 'Application submitted successfully.', 201);
        } catch (\Illuminate\Validation\ValidationException $e) {
            $firstError = $e->validator->errors()->first();
            return $this->errorResponse($firstError ?: 'Unable to submit application.', 422, $e->errors());
        } catch (\Illuminate\Database\UniqueConstraintViolationException | \Illuminate\Database\QueryException $e) {
            return $this->errorResponse('You have already applied for this vacancy.', 409);
        }
    }

    /**
     * List current user's submitted applications.
     */
    public function index(Request $request): JsonResponse
    {
        $profile = $request->user()->jobSeekerProfile ?? \App\Models\JobSeekerProfile::firstOrCreate(['user_id' => $request->user()->id]);
        if (!$profile) {
            return $this->successResponse([], 'No job seeker profile.');
        }

        $applications = Application::where('profile_id', $profile->id)
            ->with(['job.employer', 'cvDocument', 'statusHistories.changedBy'])
            ->latest('applied_at')
            ->get();

        return $this->successResponse($applications, 'Applications retrieved successfully.');
    }

    /**
     * View single application details.
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $application = Application::with(['job.employer', 'profile.user', 'profile.skills', 'cvDocument', 'statusHistories.changedBy'])->findOrFail($id);
        $user = $request->user();

        // Check permission: applicant or job owner employer or admin
        $isApplicant = $application->profile->user_id === $user->id;
        $isEmployer = $user->employers->contains('id', $application->job->employer_id);
        $isAdmin = $user->isAdmin();

        if (!$isApplicant && !$isEmployer && !$isAdmin) {
            return $this->errorResponse('Unauthorized to view this application.', 403);
        }

        return $this->successResponse($application, 'Application details retrieved.');
    }

    /**
     * Update application status (Employer or Admin).
     */
    public function updateStatus(Request $request, int $id): JsonResponse
    {
        $application = Application::with('job')->findOrFail($id);
        $user = $request->user();

        $isEmployer = $user->employers->contains('id', $application->job->employer_id);
        if (!$isEmployer && !$user->isAdmin()) {
            return $this->errorResponse('Unauthorized to update application status.', 403);
        }

        $validated = $request->validate([
            'status' => 'required|string|in:submitted,under_review,shortlisted,interview,accepted,rejected,withdrawn',
            'notes' => 'nullable|string',
        ]);

        $updated = $this->applicationService->updateStatus(
            $application,
            $validated['status'],
            $user,
            $validated['notes'] ?? null
        );

        return $this->successResponse($updated, 'Application status updated successfully.');
    }

    /**
     * Withdraw application (Applicant only).
     */
    public function withdraw(Request $request, int $id): JsonResponse
    {
        $application = Application::with('profile')->findOrFail($id);
        $user = $request->user();

        if ($application->profile->user_id !== $user->id && !$user->isAdmin()) {
            return $this->errorResponse('Unauthorized to withdraw this application.', 403);
        }

        $withdrawn = $this->applicationService->withdraw($application, $user);

        return $this->successResponse($withdrawn, 'Application withdrawn successfully.');
    }

    /**
     * Schedule / Book an interview (Employer or Admin).
     */
    public function scheduleInterview(Request $request, int $id): JsonResponse
    {
        $application = Application::with('job.employer')->findOrFail($id);
        $user = $request->user();

        $isEmployer = $user->employers->contains('id', $application->job->employer_id);
        if (!$isEmployer && !$user->isAdmin()) {
            return $this->errorResponse('Unauthorized to schedule an interview for this vacancy.', 403);
        }

        $validated = $request->validate([
            'interview_at' => 'required|date',
            'interview_type' => 'required|string|in:in_person,video,phone',
            'interview_location' => 'required|string|max:255',
            'interview_notes' => 'nullable|string',
        ]);

        $updated = $this->applicationService->scheduleInterview($application, $validated, $user);

        return $this->successResponse($updated, 'Interview scheduled successfully.');
    }

    /**
     * Confirm interview attendance (Candidate).
     */
    public function confirmInterview(Request $request, int $id): JsonResponse
    {
        $application = Application::with(['profile', 'job.employer'])->findOrFail($id);
        $user = $request->user();

        if ($application->profile->user_id !== $user->id && !$user->isAdmin()) {
            return $this->errorResponse('Unauthorized. Only the candidate can confirm attendance.', 403);
        }

        $updated = $this->applicationService->confirmInterview($application, $user);

        return $this->successResponse($updated, 'Interview attendance confirmed.');
    }

    /**
     * Reschedule interview request (Candidate or Employer).
     */
    public function rescheduleInterview(Request $request, int $id): JsonResponse
    {
        $application = Application::with(['profile', 'job.employer'])->findOrFail($id);
        $user = $request->user();

        $isApplicant = $application->profile->user_id === $user->id;
        $isEmployer = $user->employers->contains('id', $application->job->employer_id);
        if (!$isApplicant && !$isEmployer && !$user->isAdmin()) {
            return $this->errorResponse('Unauthorized.', 403);
        }

        $validated = $request->validate([
            'interview_at' => 'nullable|date',
            'interview_notes' => 'nullable|string',
            'reason' => 'nullable|string',
        ]);

        $updated = $this->applicationService->rescheduleInterview($application, $validated, $user);

        return $this->successResponse($updated, 'Interview reschedule recorded.');
    }

    /**
     * Issue a formal job offer to candidate (Section 11 - Employer).
     */
    public function createOffer(Request $request, int $id): JsonResponse
    {
        $application = Application::with(['profile.user', 'job.employer'])->findOrFail($id);
        $user = $request->user();

        $isEmployer = $user->employers->contains('id', $application->job->employer_id);
        if (!$isEmployer && !$user->isAdmin()) {
            return $this->errorResponse('Unauthorized. Only the job employer can issue a formal offer.', 403);
        }

        $validated = $request->validate([
            'offer_salary' => 'required|numeric|min:0',
            'offer_benefits' => 'nullable|string',
            'offer_conditions' => 'nullable|string',
            'offer_start_date' => 'required|date',
            'offer_notes' => 'nullable|string',
        ]);

        $oldStatus = $application->status;
        $application->update([
            'offer_salary' => $validated['offer_salary'],
            'offer_benefits' => $validated['offer_benefits'] ?? null,
            'offer_conditions' => $validated['offer_conditions'] ?? null,
            'offer_start_date' => $validated['offer_start_date'],
            'offer_notes' => $validated['offer_notes'] ?? null,
            'offer_status' => 'offered',
            'offered_at' => now(),
            'status' => 'offered',
        ]);

        ApplicationStatusHistory::create([
            'application_id' => $application->id,
            'changed_by' => $user->id,
            'old_status' => $oldStatus,
            'new_status' => 'offered',
            'notes' => 'Formal employment offer issued to candidate.',
        ]);

        // Notify candidate
        if ($application->profile && $application->profile->user_id) {
            Notification::create([
                'user_id' => $application->profile->user_id,
                'title' => 'Formal Job Offer Received! 🎉',
                'message' => "Congratulations! {$application->job->employer->organization_name} has extended an official employment offer for {$application->job->title}.",
                'notification_type' => 'job_offer',
                'is_read' => false,
            ]);
        }

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'job_offer_issued',
            'entity_type' => 'Application',
            'entity_id' => $application->id,
            'description' => "Job offer issued for application #{$application->id} ({$application->job->title}).",
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        return $this->successResponse($application->fresh(['job.employer', 'profile.user']), 'Job offer issued successfully.');
    }

    /**
     * View formal job offer details (Section 11).
     */
    public function offerDetails(Request $request, int $id): JsonResponse
    {
        $application = Application::with(['job.employer', 'profile.user'])->findOrFail($id);
        $user = $request->user();

        $isApplicant = $application->profile->user_id === $user->id;
        $isEmployer = $user->employers->contains('id', $application->job->employer_id);
        if (!$isApplicant && !$isEmployer && !$user->isAdmin()) {
            return $this->errorResponse('Unauthorized to view this offer.', 403);
        }

        return $this->successResponse([
            'application_id' => $application->id,
            'job_id' => $application->job->id,
            'job_title' => $application->job->title,
            'company_name' => $application->job->employer?->organization_name,
            'candidate_name' => $application->profile?->user?->name,
            'offer_salary' => $application->offer_salary,
            'offer_benefits' => $application->offer_benefits,
            'offer_conditions' => $application->offer_conditions,
            'offer_start_date' => $application->offer_start_date?->format('Y-m-d'),
            'offer_status' => $application->offer_status,
            'offer_notes' => $application->offer_notes,
            'candidate_response_notes' => $application->candidate_response_notes,
            'offered_at' => $application->offered_at,
            'offer_responded_at' => $application->offer_responded_at,
        ], 'Job offer details retrieved.');
    }

    /**
     * Respond to a formal job offer (Candidate: accept, decline, request clarification).
     */
    public function respondOffer(Request $request, int $id): JsonResponse
    {
        $application = Application::with(['job.employer.members.user', 'profile.user'])->findOrFail($id);
        $user = $request->user();

        if ($application->profile->user_id !== $user->id && !$user->isAdmin()) {
            return $this->errorResponse('Unauthorized. Only the applicant can respond to the job offer.', 403);
        }

        if ($application->offer_status === 'none') {
            return $this->errorResponse('No active job offer exists for this application.', 400);
        }

        if (in_array($application->offer_status, ['accepted', 'declined'])) {
            return $this->errorResponse("This job offer has already been {$application->offer_status}.", 422);
        }

        if ($application->offer_start_date && now()->startOfDay()->gt($application->offer_start_date->startOfDay())) {
            return $this->errorResponse('This job offer has expired past its proposed start date.', 422);
        }

        $validated = $request->validate([
            'action' => 'required|string|in:accepted,declined,clarification_requested',
            'notes' => 'nullable|string',
        ]);

        $action = $validated['action'];
        $notes = $validated['notes'] ?? null;
        $oldStatus = $application->status;

        $newAppStatus = match ($action) {
            'accepted' => 'accepted',
            'declined' => 'rejected',
            default => 'offered',
        };

        $application->update([
            'offer_status' => $action,
            'candidate_response_notes' => $notes,
            'offer_responded_at' => now(),
            'status' => $newAppStatus,
        ]);

        ApplicationStatusHistory::create([
            'application_id' => $application->id,
            'changed_by' => $user->id,
            'old_status' => $oldStatus,
            'new_status' => $newAppStatus,
            'notes' => "Candidate responded to offer: {$action}. Notes: {$notes}",
        ]);

        // Notify employer members
        if ($application->job->employer && $application->job->employer->members->isNotEmpty()) {
            foreach ($application->job->employer->members as $member) {
                if ($member->user) {
                    Notification::create([
                        'user_id' => $member->user->id,
                        'title' => "Job Offer Update: {$application->job->title}",
                        'message' => "Candidate {$user->name} has {$action} the formal job offer." . ($notes ? " Notes: {$notes}" : ''),
                        'notification_type' => 'offer_response',
                        'is_read' => false,
                    ]);
                }
            }
        }

        return $this->successResponse($application->fresh(), "Offer response '{$action}' recorded successfully.");
    }
}
