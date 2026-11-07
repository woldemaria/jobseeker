<?php

namespace App\Http\Controllers\Api;

use App\Models\Application;
use App\Models\Job;
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
}
