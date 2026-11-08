<?php

namespace App\Http\Controllers\Api;

use App\Models\Advertisement;
use App\Models\AdvertisementEvent;
use App\Models\AdsConsent;
use App\Services\ImageUploadService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AdvertisementController extends BaseApiController
{
    /**
     * Resolve ads consent for the current request.
     */
    protected function resolveConsent(Request $request): ?AdsConsent
    {
        $user = $request->user() ?: auth('sanctum')->user();
        if ($user) {
            $userConsent = AdsConsent::where('user_id', $user->id)->first();
            if ($userConsent) {
                return $userConsent;
            }
        }

        $consentUuid = $request->header('X-Consent-ID')
            ?: $request->input('consent_uuid')
            ?: $request->query('consent_id');

        if ($consentUuid) {
            return AdsConsent::where('consent_uuid', $consentUuid)->first();
        }

        return null;
    }

    /**
     * Get active advertisements for clients, with optional placement & personalization.
     */
    public function index(Request $request): JsonResponse
    {
        $consent = $this->resolveConsent($request);

        // Privacy enforcement: If user has explicitly withdrawn consent or rejected non-personalized ads, serve no ads
        if ($consent && ($consent->isWithdrawn() || !$consent->allowsNonPersonalizedAds())) {
            return $this->successResponse([], 'Advertisements disabled per privacy consent preferences.');
        }

        $query = Advertisement::active()->with(['employer', 'job']);

        if ($request->filled('placement')) {
            $query->placement($request->placement);
        }

        if ($request->filled('category')) {
            $query->where('category', $request->category);
        }

        $user = $request->user() ?: auth('sanctum')->user();
        if ($user) {
            $roleName = $user->isEmployer() ? 'employer' : 'job_seeker';
            $query->forRole($roleName);
        } else {
            $query->forRole('all');
        }

        $ads = $query->orderByDesc('priority')->latest()->get();

        // Determine if personalization is permitted by privacy consent
        $allowPersonalization = true;
        if ($consent) {
            $allowPersonalization = $consent->allowsPersonalizedAds();
        } else {
            // Default to client request param if no explicit consent object recorded
            $allowPersonalization = $request->boolean('personalized', true);
        }

        // Smart personalization based on user skills (respects user privacy/consent)
        if ($allowPersonalization && $user && $user->jobSeekerProfile) {
            $candidateSkillIds = $user->jobSeekerProfile->skills()->pluck('skills.id')->toArray();
            if (!empty($candidateSkillIds)) {
                $candidateSkillSet = array_flip($candidateSkillIds);
                $ads = $ads->sortByDesc(function ($ad) use ($candidateSkillSet) {
                    $score = $ad->priority * 10;
                    if (!empty($ad->target_skills) && is_array($ad->target_skills)) {
                        foreach ($ad->target_skills as $skillId) {
                            if (isset($candidateSkillSet[$skillId])) {
                                $score += 25;
                            }
                        }
                    }
                    return $score;
                })->values();
            }
        }

        return $this->successResponse($ads, 'Advertisements retrieved successfully.');
    }

    /**
     * Track impression for an advertisement.
     */
    public function recordImpression(Request $request, int $id): JsonResponse
    {
        $ad = Advertisement::findOrFail($id);
        $consent = $this->resolveConsent($request);

        // Privacy enforcement: Check whether analytics consent is granted
        if ($consent && ($consent->isWithdrawn() || !$consent->allowsAnalytics())) {
            return $this->successResponse([
                'id' => $ad->id,
                'impressions_count' => $ad->impressions_count,
                'tracking_allowed' => false,
            ], 'Impression tracking skipped due to privacy consent preferences.');
        }

        $ad->increment('impressions_count');

        $user = $request->user() ?: auth('sanctum')->user();

        // If advertising cookies/cross-session tracking disallowed, redact IP and user agent
        $trackCookies = $consent ? $consent->allowsCookies() : true;

        AdvertisementEvent::create([
            'advertisement_id' => $ad->id,
            'user_id' => $user?->id,
            'event_type' => 'impression',
            'ip_address' => $trackCookies ? $request->ip() : '0.0.0.0',
            'user_agent' => $trackCookies ? $request->userAgent() : 'Anonymized/Consent-Restricted',
            'created_at' => now(),
        ]);

        return $this->successResponse([
            'id' => $ad->id,
            'impressions_count' => $ad->impressions_count,
            'tracking_allowed' => true,
        ], 'Impression recorded.');
    }

    /**
     * Track click for an advertisement.
     */
    public function recordClick(Request $request, int $id): JsonResponse
    {
        $ad = Advertisement::findOrFail($id);
        $consent = $this->resolveConsent($request);

        // Privacy enforcement: Check whether analytics consent is granted
        if ($consent && ($consent->isWithdrawn() || !$consent->allowsAnalytics())) {
            return $this->successResponse([
                'id' => $ad->id,
                'clicks_count' => $ad->clicks_count,
                'cta_target' => $ad->cta_target,
                'cta_type' => $ad->cta_type,
                'ctr' => $ad->ctr,
                'tracking_allowed' => false,
            ], 'Click recorded without analytics telemetry per privacy consent.');
        }

        $ad->increment('clicks_count');

        $user = $request->user() ?: auth('sanctum')->user();
        $trackCookies = $consent ? $consent->allowsCookies() : true;

        AdvertisementEvent::create([
            'advertisement_id' => $ad->id,
            'user_id' => $user?->id,
            'event_type' => 'click',
            'ip_address' => $trackCookies ? $request->ip() : '0.0.0.0',
            'user_agent' => $trackCookies ? $request->userAgent() : 'Anonymized/Consent-Restricted',
            'created_at' => now(),
        ]);

        return $this->successResponse([
            'id' => $ad->id,
            'clicks_count' => $ad->clicks_count,
            'cta_target' => $ad->cta_target,
            'cta_type' => $ad->cta_type,
            'ctr' => $ad->ctr,
            'tracking_allowed' => true,
        ], 'Click recorded.');
    }

    /**
     * Admin & Employer: List all advertisements with management details.
     */
    public function adminIndex(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = Advertisement::with(['employer', 'job', 'creator'])->latest();

        if (!$user->isAdmin()) {
            $employerIds = $user->employers()->pluck('employers.id')->toArray();
            $query->where(function ($q) use ($user, $employerIds) {
                $q->where('created_by', $user->id);
                if (!empty($employerIds)) {
                    $q->orWhereIn('employer_id', $employerIds);
                }
            });
        }

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        if ($request->filled('placement')) {
            $query->where('placement', $request->placement);
        }

        if ($request->filled('category')) {
            $query->where('category', $request->category);
        }

        $ads = $query->paginate($request->get('per_page', 20));

        return $this->successResponse($ads->items(), 'Campaigns retrieved.', 200, [
            'current_page' => $ads->currentPage(),
            'total' => $ads->total(),
            'per_page' => $ads->perPage(),
            'last_page' => $ads->lastPage(),
        ]);
    }

    /**
     * Admin & Employer: Create a new advertisement campaign.
     */
    public function adminStore(Request $request): JsonResponse
    {
        $user = $request->user();
        $validated = $request->validate([
            'title' => 'required|string|max:200',
            'title_am' => 'nullable|string|max:200',
            'subtitle' => 'nullable|string|max:300',
            'subtitle_am' => 'nullable|string|max:300',
            'badge_text' => 'nullable|string|max:50',
            'badge_text_am' => 'nullable|string|max:50',
            'image_url' => 'nullable|string',
            'image_file' => 'nullable|file|image|max:10240',
            'category' => 'required|string|in:featured_jobs,company_promotions,recruitment_campaigns,sponsored_vacancies,announcements',
            'placement' => 'required|string|in:hero,dashboard,job_list,category_specific',
            'target_role' => 'nullable|string|in:all,job_seeker,employer',
            'target_skills' => 'nullable|array',
            'target_category' => 'nullable|string|max:100',
            'cta_type' => 'required|string|in:apply_now,view_details,explore_jobs,register,visit_company,external_link',
            'cta_text' => 'required|string|max:60',
            'cta_text_am' => 'nullable|string|max:60',
            'cta_target' => 'required|string',
            'background_color' => 'nullable|string|max:30',
            'status' => 'nullable|string|in:active,scheduled,paused,expired,pending_approval',
            'priority' => 'nullable|integer',
            'start_date' => 'required|date',
            'end_date' => 'required|date|after_or_equal:start_date',
            'employer_id' => 'nullable|exists:employers,id',
            'job_id' => 'nullable|exists:jobs,id',
        ]);

        $imageSource = $request->file('image_file') ?: $request->input('image_url');
        if (!$imageSource) {
            return $this->errorResponse('An image file or valid image URL is required.', 422);
        }

        $validated['image_url'] = ImageUploadService::storeImage($imageSource, 'advertisements');
        unset($validated['image_file']);

        $validated['created_by'] = $user->id;
        $validated['status'] = $validated['status'] ?? 'active';
        $validated['priority'] = $validated['priority'] ?? 0;
        $validated['background_color'] = $validated['background_color'] ?? '#0D6B4F';

        if (!$user->isAdmin()) {
            $employerIds = $user->employers()->pluck('employers.id')->toArray();
            if (!empty($validated['employer_id']) && in_array($validated['employer_id'], $employerIds)) {
                // Keep selected employer_id
            } elseif (!empty($employerIds)) {
                $validated['employer_id'] = $employerIds[0];
            } else {
                $employer = \App\Models\Employer::firstOrCreate(
                    ['email' => $user->email],
                    [
                        'organization_name' => $user->name . ' Enterprise',
                        'phone' => $user->phone ?? '+251911000000',
                        'verification_status' => 'pending',
                    ]
                );
                $user->employers()->syncWithoutDetaching([$employer->id => ['member_role' => 'admin']]);
                $validated['employer_id'] = $employer->id;
            }
        }

        $ad = Advertisement::create($validated);

        return $this->successResponse($ad->load(['employer', 'job']), 'Campaign created successfully.', 201);
    }

    /**
     * Admin & Employer: View campaign profile with performance stats.
     */
    public function adminShow(Request $request, int $id): JsonResponse
    {
        $ad = Advertisement::with(['employer', 'job', 'creator'])->findOrFail($id);
        $user = $request->user();

        if (!$user->isAdmin()) {
            $employerIds = $user->employers()->pluck('employers.id')->toArray();
            $isOwner = $ad->created_by === $user->id || (!empty($employerIds) && in_array($ad->employer_id, $employerIds));
            if (!$isOwner) {
                return $this->errorResponse('Access denied. You can only view campaigns belonging to your organization.', 403);
            }
        }

        $dailyStats = DB::table('advertisement_events')
            ->where('advertisement_id', $ad->id)
            ->selectRaw('DATE(created_at) as date, event_type, count(*) as count')
            ->groupBy('date', 'event_type')
            ->orderBy('date', 'desc')
            ->take(14)
            ->get();

        return $this->successResponse([
            'advertisement' => $ad,
            'daily_events' => $dailyStats,
        ], 'Campaign details retrieved.');
    }

    /**
     * Admin & Employer: Update advertisement campaign.
     */
    public function adminUpdate(Request $request, int $id): JsonResponse
    {
        $ad = Advertisement::findOrFail($id);
        $user = $request->user();

        if (!$user->isAdmin()) {
            $employerIds = $user->employers()->pluck('employers.id')->toArray();
            $isOwner = $ad->created_by === $user->id || (!empty($employerIds) && in_array($ad->employer_id, $employerIds));
            if (!$isOwner) {
                return $this->errorResponse('Access denied. You can only edit campaigns belonging to your organization.', 403);
            }
        }

        $validated = $request->validate([
            'title' => 'sometimes|string|max:200',
            'title_am' => 'nullable|string|max:200',
            'subtitle' => 'nullable|string|max:300',
            'subtitle_am' => 'nullable|string|max:300',
            'badge_text' => 'nullable|string|max:50',
            'badge_text_am' => 'nullable|string|max:50',
            'image_url' => 'nullable|string',
            'image_file' => 'nullable|file|image|max:10240',
            'category' => 'sometimes|string|in:featured_jobs,company_promotions,recruitment_campaigns,sponsored_vacancies,announcements',
            'placement' => 'sometimes|string|in:hero,dashboard,job_list,category_specific',
            'target_role' => 'nullable|string|in:all,job_seeker,employer',
            'target_skills' => 'nullable|array',
            'target_category' => 'nullable|string|max:100',
            'cta_type' => 'sometimes|string|in:apply_now,view_details,explore_jobs,register,visit_company,external_link',
            'cta_text' => 'sometimes|string|max:60',
            'cta_text_am' => 'nullable|string|max:60',
            'cta_target' => 'sometimes|string',
            'background_color' => 'nullable|string|max:30',
            'status' => 'sometimes|string|in:active,scheduled,paused,expired,pending_approval',
            'priority' => 'nullable|integer',
            'start_date' => 'sometimes|date',
            'end_date' => 'sometimes|date',
            'employer_id' => 'nullable|exists:employers,id',
            'job_id' => 'nullable|exists:jobs,id',
        ]);

        if ($request->hasFile('image_file') || $request->filled('image_url')) {
            $imageSource = $request->file('image_file') ?: $request->input('image_url');
            $validated['image_url'] = ImageUploadService::storeImage($imageSource, 'advertisements');
        }
        unset($validated['image_file']);

        $ad->update($validated);

        return $this->successResponse($ad->fresh(['employer', 'job']), 'Campaign updated successfully.');
    }

    /**
     * Admin & Employer: Toggle status (pause, activate).
     */
    public function adminToggleStatus(Request $request, int $id): JsonResponse
    {
        $ad = Advertisement::findOrFail($id);
        $user = $request->user();

        if (!$user->isAdmin()) {
            $employerIds = $user->employers()->pluck('employers.id')->toArray();
            $isOwner = $ad->created_by === $user->id || (!empty($employerIds) && in_array($ad->employer_id, $employerIds));
            if (!$isOwner) {
                return $this->errorResponse('Access denied. You can only update campaigns belonging to your organization.', 403);
            }
        }

        $validated = $request->validate([
            'status' => 'required|string|in:active,paused,expired,pending_approval',
        ]);

        $ad->status = $validated['status'];
        $ad->save();

        return $this->successResponse($ad, "Campaign status updated to {$ad->status}.");
    }

    /**
     * Admin & Employer: Delete campaign.
     */
    public function adminDestroy(Request $request, int $id): JsonResponse
    {
        $ad = Advertisement::findOrFail($id);
        $user = $request->user();

        if (!$user->isAdmin()) {
            $employerIds = $user->employers()->pluck('employers.id')->toArray();
            $isOwner = $ad->created_by === $user->id || (!empty($employerIds) && in_array($ad->employer_id, $employerIds));
            if (!$isOwner) {
                return $this->errorResponse('Access denied. You can only delete campaigns belonging to your organization.', 403);
            }
        }

        $ad->delete();

        return $this->successResponse(null, 'Campaign deleted successfully.');
    }

    /**
     * Admin & Employer: Overall advertisement analytics.
     */
    public function adminAnalytics(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = Advertisement::query();

        if (!$user->isAdmin()) {
            $employerIds = $user->employers()->pluck('employers.id')->toArray();
            $query->where(function ($q) use ($user, $employerIds) {
                $q->where('created_by', $user->id);
                if (!empty($employerIds)) {
                    $q->orWhereIn('employer_id', $employerIds);
                }
            });
        }

        $totalAds = (clone $query)->count();
        $activeAds = (clone $query)->active()->count();
        $totalImpressions = (clone $query)->sum('impressions_count');
        $totalClicks = (clone $query)->sum('clicks_count');

        $overallCtr = $totalImpressions > 0
            ? round(($totalClicks / $totalImpressions) * 100, 2)
            : 0.0;

        $categoryBreakdown = (clone $query)->select('category', DB::raw('count(*) as count, sum(impressions_count) as impressions, sum(clicks_count) as clicks'))
            ->groupBy('category')
            ->get();

        $placementBreakdown = (clone $query)->select('placement', DB::raw('count(*) as count, sum(impressions_count) as impressions, sum(clicks_count) as clicks'))
            ->groupBy('placement')
            ->get();

        return $this->successResponse([
            'summary' => [
                'total_campaigns' => $totalAds,
                'active_campaigns' => $activeAds,
                'total_impressions' => $totalImpressions,
                'total_clicks' => $totalClicks,
                'overall_ctr' => $overallCtr,
            ],
            'by_category' => $categoryBreakdown,
            'by_placement' => $placementBreakdown,
        ], 'Advertisement analytics generated.');
    }
}
