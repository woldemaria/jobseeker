<?php

namespace App\Http\Controllers\Api;

use App\Models\Application;
use App\Models\ApplicationStatusHistory;
use App\Models\AuditLog;
use App\Models\Job;
use App\Models\Notification;
use App\Models\User;
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

        $resolution = $this->resolveCvDocument($request, $user, $profile);
        if ($resolution instanceof JsonResponse) {
            return $resolution;
        }
        $request->merge(['cv_document_id' => $resolution]);

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
     * Resolve the CV document to attach to an application.
     *
     * Handles, in order of precedence: an explicitly uploaded CV file, an explicitly
     * referenced cv_document_id (with ownership verification), the applicant's most
     * recent existing document, and finally an auto-generated text CV built from the
     * request payload or the applicant's profile.
     *
     * @return \Illuminate\Http\JsonResponse|int Either the resolved document id, or an error response.
     */
    private function resolveCvDocument(Request $request, $user, \App\Models\JobSeekerProfile $profile): mixed
    {
        // Handle uploaded CV file or auto-resolve document if not explicitly passed
        if ($request->hasFile('cv_file')) {
            try {
                $docService = app(\App\Services\DocumentService::class);
                $uploadedDoc = $docService->uploadDocument($user, $request->file('cv_file'), 'cv');
                return $uploadedDoc->id;
            } catch (\Throwable $e) {
                return $this->errorResponse('Failed to upload CV document: ' . $e->getMessage(), 422);
            }
        }

        if (!$request->filled('cv_document_id')) {
            $existingDoc = \App\Models\Document::where('user_id', $user->id)
                ->whereIn('document_type', ['cv', 'resume', 'other'])
                ->latest()
                ->first();

            if ($existingDoc) {
                return $existingDoc->id;
            }

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

            return $newDoc->id;
        }

        // Verify CV document belongs to the authenticated applicant
        $doc = \App\Models\Document::find($request->input('cv_document_id'));
        if ($doc && $doc->user_id !== $user->id && !$user->isAdmin()) {
            return $this->errorResponse('Access denied. The specified CV document does not belong to your account.', 403);
        }

        return (int) $request->input('cv_document_id');
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
        if (null !== ($denied = $this->authorizeApplicationAccess($application, $user, 'Unauthorized to view this application.'))) {
            return $denied;
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

        if (null !== ($denied = $this->assertEmployerOrAdmin($application, $user, 'Unauthorized to update application status.'))) {
            return $denied;
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

        if (null !== ($denied = $this->assertApplicantOrAdmin($application, $user, 'Unauthorized to withdraw this application.'))) {
            return $denied;
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

        if (null !== ($denied = $this->assertEmployerOrAdmin($application, $user, 'Unauthorized to schedule an interview for this vacancy.'))) {
            return $denied;
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

        if (null !== ($denied = $this->assertApplicantOrAdmin($application, $user, 'Unauthorized. Only the candidate can confirm attendance.'))) {
            return $denied;
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

        if (null !== ($denied = $this->authorizeApplicationAccess($application, $user, 'Unauthorized.'))) {
            return $denied;
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

        if (null !== ($denied = $this->assertEmployerOrAdmin($application, $user, 'Unauthorized. Only the job employer can issue a formal offer.'))) {
            return $denied;
        }

        $validated = $request->validate([
            'offer_salary' => 'required|numeric|min:0',
            'offer_benefits' => 'nullable|string',
            'offer_conditions' => 'nullable|string',
            'offer_start_date' => 'required|date',
            'offer_notes' => 'nullable|string',
        ]);

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

        $this->recordStatusHistory($application, $user, 'offered', 'Formal employment offer issued to candidate.');

        // Notify candidate
        $this->notifyUser(
            $application->profile?->user_id,
            'Formal Job Offer Received! 🎉',
            "Congratulations! {$application->job->employer->organization_name} has extended an official employment offer for {$application->job->title}.",
            'job_offer'
        );

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

        if (null !== ($denied = $this->authorizeApplicationAccess($application, $user, 'Unauthorized to view this offer.'))) {
            return $denied;
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

        if (null !== ($denied = $this->assertApplicantOrAdmin($application, $user, 'Unauthorized. Only the applicant can respond to the job offer.'))) {
            return $denied;
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

        $this->recordStatusHistory($application, $user, $newAppStatus, "Candidate responded to offer: {$action}. Notes: {$notes}");

        // Notify employer members
        $this->notifyEmployerMembers(
            $application,
            "Job Offer Update: {$application->job->title}",
            "Candidate {$user->name} has {$action} the formal job offer." . ($notes ? " Notes: {$notes}" : ''),
            'offer_response'
        );

        return $this->successResponse($application->fresh(), "Offer response '{$action}' recorded successfully.");
    }

    /**
     * Determine whether the user belongs to the employer who owns the application's job.
     */
    private function isJobEmployer(User $user, Application $application): bool
    {
        return $user->employers->contains('id', $application->job->employer_id);
    }

    /**
     * Ensure the user is the owning employer or an admin.
     *
     * @return \Illuminate\Http\JsonResponse|null An error response when unauthorized, null when authorized.
     */
    private function assertEmployerOrAdmin(Application $application, User $user, string $message): ?JsonResponse
    {
        if ($this->isJobEmployer($user, $application) || $user->isAdmin()) {
            return null;
        }

        return $this->errorResponse($message, 403);
    }

    /**
     * Ensure the user is the applicant or an admin.
     *
     * @return \Illuminate\Http\JsonResponse|null An error response when unauthorized, null when authorized.
     */
    private function assertApplicantOrAdmin(Application $application, User $user, string $message): ?JsonResponse
    {
        if ($application->profile?->user_id === $user->id || $user->isAdmin()) {
            return null;
        }

        return $this->errorResponse($message, 403);
    }

    /**
     * Ensure the user is the applicant, the owning employer, or an admin.
     *
     * @return \Illuminate\Http\JsonResponse|null An error response when unauthorized, null when authorized.
     */
    private function authorizeApplicationAccess(Application $application, User $user, string $message): ?JsonResponse
    {
        $isApplicant = $application->profile?->user_id === $user->id;

        if (!$isApplicant && !$this->isJobEmployer($user, $application) && !$user->isAdmin()) {
            return $this->errorResponse($message, 403);
        }

        return null;
    }

    /**
     * Persist a status-change history entry for an application.
     */
    private function recordStatusHistory(Application $application, User $user, string $newStatus, ?string $notes = null): void
    {
        ApplicationStatusHistory::create([
            'application_id' => $application->id,
            'changed_by' => $user->id,
            'old_status' => $application->getOriginal('status'),
            'new_status' => $newStatus,
            'notes' => $notes,
        ]);
    }

    /**
     * Create an in-app notification for a single user (no-op when user id is null).
     */
    private function notifyUser(?int $userId, string $title, string $message, string $notificationType): void
    {
        if (!$userId) {
            return;
        }

        Notification::create([
            'user_id' => $userId,
            'title' => $title,
            'message' => $message,
            'notification_type' => $notificationType,
            'is_read' => false,
        ]);
    }

    /**
     * Notify every member of the application's employer organization.
     */
    private function notifyEmployerMembers(Application $application, string $title, string $message, string $notificationType): void
    {
        $employer = $application->job->employer;

        if (!$employer || $employer->members->isEmpty()) {
            return;
        }

        foreach ($employer->members as $member) {
            $this->notifyUser($member->user?->id, $title, $message, $notificationType);
        }
    }
}
