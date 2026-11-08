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
use App\Services\FraudDetectionService;
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
            'flagged_jobs' => Job::flagged()->count(),
            'critical_fraud_jobs' => Job::where('fraud_risk_level', 'critical')->count(),
        ];

        return $this->successResponse($stats, 'System statistics.');
    }

    public function reports(Request $request): JsonResponse
    {
        if ($resp = $this->checkAdmin($request)) return $resp;

        $query = Report::with(['reporter', 'job.employer', 'reportedUser', 'reviewer'])->latest();

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        $reports = $query->get();
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

        // When a job is reported, re-evaluate its fraud risk and auto-flag if needed
        if (!empty($validated['job_id'])) {
            $job = Job::find($validated['job_id']);
            if ($job) {
                $fraudService = app(FraudDetectionService::class);
                $fraudService->applyToJob($job);
            }
        }

        return $this->successResponse($report, 'Report submitted for administrator review.', 201);
    }

    /**
     * List flagged and suspicious job advertisements for fraud moderation.
     */
    public function fraudJobs(Request $request): JsonResponse
    {
        if ($resp = $this->checkAdmin($request)) return $resp;

        $query = Job::with(['employer.members', 'moderator'])
            ->withCount(['reports' => function ($q) {
                $q->where('status', 'pending');
            }]);

        // Filter by risk level
        if ($request->filled('risk_level') && $request->risk_level !== 'all') {
            $query->where('fraud_risk_level', $request->risk_level);
        }

        // Filter by moderation status
        if ($request->filled('moderation_status') && $request->moderation_status !== 'all') {
            $query->where('moderation_status', $request->moderation_status);
        } else {
            // Default: show flagged, under_review, fraudulent, or high score
            $query->where(function ($q) {
                $q->where('is_flagged', true)
                  ->orWhere('fraud_score', '>=', 30)
                  ->orWhereIn('moderation_status', ['flagged', 'under_review', 'fraudulent']);
            });
        }

        // Search in title or employer name
        if ($request->filled('search')) {
            $kw = '%' . $request->search . '%';
            $query->where(function ($q) use ($kw) {
                $q->where('title', 'like', $kw)
                  ->orWhere('description', 'like', $kw)
                  ->orWhereHas('employer', function ($sub) use ($kw) {
                      $sub->where('organization_name', 'like', $kw);
                  });
            });
        }

        $jobs = $query->orderByDesc('fraud_score')->latest()->paginate($request->get('per_page', 20));

        $summary = [
            'total_flagged' => Job::flagged()->count(),
            'critical_count' => Job::where('fraud_risk_level', 'critical')->count(),
            'high_count' => Job::where('fraud_risk_level', 'high')->count(),
            'under_review_count' => Job::where('moderation_status', 'under_review')->count(),
            'fraudulent_count' => Job::where('moderation_status', 'fraudulent')->count(),
        ];

        return $this->successResponse($jobs->items(), 'Fraudulent job advertisements retrieved.', 200, [
            'current_page' => $jobs->currentPage(),
            'total' => $jobs->total(),
            'summary' => $summary,
        ]);
    }

    /**
     * Moderate a flagged job advertisement.
     */
    public function moderateJob(Request $request, int $id): JsonResponse
    {
        if ($resp = $this->checkAdmin($request)) return $resp;

        $request->validate([
            'action' => 'required|string|in:mark_fraudulent,mark_safe,takedown,suspend_employer',
            'notes' => 'nullable|string',
        ]);

        $job = Job::with(['employer.members.user', 'reports'])->findOrFail($id);
        $action = $request->action;
        $notes = $request->notes ?? '';
        $admin = $request->user();

        switch ($action) {
            case 'mark_fraudulent':
                $job->moderation_status = 'fraudulent';
                $job->status = 'archived'; // unlisted immediately
                $job->is_flagged = true;
                $job->fraud_risk_level = 'critical';
                $job->moderated_by = $admin->id;
                $job->moderated_at = now();
                $job->moderation_notes = $notes ?: 'Marked as fraudulent listing by administrator';
                $job->save();

                // Resolve pending reports
                Report::where('job_id', $job->id)->where('status', 'pending')->update([
                    'status' => 'resolved',
                    'action_taken' => 'marked_fraudulent',
                    'resolution_notes' => $notes ?: 'Listing taken down as confirmed fraud',
                    'resolved_at' => now(),
                    'reviewed_by' => $admin->id,
                ]);

                // Notify employer owner of violation
                if ($job->employer && $job->employer->members->isNotEmpty()) {
                    $owner = $job->employer->members->first()->user;
                    if ($owner) {
                        Notification::create([
                            'user_id' => $owner->id,
                            'title' => 'Vacancy Takedown Notice: Policy Violation',
                            'message' => "Your job advertisement '{$job->title}' has been removed due to fraudulent activity or policy violations. Notes: {$notes}",
                            'notification_type' => 'fraud_warning',
                            'is_read' => false,
                        ]);
                    }
                }
                break;

            case 'mark_safe':
                $job->moderation_status = 'cleared';
                $job->is_flagged = false;
                $job->fraud_score = max(0, min($job->fraud_score, 15));
                $job->fraud_risk_level = 'low';
                $job->moderated_by = $admin->id;
                $job->moderated_at = now();
                $job->moderation_notes = $notes ?: 'Verified and marked safe by administrator';
                if ($job->status === 'draft') {
                    $job->status = 'published';
                    if (!$job->published_at) $job->published_at = now();
                }
                $job->save();

                // Dismiss pending reports
                Report::where('job_id', $job->id)->where('status', 'pending')->update([
                    'status' => 'dismissed',
                    'action_taken' => 'marked_safe',
                    'resolution_notes' => $notes ?: 'Reviewed and marked safe by administrator',
                    'resolved_at' => now(),
                    'reviewed_by' => $admin->id,
                ]);
                break;

            case 'takedown':
                $job->status = 'closed';
                $job->moderation_status = 'under_review';
                $job->moderated_by = $admin->id;
                $job->moderated_at = now();
                $job->moderation_notes = $notes ?: 'Taken down pending further verification';
                $job->save();
                break;

            case 'suspend_employer':
                $job->moderation_status = 'fraudulent';
                $job->status = 'archived';
                $job->is_flagged = true;
                $job->moderated_by = $admin->id;
                $job->moderated_at = now();
                $job->moderation_notes = $notes ?: 'Employer suspended for fraudulent recruiting';
                $job->save();

                if ($job->employer) {
                    $job->employer->update(['verification_status' => 'rejected']);
                    // Suspend user accounts tied to this organization
                    foreach ($job->employer->members as $member) {
                        if ($member->user) {
                            $member->user->update(['status' => 'suspended']);
                        }
                    }
                    // Archive all vacancies published by this organization
                    Job::where('employer_id', $job->employer_id)->update([
                        'status' => 'archived',
                        'moderation_status' => 'fraudulent',
                        'is_flagged' => true,
                    ]);
                }
                break;
        }

        AuditLog::create([
            'user_id' => $admin->id,
            'action' => 'job_fraud_moderated',
            'entity_type' => 'Job',
            'entity_id' => $job->id,
            'description' => "Moderation action '{$action}' applied to job #{$job->id} ({$job->title}).",
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        return $this->successResponse($job->fresh(['employer', 'moderator']), "Moderation action '{$action}' executed successfully.");
    }

    /**
     * Run automated fraud scan across platform vacancies.
     */
    public function scanFraudJobs(Request $request, FraudDetectionService $fraudService): JsonResponse
    {
        if ($resp = $this->checkAdmin($request)) return $resp;

        $results = $fraudService->scanAllJobs();

        AuditLog::create([
            'user_id' => $request->user()->id,
            'action' => 'platform_fraud_scan',
            'entity_type' => 'Job',
            'entity_id' => 0,
            'description' => "Platform-wide fraud scan completed: {$results['total_scanned']} scanned, {$results['flagged_count']} flagged, {$results['quarantined_count']} quarantined.",
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        return $this->successResponse($results, 'Platform fraud scan completed successfully.');
    }

    /**
     * Review / resolve a specific abuse report.
     */
    public function moderateReport(Request $request, int $id): JsonResponse
    {
        if ($resp = $this->checkAdmin($request)) return $resp;

        $request->validate([
            'action' => 'required|string|in:mark_fraudulent,mark_safe,dismiss,takedown_job',
            'notes' => 'nullable|string',
        ]);

        $report = Report::with('job')->findOrFail($id);
        $action = $request->action;
        $notes = $request->notes ?? '';
        $admin = $request->user();

        $status = in_array($action, ['dismiss', 'mark_safe']) ? 'dismissed' : 'resolved';

        $report->update([
            'status' => $status,
            'action_taken' => $action,
            'resolution_notes' => $notes,
            'resolved_at' => now(),
            'reviewed_by' => $admin->id,
        ]);

        if ($report->job) {
            if ($action === 'mark_fraudulent') {
                $report->job->update([
                    'moderation_status' => 'fraudulent',
                    'status' => 'archived',
                    'is_flagged' => true,
                    'moderated_by' => $admin->id,
                    'moderated_at' => now(),
                    'moderation_notes' => $notes,
                ]);
            } elseif ($action === 'takedown_job') {
                $report->job->update([
                    'status' => 'closed',
                    'moderation_status' => 'under_review',
                    'moderated_by' => $admin->id,
                    'moderated_at' => now(),
                    'moderation_notes' => $notes,
                ]);
            } elseif ($action === 'mark_safe') {
                $report->job->update([
                    'moderation_status' => 'cleared',
                    'is_flagged' => false,
                    'moderated_by' => $admin->id,
                    'moderated_at' => now(),
                ]);
            }
        }

        AuditLog::create([
            'user_id' => $admin->id,
            'action' => 'report_moderated',
            'entity_type' => 'Report',
            'entity_id' => $report->id,
            'description' => "Report #{$report->id} resolved with action '{$action}'.",
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        return $this->successResponse($report->fresh(['reporter', 'job', 'reviewer']), 'Report moderated successfully.');
    }
}
