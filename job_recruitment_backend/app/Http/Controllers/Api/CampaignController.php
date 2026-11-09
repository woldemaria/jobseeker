<?php

namespace App\Http\Controllers\Api;

use App\Models\Advertisement;
use App\Models\AdvertisingPackage;
use App\Models\AuditLog;
use App\Models\Employer;
use App\Models\Notification;
use App\Models\User;
use App\Services\EthiopianLocationService;
use App\Services\ImageUploadService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CampaignController extends BaseApiController
{
    /**
     * Resolve the employer ID for the authenticated user and ensure authorization.
     */
    protected function resolveEmployerId(User $user, ?int $requestedEmployerId = null): ?int
    {
        $employerIds = $user->employers()->pluck('employers.id')->toArray();

        if ($user->isAdmin() && $requestedEmployerId) {
            return $requestedEmployerId;
        }

        if ($requestedEmployerId && in_array($requestedEmployerId, $employerIds)) {
            return $requestedEmployerId;
        }

        if (!empty($employerIds)) {
            return $employerIds[0];
        }

        // Auto-provision an employer profile for employer users without an explicit company record
        $employer = Employer::firstOrCreate(
            ['email' => $user->email],
            [
                'organization_name' => $user->name . ' Enterprise',
                'phone' => $user->phone ?? '+251911000000',
                'verification_status' => 'pending',
            ]
        );
        $user->employers()->syncWithoutDetaching([$employer->id => ['member_role' => 'admin']]);

        return $employer->id;
    }

    /**
     * Check if the authenticated user owns or has authority over the campaign.
     */
    protected function authorizeCampaignAccess(User $user, Advertisement $ad): bool
    {
        if ($user->isAdmin()) {
            return true;
        }

        $employerIds = $user->employers()->pluck('employers.id')->toArray();

        return $ad->created_by === $user->id ||
               (!empty($ad->employer_id) && in_array($ad->employer_id, $employerIds));
    }

    /**
     * Public / Employer: Ethiopian geographic targeting hierarchy.
     */
    public function locations(): JsonResponse
    {
        return $this->successResponse([
            'hierarchy' => EthiopianLocationService::getTargetingHierarchy(),
            'all_locations' => EthiopianLocationService::getAllValidLocations(),
        ], 'Ethiopian geographic targeting locations retrieved.');
    }

    /**
     * Employer: List campaigns belonging to authenticated employer with status filters.
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $employerIds = $user->employers()->pluck('employers.id')->toArray();

        $query = Advertisement::with(['package', 'employer', 'job', 'approvedBy'])
            ->where(function ($q) use ($user, $employerIds) {
                $q->where('created_by', $user->id);
                if (!empty($employerIds)) {
                    $q->orWhereIn('employer_id', $employerIds);
                }
            })
            ->latest();

        if ($request->filled('status') && $request->status !== 'all') {
            $status = $request->status;
            if (in_array($status, ['draft', 'pending_approval', 'approved', 'rejected'])) {
                $query->where('approval_status', $status);
            } else {
                $query->where('status', $status);
            }
        }

        if ($request->filled('category')) {
            $query->where('category', $request->category);
        }

        $campaigns = $query->paginate($request->get('per_page', 15));

        // Employer summary stats
        $baseQuery = Advertisement::where(function ($q) use ($user, $employerIds) {
            $q->where('created_by', $user->id);
            if (!empty($employerIds)) {
                $q->orWhereIn('employer_id', $employerIds);
            }
        });

        $stats = [
            'total' => (clone $baseQuery)->count(),
            'active' => (clone $baseQuery)->where('status', 'active')->count(),
            'draft' => (clone $baseQuery)->where('approval_status', 'draft')->count(),
            'pending_approval' => (clone $baseQuery)->where('approval_status', 'pending_approval')->count(),
            'approved' => (clone $baseQuery)->where('approval_status', 'approved')->count(),
            'rejected' => (clone $baseQuery)->where('approval_status', 'rejected')->count(),
            'paused' => (clone $baseQuery)->where('status', 'paused')->count(),
            'expired' => (clone $baseQuery)->where('status', 'expired')->count(),
        ];

        return $this->successResponse($campaigns->items(), 'Employer campaigns retrieved.', 200, [
            'current_page' => $campaigns->currentPage(),
            'total' => $campaigns->total(),
            'per_page' => $campaigns->perPage(),
            'last_page' => $campaigns->lastPage(),
            'counts' => $stats,
        ]);
    }

    /**
     * Employer: Create a new advertising campaign with package and geographic validation.
     */
    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'package_id' => 'required|exists:advertising_packages,id',
            'title' => 'required|string|max:200',
            'title_am' => 'nullable|string|max:200',
            'subtitle' => 'nullable|string|max:300',
            'subtitle_am' => 'nullable|string|max:300',
            'description' => 'nullable|string',
            'badge_text' => 'nullable|string|max:50',
            'badge_text_am' => 'nullable|string|max:50',
            'image_url' => 'nullable|string',
            'image_file' => 'nullable|file|image|max:10240',
            'category' => 'required|string|in:featured_jobs,company_promotions,recruitment_campaigns,sponsored_vacancies,announcements',
            'placement' => 'required|string|in:hero,dashboard,job_list,sidebar,search_sponsored,category_specific',
            'placements' => 'nullable|array',
            'placements.*' => 'string|in:hero,dashboard,job_list,sidebar,search_sponsored,category_specific',
            'target_role' => 'nullable|string|in:all,job_seeker,employer',
            'target_skills' => 'nullable|array',
            'target_category' => 'nullable|string|max:100',
            'target_locations' => 'nullable|array',
            'target_locations.*' => 'string|max:100',
            'target_audience' => 'nullable|array',
            'cta_type' => 'required|string|in:apply_now,view_details,explore_jobs,register,visit_company,external_link',
            'cta_text' => 'required|string|max:60',
            'cta_text_am' => 'nullable|string|max:60',
            'cta_target' => 'required|string',
            'background_color' => 'nullable|string|max:30',
            'start_date' => 'required|date',
            'end_date' => 'required|date|after_or_equal:start_date',
            'job_id' => 'nullable|exists:jobs,id',
            'employer_id' => 'nullable|exists:employers,id',
            'is_draft' => 'nullable|boolean',
        ]);

        // 1. Validate Image Creative
        $imageSource = $request->file('image_file') ?: $request->input('image_url');
        if (!$imageSource) {
            return $this->errorResponse('An advertisement creative image file or URL is required.', 422);
        }
        $validated['image_url'] = ImageUploadService::storeImage($imageSource, 'advertisements');
        unset($validated['image_file']);

        // 2. Fetch and Validate Advertising Package Restrictions
        $package = AdvertisingPackage::findOrFail($validated['package_id']);
        if (!$package->is_active) {
            return $this->errorResponse("Selected package '{$package->name}' is currently unavailable for purchase.", 422);
        }

        // Package Category Restriction
        if (!in_array($validated['category'], $package->allowed_categories)) {
            return $this->errorResponse(
                "Category '{$validated['category']}' is not permitted under the {$package->name}. Allowed: " . implode(', ', $package->allowed_categories),
                422
            );
        }

        // Package Placement Restriction
        $selectedPlacements = !empty($validated['placements']) ? $validated['placements'] : [$validated['placement']];
        foreach ($selectedPlacements as $plc) {
            if (!in_array($plc, $package->allowed_placements)) {
                return $this->errorResponse(
                    "Placement '{$plc}' is not included in the {$package->name}. Allowed: " . implode(', ', $package->allowed_placements),
                    422
                );
            }
        }
        $validated['placements'] = array_values(array_unique($selectedPlacements));

        // 3. Campaign Duration Enforcement
        $start = Carbon::parse($validated['start_date']);
        $end = Carbon::parse($validated['end_date']);
        $durationDays = $start->diffInDays($end) + 1;

        if ($durationDays > $package->duration_days) {
            return $this->errorResponse(
                "Selected duration ({$durationDays} days) exceeds the maximum allowed by {$package->name} ({$package->duration_days} days).",
                422
            );
        }

        // 4. Validate Ethiopian Geographic Targeting
        if (!empty($validated['target_locations'])) {
            if (!EthiopianLocationService::validateLocations($validated['target_locations'])) {
                return $this->errorResponse('Invalid Ethiopian geographic location target specified.', 422);
            }
        } else {
            $validated['target_locations'] = ['All Ethiopia'];
        }

        // 5. Ownership & Financial Snapshot
        $validated['created_by'] = $user->id;
        $validated['employer_id'] = $this->resolveEmployerId($user, $validated['employer_id'] ?? null);
        $validated['price_paid'] = $package->price_etb;
        $validated['payment_status'] = 'unpaid'; // Ready for Phase 3 payment integration

        $isDraft = $request->boolean('is_draft', false);
        if ($isDraft) {
            $validated['approval_status'] = 'draft';
            $validated['status'] = 'draft';
        } else {
            $validated['approval_status'] = 'pending_approval';
            $validated['status'] = 'pending_approval';
        }

        $validated['background_color'] = $validated['background_color'] ?? '#0D6B4F';
        $validated['priority'] = $package->priority_level;

        $campaign = DB::transaction(function () use ($validated, $user, $isDraft) {
            $ad = Advertisement::create($validated);

            AuditLog::create([
                'user_id' => $user->id,
                'action' => $isDraft ? 'campaign_draft_created' : 'campaign_submitted_for_approval',
                'entity_type' => 'Advertisement',
                'entity_id' => $ad->id,
                'description' => "Campaign '{$ad->title}' created with status '{$ad->status}'.",
                'ip_address' => request()->ip(),
                'created_at' => now(),
            ]);

            // Notify administrators if submitted directly for approval
            if (!$isDraft) {
                $admins = User::whereHas('roles', fn($q) => $q->where('name', 'administrator'))->get();
                foreach ($admins as $admin) {
                    Notification::create([
                        'user_id' => $admin->id,
                        'title' => 'New Advertising Campaign Submitted',
                        'message' => "Campaign '{$ad->title}' requires administrative review and approval.",
                        'notification_type' => 'campaign_approval_needed',
                        'is_read' => false,
                    ]);
                }
            }

            return $ad;
        });

        return $this->successResponse(
            $campaign->load(['package', 'employer', 'job']),
            $isDraft ? 'Campaign saved as draft successfully.' : 'Campaign submitted for administrative review.',
            201
        );
    }

    /**
     * Employer: View single campaign details and daily telemetry.
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $ad = Advertisement::with(['package', 'employer', 'job', 'creator', 'approvedBy'])->findOrFail($id);

        if (!$this->authorizeCampaignAccess($request->user(), $ad)) {
            return $this->errorResponse('Access denied. You can only view campaigns belonging to your organization.', 403);
        }

        $dailyStats = DB::table('advertisement_events')
            ->where('advertisement_id', $ad->id)
            ->selectRaw('DATE(created_at) as date, event_type, count(*) as count')
            ->groupBy('date', 'event_type')
            ->orderBy('date', 'desc')
            ->take(14)
            ->get();

        return $this->successResponse([
            'campaign' => $ad,
            'daily_events' => $dailyStats,
        ], 'Campaign details retrieved.');
    }

    /**
     * Employer: Update eligible campaign draft or resubmit rejected campaign.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $ad = Advertisement::findOrFail($id);
        $user = $request->user();

        if (!$this->authorizeCampaignAccess($user, $ad)) {
            return $this->errorResponse('Access denied. You can only edit campaigns belonging to your organization.', 403);
        }

        // Can only edit if draft or rejected
        if (!$ad->canBeEdited()) {
            return $this->errorResponse(
                "Campaign cannot be edited in its current status ('{$ad->approval_status}'). Only drafts and rejected campaigns can be edited.",
                422
            );
        }

        $validated = $request->validate([
            'package_id' => 'sometimes|required|exists:advertising_packages,id',
            'title' => 'sometimes|required|string|max:200',
            'title_am' => 'nullable|string|max:200',
            'subtitle' => 'nullable|string|max:300',
            'subtitle_am' => 'nullable|string|max:300',
            'description' => 'nullable|string',
            'badge_text' => 'nullable|string|max:50',
            'badge_text_am' => 'nullable|string|max:50',
            'image_url' => 'nullable|string',
            'image_file' => 'nullable|file|image|max:10240',
            'category' => 'sometimes|required|string|in:featured_jobs,company_promotions,recruitment_campaigns,sponsored_vacancies,announcements',
            'placement' => 'sometimes|required|string|in:hero,dashboard,job_list,sidebar,search_sponsored,category_specific',
            'placements' => 'nullable|array',
            'target_role' => 'nullable|string|in:all,job_seeker,employer',
            'target_skills' => 'nullable|array',
            'target_category' => 'nullable|string|max:100',
            'target_locations' => 'nullable|array',
            'target_locations.*' => 'string|max:100',
            'target_audience' => 'nullable|array',
            'cta_type' => 'sometimes|required|string|in:apply_now,view_details,explore_jobs,register,visit_company,external_link',
            'cta_text' => 'sometimes|required|string|max:60',
            'cta_text_am' => 'nullable|string|max:60',
            'cta_target' => 'sometimes|required|string',
            'background_color' => 'nullable|string|max:30',
            'start_date' => 'sometimes|required|date',
            'end_date' => 'sometimes|required|date|after_or_equal:start_date',
            'job_id' => 'nullable|exists:jobs,id',
            'is_draft' => 'nullable|boolean',
        ]);

        if ($request->hasFile('image_file') || $request->filled('image_url')) {
            $imageSource = $request->file('image_file') ?: $request->input('image_url');
            $validated['image_url'] = ImageUploadService::storeImage($imageSource, 'advertisements');
        }
        unset($validated['image_file']);

        // Check package constraints
        $packageId = $validated['package_id'] ?? $ad->package_id;
        $package = AdvertisingPackage::findOrFail($packageId);

        $category = $validated['category'] ?? $ad->category;
        if (!in_array($category, $package->allowed_categories)) {
            return $this->errorResponse("Category '{$category}' is not allowed for package '{$package->name}'.", 422);
        }

        $startDate = isset($validated['start_date']) ? Carbon::parse($validated['start_date']) : $ad->start_date;
        $endDate = isset($validated['end_date']) ? Carbon::parse($validated['end_date']) : $ad->end_date;
        $durationDays = $startDate->diffInDays($endDate) + 1;

        if ($durationDays > $package->duration_days) {
            return $this->errorResponse("Campaign duration ({$durationDays} days) exceeds {$package->name} limit of {$package->duration_days} days.", 422);
        }

        if (!empty($validated['target_locations'])) {
            if (!EthiopianLocationService::validateLocations($validated['target_locations'])) {
                return $this->errorResponse('Invalid Ethiopian geographic location target specified.', 422);
            }
        }

        $isDraft = $request->boolean('is_draft', true);
        if ($isDraft) {
            $validated['approval_status'] = 'draft';
            $validated['status'] = 'draft';
        } else {
            $validated['approval_status'] = 'pending_approval';
            $validated['status'] = 'pending_approval';
        }
        $validated['price_paid'] = $package->price_etb;

        $ad->update($validated);

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'campaign_updated',
            'entity_type' => 'Advertisement',
            'entity_id' => $ad->id,
            'description' => "Campaign '{$ad->title}' updated (Status: {$ad->status}).",
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        return $this->successResponse($ad->fresh(['package', 'employer', 'job']), 'Campaign updated successfully.');
    }

    /**
     * Employer: Submit draft campaign for admin approval.
     */
    public function submit(Request $request, int $id): JsonResponse
    {
        $ad = Advertisement::findOrFail($id);
        $user = $request->user();

        if (!$this->authorizeCampaignAccess($user, $ad)) {
            return $this->errorResponse('Access denied. You can only submit campaigns belonging to your organization.', 403);
        }

        if (!$ad->canBeEdited()) {
            return $this->errorResponse("Only drafts or rejected campaigns can be submitted for approval.", 422);
        }

        $ad->approval_status = 'pending_approval';
        $ad->status = 'pending_approval';
        $ad->rejection_reason = null;
        $ad->save();

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'campaign_submitted_for_approval',
            'entity_type' => 'Advertisement',
            'entity_id' => $ad->id,
            'description' => "Campaign '{$ad->title}' submitted for administrative approval.",
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        $admins = User::whereHas('roles', fn($q) => $q->where('name', 'administrator'))->get();
        foreach ($admins as $admin) {
            Notification::create([
                'user_id' => $admin->id,
                'title' => 'Campaign Approval Required',
                'message' => "Campaign '{$ad->title}' was submitted for review.",
                'notification_type' => 'campaign_approval_needed',
                'is_read' => false,
            ]);
        }

        return $this->successResponse($ad, 'Campaign submitted for approval.');
    }

    /**
     * Employer: Pause own active campaign.
     */
    public function pause(Request $request, int $id): JsonResponse
    {
        $ad = Advertisement::findOrFail($id);
        $user = $request->user();

        if (!$this->authorizeCampaignAccess($user, $ad)) {
            return $this->errorResponse('Access denied. You can only pause campaigns belonging to your organization.', 403);
        }

        if ($ad->status !== 'active') {
            return $this->errorResponse("Only active campaigns can be paused.", 422);
        }

        $ad->status = 'paused';
        $ad->save();

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'campaign_paused_by_employer',
            'entity_type' => 'Advertisement',
            'entity_id' => $ad->id,
            'description' => "Campaign '{$ad->title}' paused by employer.",
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        return $this->successResponse($ad, 'Campaign paused successfully.');
    }

    /**
     * Employer: Resume paused campaign (strictly enforces approval, payment, and non-expiration).
     */
    public function resume(Request $request, int $id): JsonResponse
    {
        $ad = Advertisement::findOrFail($id);
        $user = $request->user();

        if (!$this->authorizeCampaignAccess($user, $ad)) {
            return $this->errorResponse('Access denied. You can only resume campaigns belonging to your organization.', 403);
        }

        if ($ad->status !== 'paused') {
            return $this->errorResponse("Only paused campaigns can be resumed.", 422);
        }

        if (!$ad->isApproved()) {
            return $this->errorResponse("Cannot resume campaign: administrative approval is pending or rejected.", 422);
        }

        // Strict payment rule: Unpaid campaigns cannot become active
        if (!$ad->isPaid()) {
            return $this->errorResponse("Cannot activate campaign: payment has not been completed.", 422);
        }

        if ($ad->end_date < now()) {
            $ad->status = 'expired';
            $ad->save();
            return $this->errorResponse("Cannot resume campaign: campaign schedule has already expired.", 422);
        }

        $ad->status = 'active';
        $ad->save();

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'campaign_resumed_by_employer',
            'entity_type' => 'Advertisement',
            'entity_id' => $ad->id,
            'description' => "Campaign '{$ad->title}' resumed by employer.",
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        return $this->successResponse($ad, 'Campaign resumed and is now active.');
    }

    // =========================================================================
    // ADMINISTRATOR CAMPAIGN CONTROL
    // =========================================================================

    /**
     * Admin: Comprehensive campaign list with multi-parameter filtering.
     */
    public function adminIndex(Request $request): JsonResponse
    {
        $query = Advertisement::with(['package', 'employer', 'job', 'creator', 'approvedBy'])->latest();

        if ($request->filled('status') && $request->status !== 'all') {
            $status = $request->status;
            if (in_array($status, ['draft', 'pending_approval', 'approved', 'rejected'])) {
                $query->where('approval_status', $status);
            } else {
                $query->where('status', $status);
            }
        }

        if ($request->filled('approval_status')) {
            $query->where('approval_status', $request->approval_status);
        }

        if ($request->filled('employer_id')) {
            $query->where('employer_id', $request->employer_id);
        }

        if ($request->filled('package_id')) {
            $query->where('package_id', $request->package_id);
        }

        if ($request->filled('category')) {
            $query->where('category', $request->category);
        }

        if ($request->filled('placement')) {
            $query->where('placement', $request->placement);
        }

        if ($request->filled('search')) {
            $term = '%' . $request->search . '%';
            $query->where(function ($q) use ($term) {
                $q->where('title', 'like', $term)
                  ->orWhere('subtitle', 'like', $term)
                  ->orWhereHas('employer', fn($eq) => $eq->where('organization_name', 'like', $term));
            });
        }

        $campaigns = $query->paginate($request->get('per_page', 20));

        $stats = [
            'total' => Advertisement::count(),
            'pending_approval' => Advertisement::where('approval_status', 'pending_approval')->count(),
            'approved' => Advertisement::where('approval_status', 'approved')->count(),
            'rejected' => Advertisement::where('approval_status', 'rejected')->count(),
            'active' => Advertisement::where('status', 'active')->count(),
            'paused' => Advertisement::where('status', 'paused')->count(),
            'expired' => Advertisement::where('status', 'expired')->count(),
        ];

        return $this->successResponse($campaigns->items(), 'Admin campaigns retrieved.', 200, [
            'current_page' => $campaigns->currentPage(),
            'total' => $campaigns->total(),
            'per_page' => $campaigns->perPage(),
            'last_page' => $campaigns->lastPage(),
            'counts' => $stats,
        ]);
    }

    /**
     * Admin: Approve campaign with automatic publication scheduling check.
     */
    public function approve(Request $request, int $id): JsonResponse
    {
        $ad = Advertisement::findOrFail($id);
        $admin = $request->user();

        $ad->approval_status = 'approved';
        $ad->approved_by = $admin->id;
        $ad->approved_at = now();
        $ad->rejection_reason = null;

        $now = now();
        // Check if start date arrived and payment rule satisfied
        if ($ad->isPaid()) {
            if ($ad->start_date <= $now && $ad->end_date >= $now) {
                $ad->status = 'active';
            } elseif ($ad->start_date > $now) {
                $ad->status = 'scheduled';
            } else {
                $ad->status = 'expired';
            }
        } else {
            // Awaiting Phase 3 payment
            $ad->status = 'approved';
        }

        $ad->save();

        AuditLog::create([
            'user_id' => $admin->id,
            'action' => 'campaign_approved_by_admin',
            'entity_type' => 'Advertisement',
            'entity_id' => $ad->id,
            'description' => "Campaign '{$ad->title}' approved by administrator {$admin->email}.",
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        Notification::create([
            'user_id' => $ad->created_by,
            'title' => 'Campaign Approved!',
            'message' => "Your campaign '{$ad->title}' has been approved by the administration.",
            'notification_type' => 'campaign_approved',
            'is_read' => false,
        ]);

        return $this->successResponse($ad->fresh(['package', 'employer', 'approvedBy']), 'Campaign approved successfully.');
    }

    /**
     * Admin: Reject campaign with mandatory explanation.
     */
    public function reject(Request $request, int $id): JsonResponse
    {
        $request->validate([
            'rejection_reason' => 'required|string|min:5|max:1000',
        ]);

        $ad = Advertisement::findOrFail($id);
        $admin = $request->user();

        $ad->approval_status = 'rejected';
        $ad->status = 'rejected';
        $ad->rejection_reason = $request->rejection_reason;
        $ad->approved_by = $admin->id;
        $ad->approved_at = now();
        $ad->save();

        AuditLog::create([
            'user_id' => $admin->id,
            'action' => 'campaign_rejected_by_admin',
            'entity_type' => 'Advertisement',
            'entity_id' => $ad->id,
            'description' => "Campaign '{$ad->title}' rejected. Reason: {$request->rejection_reason}",
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        Notification::create([
            'user_id' => $ad->created_by,
            'title' => 'Campaign Revision Required',
            'message' => "Your campaign '{$ad->title}' was rejected. Reason: {$request->rejection_reason}",
            'notification_type' => 'campaign_rejected',
            'is_read' => false,
        ]);

        return $this->successResponse($ad->fresh(['package', 'employer']), 'Campaign rejected.');
    }

    /**
     * Admin: Suspend or pause campaign immediately.
     */
    public function suspend(Request $request, int $id): JsonResponse
    {
        $ad = Advertisement::findOrFail($id);
        $admin = $request->user();

        $ad->status = 'paused';
        $ad->save();

        AuditLog::create([
            'user_id' => $admin->id,
            'action' => 'campaign_suspended_by_admin',
            'entity_type' => 'Advertisement',
            'entity_id' => $ad->id,
            'description' => "Campaign '{$ad->title}' suspended by administrator {$admin->email}.",
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);

        return $this->successResponse($ad, 'Campaign has been suspended.');
    }
}
