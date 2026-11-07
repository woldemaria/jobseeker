<?php

namespace App\Http\Controllers\Api;

use App\Models\Application;
use App\Models\AuditLog;
use App\Models\Employer;
use App\Models\EmployerVerification;
use App\Models\Job;
use App\Models\Notification;
use App\Models\Report;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminController extends BaseApiController
{
    private function checkAdmin(Request $request): ?JsonResponse
    {
        if (!$request->user()->isAdmin()) {
            return $this->errorResponse('Access denied. Administrator privileges required.', 403);
        }
        return null;
    }

    public function users(Request $request): JsonResponse
    {
        if ($resp = $this->checkAdmin($request)) return $resp;

        $users = User::with(['roles', 'jobSeekerProfile', 'employers'])->latest()->paginate(20);
        return $this->successResponse($users->items(), 'Users retrieved.', 200, [
            'current_page' => $users->currentPage(),
            'total' => $users->total(),
        ]);
    }

    public function updateUserStatus(Request $request, int $id): JsonResponse
    {
        if ($resp = $this->checkAdmin($request)) return $resp;

        $request->validate(['status' => 'required|string|in:active,pending,suspended,deactivated']);

        $user = User::findOrFail($id);
        $user->status = $request->status;
        $user->save();

        AuditLog::create([
            'user_id' => $request->user()->id,
            'action' => 'user_status_changed',
            'entity_type' => 'User',
            'entity_id' => $user->id,
            'description' => "Status changed to {$request->status} for {$user->email}.",
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        return $this->successResponse($user, 'User status updated successfully.');
    }

    public function verifications(Request $request): JsonResponse
    {
        if ($resp = $this->checkAdmin($request)) return $resp;

        $verifications = EmployerVerification::with(['employer', 'document', 'submittedBy'])
            ->latest('submitted_at')
            ->get();

        return $this->successResponse($verifications, 'Employer verifications retrieved.');
    }

    public function reviewVerification(Request $request, int $id): JsonResponse
    {
        if ($resp = $this->checkAdmin($request)) return $resp;

        $request->validate([
            'status' => 'required|string|in:approved,rejected,requires_changes',
            'review_notes' => 'nullable|string',
        ]);

        $verification = EmployerVerification::with('employer')->findOrFail($id);
        $verification->update([
            'status' => $request->status,
            'review_notes' => $request->review_notes,
            'reviewed_by' => $request->user()->id,
            'reviewed_at' => now(),
        ]);

        $verification->employer->update([
            'verification_status' => $request->status,
        ]);

        // Notify employer owner
        Notification::create([
            'user_id' => $verification->submitted_by,
            'title' => 'Employer Verification Update',
            'message' => "Your organization verification has been: " . strtoupper($request->status) . ($request->review_notes ? ". Notes: " . $request->review_notes : ''),
            'notification_type' => 'verification_update',
            'is_read' => false,
        ]);

        AuditLog::create([
            'user_id' => $request->user()->id,
            'action' => 'employer_verification_reviewed',
            'entity_type' => 'EmployerVerification',
            'entity_id' => $verification->id,
            'description' => "Verification decision: {$request->status}.",
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        return $this->successResponse($verification, 'Verification decision recorded.');
    }

    public function statistics(Request $request): JsonResponse
    {
        if ($resp = $this->checkAdmin($request)) return $resp;

        $stats = [
            'total_users' => User::count(),
            'active_job_seekers' => User::whereHas('roles', fn($q) => $q->where('name', 'job_seeker'))->count(),
            'total_employers' => Employer::count(),
            'pending_verifications' => EmployerVerification::where('status', 'pending')->count(),
            'total_jobs' => Job::count(),
            'published_jobs' => Job::published()->count(),
            'total_applications' => Application::count(),
            'pending_reports' => Report::where('status', 'pending')->count(),
        ];

        return $this->successResponse($stats, 'System statistics.');
    }

    public function reports(Request $request): JsonResponse
    {
        if ($resp = $this->checkAdmin($request)) return $resp;

        $reports = Report::with(['reporter', 'job', 'reportedUser'])->latest()->get();
        return $this->successResponse($reports, 'Reports retrieved.');
    }

    public function submitReport(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'job_id' => 'nullable|exists:jobs,id',
            'reported_user_id' => 'nullable|exists:users,id',
            'reason' => 'required|string|max:150',
            'description' => 'nullable|string',
        ]);

        $report = Report::create([
            'reporter_id' => $request->user()->id,
            'job_id' => $validated['job_id'] ?? null,
            'reported_user_id' => $validated['reported_user_id'] ?? null,
            'reason' => $validated['reason'],
            'description' => $validated['description'] ?? null,
            'status' => 'pending',
        ]);

        return $this->successResponse($report, 'Report submitted for administrator review.', 201);
    }
}
