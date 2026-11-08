<?php

namespace App\Http\Controllers\Api;

use App\Models\AdsConsent;
use App\Models\AdsConsentHistory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class AdsConsentController extends BaseApiController
{
    public const CURRENT_POLICY_VERSION = '1.0';

    /**
     * Resolve the current consent model from authenticated user or consent identifier.
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
     * Get current ads consent status and policy version.
     */
    public function show(Request $request): JsonResponse
    {
        $consent = $this->resolveConsent($request);

        $requiresReconsent = true;
        if ($consent && $consent->policy_version === self::CURRENT_POLICY_VERSION && $consent->status !== 'withdrawn') {
            $requiresReconsent = false;
        }

        return $this->successResponse([
            'consent' => $consent,
            'current_policy_version' => self::CURRENT_POLICY_VERSION,
            'requires_reconsent' => $requiresReconsent,
            'has_consent_record' => $consent !== null,
        ], 'Ads consent status retrieved successfully.');
    }

    /**
     * Store or update ads consent choices.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'consent_uuid' => 'nullable|string|max:64',
            'status' => 'required|in:accepted,rejected,custom,withdrawn',
            'personalized_ads' => 'nullable|boolean',
            'non_personalized_ads' => 'nullable|boolean',
            'analytics' => 'nullable|boolean',
            'advertising_cookies' => 'nullable|boolean',
            'policy_version' => 'nullable|string|max:20',
        ]);

        $user = $request->user() ?: auth('sanctum')->user();
        $status = $validated['status'];
        $policyVersion = $validated['policy_version'] ?? self::CURRENT_POLICY_VERSION;

        // Determine granular preferences based on explicit user action
        if ($status === 'accepted') {
            $personalized = true;
            $nonPersonalized = true;
            $analytics = true;
            $cookies = true;
        } elseif ($status === 'rejected' || $status === 'withdrawn') {
            $personalized = false;
            $nonPersonalized = false;
            $analytics = false;
            $cookies = false;
        } else { // 'custom'
            $personalized = (bool) ($validated['personalized_ads'] ?? false);
            $nonPersonalized = (bool) ($validated['non_personalized_ads'] ?? false);
            $analytics = (bool) ($validated['analytics'] ?? false);
            $cookies = (bool) ($validated['advertising_cookies'] ?? false);
        }

        $consentUuid = ($validated['consent_uuid'] ?? null)
            ?: $request->header('X-Consent-ID')
            ?: (string) Str::uuid();

        // Check if an existing consent record exists for this user or anonymous UUID
        $consent = null;
        if ($user) {
            $consent = AdsConsent::where('user_id', $user->id)->first();
        }

        if (!$consent && $consentUuid) {
            $consent = AdsConsent::where('consent_uuid', $consentUuid)->first();
        }

        $isNew = ($consent === null);
        $action = $isNew ? 'grant' : ($status === 'withdrawn' ? 'withdraw' : 'update');

        if (!$consent) {
            $consent = new AdsConsent();
            $consent->consent_uuid = $consentUuid;
        }

        if ($user) {
            $consent->user_id = $user->id;
        }

        $consent->status = $status;
        $consent->personalized_ads = $personalized;
        $consent->non_personalized_ads = $nonPersonalized;
        $consent->analytics = $analytics;
        $consent->advertising_cookies = $cookies;
        $consent->policy_version = $policyVersion;
        $consent->ip_address = $request->ip();
        $consent->user_agent = $request->userAgent();
        $consent->consented_at = now();

        if ($status === 'withdrawn') {
            $consent->withdrawn_at = now();
        } else {
            $consent->withdrawn_at = null;
        }

        $consent->save();

        // Record immutable audit history
        AdsConsentHistory::create([
            'ads_consent_id' => $consent->id,
            'user_id' => $user?->id,
            'action' => $action,
            'policy_version' => $policyVersion,
            'status' => $status,
            'preferences' => [
                'personalized_ads' => $personalized,
                'non_personalized_ads' => $nonPersonalized,
                'analytics' => $analytics,
                'advertising_cookies' => $cookies,
            ],
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'created_at' => now(),
        ]);

        return $this->successResponse($consent, 'Privacy and advertising preferences saved successfully.', 200);
    }

    /**
     * Completely withdraw all advertising consent.
     */
    public function withdraw(Request $request): JsonResponse
    {
        $consent = $this->resolveConsent($request);
        $user = $request->user() ?: auth('sanctum')->user();
        $consentUuid = $request->header('X-Consent-ID')
            ?: $request->input('consent_uuid')
            ?: ($consent ? $consent->consent_uuid : (string) Str::uuid());

        if (!$consent) {
            $consent = new AdsConsent();
            $consent->consent_uuid = $consentUuid;
            if ($user) {
                $consent->user_id = $user->id;
            }
        }

        $consent->status = 'withdrawn';
        $consent->personalized_ads = false;
        $consent->non_personalized_ads = false;
        $consent->analytics = false;
        $consent->advertising_cookies = false;
        $consent->policy_version = self::CURRENT_POLICY_VERSION;
        $consent->ip_address = $request->ip();
        $consent->user_agent = $request->userAgent();
        $consent->withdrawn_at = now();
        $consent->save();

        // Audit log entry
        AdsConsentHistory::create([
            'ads_consent_id' => $consent->id,
            'user_id' => $user?->id,
            'action' => 'withdraw',
            'policy_version' => self::CURRENT_POLICY_VERSION,
            'status' => 'withdrawn',
            'preferences' => [
                'personalized_ads' => false,
                'non_personalized_ads' => false,
                'analytics' => false,
                'advertising_cookies' => false,
            ],
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'created_at' => now(),
        ]);

        return $this->successResponse($consent, 'Advertising consent successfully withdrawn. All ad tracking has been stopped.');
    }

    /**
     * Sync anonymous consent with authenticated user account upon login.
     */
    public function syncAccount(Request $request): JsonResponse
    {
        $user = $request->user() ?: auth('sanctum')->user();
        if (!$user) {
            return $this->errorResponse('Authentication required to sync consent with account.', 401);
        }

        $anonymousUuid = $request->input('consent_uuid') ?: $request->header('X-Consent-ID');
        if (!$anonymousUuid) {
            $userConsent = AdsConsent::where('user_id', $user->id)->first();
            return $this->successResponse($userConsent, 'No anonymous UUID provided; current user consent retained.');
        }

        $userConsent = AdsConsent::where('user_id', $user->id)->first();
        $anonConsent = AdsConsent::where('consent_uuid', $anonymousUuid)->first();

        if ($anonConsent && !$userConsent) {
            // Transfer anonymous consent to the authenticated user
            $anonConsent->user_id = $user->id;
            $anonConsent->save();

            AdsConsentHistory::create([
                'ads_consent_id' => $anonConsent->id,
                'user_id' => $user->id,
                'action' => 'link_account',
                'policy_version' => $anonConsent->policy_version,
                'status' => $anonConsent->status,
                'preferences' => [
                    'personalized_ads' => $anonConsent->personalized_ads,
                    'non_personalized_ads' => $anonConsent->non_personalized_ads,
                    'analytics' => $anonConsent->analytics,
                    'advertising_cookies' => $anonConsent->advertising_cookies,
                ],
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'created_at' => now(),
            ]);

            return $this->successResponse($anonConsent, 'Anonymous consent linked to user account.');
        }

        return $this->successResponse($userConsent ?: $anonConsent, 'Consent synced with user account.');
    }

    /**
     * Get audit log history of consent decisions.
     */
    public function history(Request $request): JsonResponse
    {
        $consent = $this->resolveConsent($request);
        if (!$consent) {
            return $this->successResponse([], 'No consent history found.');
        }

        $histories = AdsConsentHistory::where('ads_consent_id', $consent->id)
            ->latest('created_at')
            ->limit(50)
            ->get();

        return $this->successResponse($histories, 'Consent audit history retrieved successfully.');
    }
}
