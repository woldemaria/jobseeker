<?php

namespace Tests\Feature;

use App\Models\Advertisement;
use App\Models\AdsConsent;
use App\Models\AdsConsentHistory;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class AdsConsentManagementTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    public function test_can_retrieve_default_consent_status_when_no_record_exists(): void
    {
        $response = $this->getJson('/api/v1/ads-consent');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'consent' => null,
                    'current_policy_version' => '1.0',
                    'requires_reconsent' => true,
                    'has_consent_record' => false,
                ],
            ]);
    }

    public function test_can_save_accept_all_consent(): void
    {
        $consentUuid = (string) Str::uuid();

        $response = $this->postJson('/api/v1/ads-consent', [
            'consent_uuid' => $consentUuid,
            'status' => 'accepted',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'consent_uuid' => $consentUuid,
                    'status' => 'accepted',
                    'personalized_ads' => true,
                    'non_personalized_ads' => true,
                    'analytics' => true,
                    'advertising_cookies' => true,
                    'policy_version' => '1.0',
                ],
            ]);

        $this->assertDatabaseHas('ads_consents', [
            'consent_uuid' => $consentUuid,
            'status' => 'accepted',
            'personalized_ads' => 1,
            'non_personalized_ads' => 1,
            'analytics' => 1,
            'advertising_cookies' => 1,
        ]);

        $this->assertDatabaseHas('ads_consent_histories', [
            'action' => 'grant',
            'status' => 'accepted',
            'policy_version' => '1.0',
        ]);
    }

    public function test_can_save_reject_all_consent(): void
    {
        $consentUuid = (string) Str::uuid();

        $response = $this->postJson('/api/v1/ads-consent', [
            'consent_uuid' => $consentUuid,
            'status' => 'rejected',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'consent_uuid' => $consentUuid,
                    'status' => 'rejected',
                    'personalized_ads' => false,
                    'non_personalized_ads' => false,
                    'analytics' => false,
                    'advertising_cookies' => false,
                ],
            ]);

        $this->assertDatabaseHas('ads_consents', [
            'consent_uuid' => $consentUuid,
            'status' => 'rejected',
            'personalized_ads' => 0,
            'non_personalized_ads' => 0,
            'analytics' => 0,
            'advertising_cookies' => 0,
        ]);
    }

    public function test_can_save_custom_granular_preferences(): void
    {
        $consentUuid = (string) Str::uuid();

        $response = $this->postJson('/api/v1/ads-consent', [
            'consent_uuid' => $consentUuid,
            'status' => 'custom',
            'personalized_ads' => false,
            'non_personalized_ads' => true,
            'analytics' => true,
            'advertising_cookies' => false,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'consent_uuid' => $consentUuid,
                    'status' => 'custom',
                    'personalized_ads' => false,
                    'non_personalized_ads' => true,
                    'analytics' => true,
                    'advertising_cookies' => false,
                ],
            ]);

        $this->assertDatabaseHas('ads_consents', [
            'consent_uuid' => $consentUuid,
            'personalized_ads' => 0,
            'non_personalized_ads' => 1,
            'analytics' => 1,
            'advertising_cookies' => 0,
        ]);
    }

    public function test_can_withdraw_consent_completely(): void
    {
        $consentUuid = (string) Str::uuid();

        // Initial consent
        $this->postJson('/api/v1/ads-consent', [
            'consent_uuid' => $consentUuid,
            'status' => 'accepted',
        ]);

        // Withdraw consent
        $withdrawResponse = $this->postJson('/api/v1/ads-consent/withdraw', [
            'consent_uuid' => $consentUuid,
        ]);

        $withdrawResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'status' => 'withdrawn',
                    'personalized_ads' => false,
                    'non_personalized_ads' => false,
                    'analytics' => false,
                    'advertising_cookies' => false,
                ],
            ]);

        $consent = AdsConsent::where('consent_uuid', $consentUuid)->first();
        $this->assertNotNull($consent->withdrawn_at);
        $this->assertEquals('withdrawn', $consent->status);

        $this->assertDatabaseHas('ads_consent_histories', [
            'ads_consent_id' => $consent->id,
            'action' => 'withdraw',
            'status' => 'withdrawn',
        ]);
    }

    public function test_advertisements_delivery_respects_withdrawn_or_rejected_consent(): void
    {
        $consentUuid = (string) Str::uuid();

        // Reject ads
        $this->postJson('/api/v1/ads-consent', [
            'consent_uuid' => $consentUuid,
            'status' => 'rejected',
        ]);

        $response = $this->withHeader('X-Consent-ID', $consentUuid)
            ->getJson('/api/v1/advertisements');

        $response->assertStatus(200);
        $this->assertEmpty($response->json('data'));
    }

    public function test_impression_and_click_tracking_are_blocked_when_analytics_consent_denied(): void
    {
        $ad = Advertisement::first();
        $this->assertNotNull($ad);

        $consentUuid = (string) Str::uuid();

        // Custom consent: allow non-personalized ads, but disallow analytics
        $this->postJson('/api/v1/ads-consent', [
            'consent_uuid' => $consentUuid,
            'status' => 'custom',
            'personalized_ads' => false,
            'non_personalized_ads' => true,
            'analytics' => false,
            'advertising_cookies' => false,
        ]);

        $initialImpressions = $ad->impressions_count;
        $initialClicks = $ad->clicks_count;

        // Attempt impression tracking with consent ID
        $impResponse = $this->withHeader('X-Consent-ID', $consentUuid)
            ->postJson("/api/v1/advertisements/{$ad->id}/impression");

        $impResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'tracking_allowed' => false,
                ],
            ]);

        $ad->refresh();
        $this->assertEquals($initialImpressions, $ad->impressions_count, 'Impressions count must not increment without analytics consent');

        // Attempt click tracking with consent ID
        $clickResponse = $this->withHeader('X-Consent-ID', $consentUuid)
            ->postJson("/api/v1/advertisements/{$ad->id}/click");

        $clickResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'tracking_allowed' => false,
                ],
            ]);

        $ad->refresh();
        $this->assertEquals($initialClicks, $ad->clicks_count, 'Clicks count must not increment without analytics consent');
    }

    public function test_can_link_anonymous_consent_to_authenticated_user(): void
    {
        $user = User::factory()->create();
        $consentUuid = (string) Str::uuid();

        // Anonymous consent
        $this->postJson('/api/v1/ads-consent', [
            'consent_uuid' => $consentUuid,
            'status' => 'accepted',
        ]);

        // User logs in and syncs
        $syncResponse = $this->actingAs($user)
            ->postJson('/api/v1/ads-consent/sync', [
                'consent_uuid' => $consentUuid,
            ]);

        $syncResponse->assertStatus(200);

        $this->assertDatabaseHas('ads_consents', [
            'consent_uuid' => $consentUuid,
            'user_id' => $user->id,
            'status' => 'accepted',
        ]);

        $this->assertDatabaseHas('ads_consent_histories', [
            'user_id' => $user->id,
            'action' => 'link_account',
        ]);
    }

    public function test_can_retrieve_consent_audit_history(): void
    {
        $consentUuid = (string) Str::uuid();

        // 1. Initial grant
        $this->postJson('/api/v1/ads-consent', [
            'consent_uuid' => $consentUuid,
            'status' => 'accepted',
        ]);

        // 2. Preference change
        $this->postJson('/api/v1/ads-consent', [
            'consent_uuid' => $consentUuid,
            'status' => 'custom',
            'personalized_ads' => false,
            'non_personalized_ads' => true,
            'analytics' => false,
            'advertising_cookies' => false,
        ]);

        $response = $this->withHeader('X-Consent-ID', $consentUuid)
            ->getJson('/api/v1/ads-consent/history');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'success',
                'data' => [
                    '*' => [
                        'id',
                        'ads_consent_id',
                        'action',
                        'policy_version',
                        'status',
                        'preferences',
                        'created_at',
                    ],
                ],
            ]);

        $this->assertCount(2, $response->json('data'));
    }

    public function test_withdrawn_consent_enforces_zero_ads_and_blocks_all_telemetry(): void
    {
        $ad = Advertisement::first();
        $this->assertNotNull($ad);
        $consentUuid = (string) Str::uuid();

        // 1. Initial consent
        $this->postJson('/api/v1/ads-consent', [
            'consent_uuid' => $consentUuid,
            'status' => 'accepted',
        ]);

        // 2. Withdraw consent
        $this->postJson('/api/v1/ads-consent/withdraw', [
            'consent_uuid' => $consentUuid,
        ]);

        // 3. Ad delivery must return 0 advertisements
        $adResponse = $this->withHeader('X-Consent-ID', $consentUuid)
            ->getJson('/api/v1/advertisements');
        $adResponse->assertStatus(200);
        $this->assertEmpty($adResponse->json('data'));

        // 4. Impression tracking must be blocked
        $initialImpressions = $ad->impressions_count;
        $impResponse = $this->withHeader('X-Consent-ID', $consentUuid)
            ->postJson("/api/v1/advertisements/{$ad->id}/impression");
        $impResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => ['tracking_allowed' => false],
            ]);
        $ad->refresh();
        $this->assertEquals($initialImpressions, $ad->impressions_count);

        // 5. Click tracking must be blocked
        $initialClicks = $ad->clicks_count;
        $clickResponse = $this->withHeader('X-Consent-ID', $consentUuid)
            ->postJson("/api/v1/advertisements/{$ad->id}/click");
        $clickResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => ['tracking_allowed' => false],
            ]);
        $ad->refresh();
        $this->assertEquals($initialClicks, $ad->clicks_count);
    }

    public function test_policy_version_mismatch_flags_reconsent_requirement(): void
    {
        $consentUuid = (string) Str::uuid();

        // Create consent with older policy version
        $consent = AdsConsent::create([
            'consent_uuid' => $consentUuid,
            'status' => 'accepted',
            'personalized_ads' => true,
            'non_personalized_ads' => true,
            'analytics' => true,
            'advertising_cookies' => true,
            'policy_version' => '0.9',
            'consented_at' => now()->subMonths(3),
        ]);

        $response = $this->withHeader('X-Consent-ID', $consentUuid)
            ->getJson('/api/v1/ads-consent');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'current_policy_version' => '1.0',
                    'requires_reconsent' => true,
                    'has_consent_record' => true,
                ],
            ]);
    }

    public function test_authenticated_user_consent_takes_precedence_and_updates_cleanly(): void
    {
        $user = User::factory()->create();

        // Authenticated user saves preferences
        $response = $this->actingAs($user)->postJson('/api/v1/ads-consent', [
            'status' => 'custom',
            'personalized_ads' => true,
            'non_personalized_ads' => true,
            'analytics' => false,
            'advertising_cookies' => false,
        ]);

        $response->assertStatus(200);

        // Fetch consent using Bearer token without X-Consent-ID
        $fetchResponse = $this->actingAs($user)->getJson('/api/v1/ads-consent');

        $fetchResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'consent' => [
                        'user_id' => $user->id,
                        'status' => 'custom',
                        'personalized_ads' => true,
                        'non_personalized_ads' => true,
                        'analytics' => false,
                        'advertising_cookies' => false,
                    ],
                    'requires_reconsent' => false,
                ],
            ]);
    }
}
