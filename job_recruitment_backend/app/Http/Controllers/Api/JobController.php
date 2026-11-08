<?php

namespace App\Http\Controllers\Api;

use App\Models\AuditLog;
use App\Models\Job;
use App\Models\JobSkill;
use App\Models\SavedJob;
use App\Services\FraudDetectionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class JobController extends BaseApiController
{
    /**
     * List published vacancies with filters.
     */
    public function index(Request $request): JsonResponse
    {
        $query = Job::published()->with(['employer', 'skills', 'category', 'jobTitle']);

        // Category filter
        if ($request->filled('category_id')) {
            $query->where('category_id', $request->category_id);
        }

        if ($request->filled('category')) {
            $cat = $request->category;
            $query->where(function ($q) use ($cat) {
                $q->where('category', 'like', "%{$cat}%")
                  ->orWhereHas('category', function ($sub) use ($cat) {
                      $sub->where('name', 'like', "%{$cat}%")->orWhere('slug', $cat);
                  });
            });
        }

        if ($request->filled('job_title_id')) {
            $query->where('job_title_id', $request->job_title_id);
        }

        // Title or keyword search
        if ($request->filled('keyword')) {
            $keyword = '%' . $request->keyword . '%';
            $query->where(function ($q) use ($keyword) {
                $q->where('title', 'like', $keyword)
                  ->orWhere('description', 'like', $keyword)
                  ->orWhere('requirements', 'like', $keyword)
                  ->orWhere('category', 'like', $keyword);
            });
        }

        // Location filter
        if ($request->filled('location')) {
            $query->where('location', 'like', '%' . $request->location . '%');
        }

        // Employment type filter
        if ($request->filled('employment_type')) {
            $query->where('employment_type', $request->employment_type);
        }

        // Skills filter
        if ($request->filled('skill_id')) {
            $query->whereHas('skills', function ($q) use ($request) {
                $q->where('skills.id', $request->skill_id);
            });
        }

        // Salary minimum
        if ($request->filled('min_salary')) {
            $query->where('salary_max', '>=', $request->min_salary);
        }

        $jobs = $query->latest('published_at')->paginate($request->get('per_page', 15));

        $user = $request->user() ?: auth('sanctum')->user();
        if ($user) {
            $savedJobIds = SavedJob::where('user_id', $user->id)->pluck('job_id')->flip();
            $appliedJobIds = [];
            $profile = $user->jobSeekerProfile ?? \App\Models\JobSeekerProfile::firstOrCreate(['user_id' => $user->id]);
            if ($profile) {
                $appliedJobIds = $profile->applications()->pluck('status', 'job_id')->toArray();
            }
            foreach ($jobs as $job) {
                $job->is_saved = isset($savedJobIds[$job->id]);
                $job->has_applied = isset($appliedJobIds[$job->id]);
                if (isset($appliedJobIds[$job->id])) {
                    $job->application_status = $appliedJobIds[$job->id];
                }
            }
        }

        return $this->successResponse($jobs->items(), 'Jobs retrieved successfully.', 200, [
            'current_page' => $jobs->currentPage(),
            'total' => $jobs->total(),
            'per_page' => $jobs->perPage(),
            'last_page' => $jobs->lastPage(),
        ]);
    }

    /**
     * Search endpoint alias.
     */
    public function search(Request $request): JsonResponse
    {
        return $this->index($request);
    }

    /**
     * View single job vacancy.
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $job = Job::with(['employer.members', 'skills', 'screeningQuestions'])->findOrFail($id);

        $data = $job->toArray();
        $user = $request->user() ?: auth('sanctum')->user();
        if ($user) {
            $data['is_saved'] = $job->isSavedBy($user->id);
            $profile = $user->jobSeekerProfile ?? \App\Models\JobSeekerProfile::firstOrCreate(['user_id' => $user->id]);
            if ($profile) {
                $existingApp = $job->applications()->where('profile_id', $profile->id)->first();
                $data['has_applied'] = $existingApp !== null;
                $data['application_status'] = $existingApp?->status;
            }
        }

        return $this->successResponse($data, 'Job details retrieved successfully.');
    }

    /**
     * Create job (Employers only).
     */
    public function store(Request $request): JsonResponse
    {
        $user = $request->user() ?: auth('sanctum')->user();
        if (!$user) {
            return $this->errorResponse('Unauthenticated.', 401);
        }

        $employer = $user->employers()->first();

        if (!$employer) {
            $employer = \App\Models\Employer::create([
                'organization_name' => $user->name . ' Organization',
                'email' => $user->email,
                'phone' => $user->phone,
                'verification_status' => 'approved',
            ]);
            \App\Models\EmployerMember::create([
                'employer_id' => $employer->id,
                'user_id' => $user->id,
                'member_role' => 'owner',
            ]);
        }

        $validated = $request->validate([
            'category_id' => 'nullable|integer|exists:job_categories,id',
            'category' => 'nullable|string|max:150',
            'job_title_id' => 'nullable|integer|exists:job_titles,id',
            'title' => 'required|string|max:200',
            'description' => 'required|string',
            'responsibilities' => 'nullable|string',
            'requirements' => 'nullable|string',
            'location' => 'required|string|max:150',
            'employment_type' => 'required|string|max:50',
            'experience_required' => 'nullable|numeric|min:0',
            'salary_min' => 'nullable|numeric|min:0',
            'salary_max' => ['nullable', 'numeric', 'min:0', function ($attribute, $value, $fail) use ($request) {
                if ($value !== null && $request->filled('salary_min') && (float)$value < (float)$request->salary_min) {
                    $fail('The maximum salary must be greater than or equal to minimum salary.');
                }
            }],
            'currency' => 'nullable|string|max:10',
            'deadline' => 'required|date',
            'status' => 'nullable|string|in:draft,published',
            'skills' => 'nullable|array',
            'skills.*.skill_id' => 'required_with:skills|exists:skills,id',
            'skills.*.importance' => 'nullable|string|in:required,preferred',
            'skills.*.minimum_proficiency' => 'nullable|string',
        ]);

        $job = DB::transaction(function () use ($employer, $validated, $user, $request) {
            $status = $validated['status'] ?? 'published';
            $publishedAt = $status === 'published' ? now() : null;

            // Fraud Detection Analysis
            $fraudService = app(FraudDetectionService::class);
            $fraudAssessment = $fraudService->assessJobData($validated, $employer);
            $fraudScore = $fraudAssessment['fraud_score'];
            $fraudRiskLevel = $fraudAssessment['fraud_risk_level'];
            $fraudIndicators = $fraudAssessment['fraud_indicators'];
            $isFlagged = $fraudAssessment['is_flagged'];
            $moderationStatus = 'clean';

            if ($fraudAssessment['recommended_action'] === 'auto_quarantine') {
                $moderationStatus = 'under_review';
                $status = 'draft';
                $publishedAt = null;
            } elseif ($isFlagged) {
                $moderationStatus = 'flagged';
            }

            $categoryId = $validated['category_id'] ?? null;
            $categoryName = $validated['category'] ?? null;
            if ($categoryId && empty($categoryName)) {
                $categoryName = \App\Models\JobCategory::find($categoryId)?->name;
            } elseif (!$categoryId && !empty($categoryName)) {
                $cat = \App\Models\JobCategory::where('name', $categoryName)->orWhere('slug', $categoryName)->first();
                if ($cat) {
                    $categoryId = $cat->id;
                    $categoryName = $cat->name;
                }
            }

            $newJob = Job::create([
                'employer_id' => $employer->id,
                'category_id' => $categoryId,
                'category' => $categoryName,
                'job_title_id' => $validated['job_title_id'] ?? null,
                'title' => $validated['title'],
                'description' => $validated['description'],
                'responsibilities' => $validated['responsibilities'] ?? null,
                'requirements' => $validated['requirements'] ?? null,
                'location' => $validated['location'],
                'employment_type' => $validated['employment_type'],
                'experience_required' => $validated['experience_required'] ?? null,
                'salary_min' => $validated['salary_min'] ?? null,
                'salary_max' => $validated['salary_max'] ?? null,
                'currency' => $validated['currency'] ?? 'ETB',
                'deadline' => $validated['deadline'],
                'status' => $status,
                'fraud_score' => $fraudScore,
                'fraud_risk_level' => $fraudRiskLevel,
                'fraud_indicators' => $fraudIndicators,
                'is_flagged' => $isFlagged,
                'moderation_status' => $moderationStatus,
                'published_at' => $publishedAt,
            ]);

            if (!empty($validated['skills'])) {
                foreach ($validated['skills'] as $skillItem) {
                    JobSkill::create([
                        'job_id' => $newJob->id,
                        'skill_id' => $skillItem['skill_id'],
                        'importance' => $skillItem['importance'] ?? 'required',
                        'minimum_proficiency' => $skillItem['minimum_proficiency'] ?? null,
                    ]);
                }
            }

            AuditLog::create([
                'user_id' => $user->id,
                'action' => 'job_created',
                'entity_type' => 'Job',
                'entity_id' => $newJob->id,
                'description' => "Job '{$newJob->title}' created.",
                'ip_address' => $request->ip(),
                'created_at' => now(),
            ]);

            return $newJob->load(['employer', 'skills']);
        });

        return $this->successResponse($job, 'Job created successfully.', 201);
    }

    /**
     * Update job.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $job = Job::findOrFail($id);
        $user = $request->user() ?: auth('sanctum')->user();
        if (!$user) {
            return $this->errorResponse('Unauthenticated.', 401);
        }

        // Check ownership
        if (!$user->employers->contains('id', $job->employer_id) && !$user->isAdmin()) {
            return $this->errorResponse('Unauthorized to modify this vacancy.', 403);
        }

        $validated = $request->validate([
            'category_id' => 'nullable|integer|exists:job_categories,id',
            'category' => 'nullable|string|max:150',
            'job_title_id' => 'nullable|integer|exists:job_titles,id',
            'title' => 'sometimes|string|max:200',
            'description' => 'sometimes|string',
            'responsibilities' => 'nullable|string',
            'requirements' => 'nullable|string',
            'location' => 'sometimes|string|max:150',
            'employment_type' => 'sometimes|string|max:50',
            'experience_required' => 'nullable|numeric|min:0',
            'salary_min' => 'nullable|numeric|min:0',
            'salary_max' => ['nullable', 'numeric', 'min:0', function ($attribute, $value, $fail) use ($request, $job) {
                $min = $request->filled('salary_min') ? (float)$request->salary_min : ($job->salary_min ? (float)$job->salary_min : null);
                if ($value !== null && $min !== null && (float)$value < $min) {
                    $fail('The maximum salary must be greater than or equal to minimum salary.');
                }
            }],
            'currency' => 'nullable|string|max:10',
            'deadline' => 'sometimes|date',
            'status' => 'sometimes|string|in:draft,published,closed,archived',
            'skills' => 'nullable|array',
            'skills.*.skill_id' => 'required_with:skills|exists:skills,id',
            'skills.*.importance' => 'nullable|string|in:required,preferred',
        ]);

        DB::transaction(function () use ($job, $validated) {
            if (isset($validated['category_id']) && empty($validated['category'])) {
                $validated['category'] = \App\Models\JobCategory::find($validated['category_id'])?->name;
            } elseif (isset($validated['category']) && empty($validated['category_id'])) {
                $cat = \App\Models\JobCategory::where('name', $validated['category'])->orWhere('slug', $validated['category'])->first();
                if ($cat) {
                    $validated['category_id'] = $cat->id;
                    $validated['category'] = $cat->name;
                }
            }

            if (isset($validated['status']) && $validated['status'] === 'published' && !$job->published_at) {
                $validated['published_at'] = now();
            }

            $job->update($validated);

            // Re-assess fraud score upon updating details
            $fraudService = app(FraudDetectionService::class);
            $fraudService->applyToJob($job);

            if (isset($validated['skills'])) {
                JobSkill::where('job_id', $job->id)->delete();
                foreach ($validated['skills'] as $skillItem) {
                    JobSkill::create([
                        'job_id' => $job->id,
                        'skill_id' => $skillItem['skill_id'],
                        'importance' => $skillItem['importance'] ?? 'required',
                    ]);
                }
            }
        });

        return $this->successResponse($job->fresh(['employer', 'skills']), 'Job updated successfully.');
    }

    /**
     * Archive or delete job.
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $job = Job::findOrFail($id);
        $user = $request->user() ?: auth('sanctum')->user();
        if (!$user) {
            return $this->errorResponse('Unauthenticated.', 401);
        }

        if (!$user->employers->contains('id', $job->employer_id) && !$user->isAdmin()) {
            return $this->errorResponse('Unauthorized action.', 403);
        }

        $job->status = 'archived';
        $job->save();

        return $this->successResponse(null, 'Job archived successfully.');
    }

    /**
     * List applicants for a vacancy (Employer only).
     */
    public function applicants(Request $request, int $id): JsonResponse
    {
        $job = Job::with('employer')->findOrFail($id);
        $user = $request->user() ?: auth('sanctum')->user();
        if (!$user) {
            return $this->errorResponse('Unauthenticated.', 401);
        }

        if (!$user->employers->contains('id', $job->employer_id) && !$user->isAdmin()) {
            return $this->errorResponse('Unauthorized to view applicants.', 403);
        }

        $applications = $job->applications()
            ->with(['profile.user', 'profile.skills', 'cvDocument', 'statusHistories'])
            ->latest('applied_at')
            ->get();

        return $this->successResponse($applications, 'Applicants retrieved successfully.');
    }

    /**
     * Bookmark/save a job.
     */
    public function saveJob(Request $request, int $id): JsonResponse
    {
        $job = Job::findOrFail($id);
        $saved = SavedJob::firstOrCreate([
            'user_id' => $request->user()->id,
            'job_id' => $job->id,
        ]);

        return $this->successResponse($saved, 'Job saved successfully.');
    }

    /**
     * Remove saved job.
     */
    public function unsaveJob(Request $request, int $id): JsonResponse
    {
        SavedJob::where('user_id', $request->user()->id)->where('job_id', $id)->delete();
        return $this->successResponse(null, 'Job removed from saved list.');
    }

    /**
     * List saved jobs for authenticated user.
     */
    public function listSaved(Request $request): JsonResponse
    {
        $saved = SavedJob::where('user_id', $request->user()->id)
            ->with(['job.employer', 'job.skills'])
            ->latest()
            ->get();

        $jobs = $saved->pluck('job')->filter();
        return $this->successResponse($jobs->values(), 'Saved jobs retrieved.');
    }

    /**
     * List jobs created by the employer.
     */
    public function employerJobs(Request $request): JsonResponse
    {
        $user = $request->user() ?: auth('sanctum')->user();
        if (!$user) {
            return $this->errorResponse('Unauthenticated.', 401);
        }

        $employer = $user->employers()->first();
        if (!$employer) {
            return $this->successResponse([], 'No vacancies posted yet.');
        }

        $jobs = Job::where('employer_id', $employer->id)
            ->with(['skills'])
            ->withCount('applications')
            ->latest()
            ->get();

        return $this->successResponse($jobs, 'Employer vacancies retrieved.');
    }

    /**
     * Pre-check job posting content for fraud / scam indicators before creation.
     */
    public function checkFraud(Request $request, FraudDetectionService $fraudService): JsonResponse
    {
        $validated = $request->validate([
            'title' => 'required|string|max:200',
            'description' => 'required|string',
            'requirements' => 'nullable|string',
            'responsibilities' => 'nullable|string',
            'salary_max' => 'nullable|numeric|min:0',
            'salary_min' => 'nullable|numeric|min:0',
            'experience_required' => 'nullable|numeric|min:0',
        ]);

        $employer = $request->user()?->employers()?->first();
        $assessment = $fraudService->assessJobData($validated, $employer);

        return $this->successResponse($assessment, 'Fraud risk assessment calculated successfully.');
    }

    /**
     * Get detailed fraud risk assessment and safety transparency for a job.
     */
    public function fraudAssessment(Request $request, int $id, FraudDetectionService $fraudService): JsonResponse
    {
        $job = Job::with('employer')->findOrFail($id);
        $assessment = $fraudService->assessJob($job);

        return $this->successResponse([
            'job_id' => $job->id,
            'title' => $job->title,
            'employer_name' => $job->employer?->organization_name,
            'is_verified_employer' => $job->employer?->verification_status === 'approved',
            'moderation_status' => $job->moderation_status,
            'is_flagged' => $job->is_flagged,
            'fraud_score' => $job->fraud_score,
            'fraud_risk_level' => $job->fraud_risk_level,
            'fraud_indicators' => $job->fraud_indicators ?? $assessment['fraud_indicators'],
            'safety_checklist' => $assessment['safety_checklist'],
        ], 'Fraud risk assessment details retrieved.');
    }
}
