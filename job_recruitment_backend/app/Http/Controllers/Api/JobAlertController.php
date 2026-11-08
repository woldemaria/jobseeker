<?php

namespace App\Http\Controllers\Api;

use App\Models\AuditLog;
use App\Models\JobAlert;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class JobAlertController extends BaseApiController
{
    /**
     * List authenticated user's job alerts (Section 6).
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $alerts = JobAlert::where('user_id', $user->id)
            ->with('category')
            ->latest()
            ->get();

        foreach ($alerts as $alert) {
            $alert->matching_jobs_count = $alert->matchingJobs()->count();
        }

        return $this->successResponse($alerts, 'Job alerts retrieved successfully.');
    }

    /**
     * Create a custom job alert.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => 'required|string|max:150',
            'keyword' => 'nullable|string|max:150',
            'category_id' => 'nullable|exists:job_categories,id',
            'location' => 'nullable|string|max:150',
            'min_salary' => 'nullable|numeric|min:0',
            'frequency' => 'nullable|string|in:instant,daily,weekly',
        ]);

        $alert = JobAlert::create([
            'user_id' => $request->user()->id,
            'title' => $validated['title'],
            'keyword' => $validated['keyword'] ?? null,
            'category_id' => $validated['category_id'] ?? null,
            'location' => $validated['location'] ?? null,
            'min_salary' => $validated['min_salary'] ?? null,
            'frequency' => $validated['frequency'] ?? 'daily',
            'is_active' => true,
        ]);

        $alert->matching_jobs_count = $alert->matchingJobs()->count();

        AuditLog::create([
            'user_id' => $request->user()->id,
            'action' => 'job_alert_created',
            'entity_type' => 'JobAlert',
            'entity_id' => $alert->id,
            'description' => "Job alert '{$alert->title}' created.",
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        return $this->successResponse($alert->load('category'), 'Job alert created successfully.', 201);
    }

    /**
     * Pause or activate a job alert.
     */
    public function toggle(Request $request, int $id): JsonResponse
    {
        $alert = JobAlert::where('user_id', $request->user()->id)->findOrFail($id);
        $alert->is_active = !$alert->is_active;
        $alert->save();

        $statusStr = $alert->is_active ? 'activated' : 'paused';
        return $this->successResponse($alert, "Job alert {$statusStr} successfully.");
    }

    /**
     * Delete a job alert.
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $alert = JobAlert::where('user_id', $request->user()->id)->findOrFail($id);
        $alert->delete();

        return $this->successResponse(null, 'Job alert deleted successfully.');
    }

    /**
     * View matching vacancies for a specific job alert.
     */
    public function matches(Request $request, int $id): JsonResponse
    {
        $alert = JobAlert::where('user_id', $request->user()->id)->findOrFail($id);
        $jobs = $alert->matchingJobs()->paginate($request->get('per_page', 15));

        return $this->successResponse($jobs->items(), 'Matching vacancies retrieved.', 200, [
            'total' => $jobs->total(),
            'current_page' => $jobs->currentPage(),
        ]);
    }
}
