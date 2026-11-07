<?php

namespace Tests\Feature;

use App\Models\Advertisement;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdvertisementApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    public function test_can_fetch_public_active_advertisements(): void
    {
        $response = $this->getJson('/api/v1/advertisements');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'success',
                'message',
                'data' => [
                    '*' => [
                        'id',
                        'title',
                        'category',
                        'placement',
                        'cta_type',
                        'cta_target',
                        'ctr',
                    ],
                ],
            ]);
    }

    public function test_can_record_impression_and_click(): void
    {
        $ad = Advertisement::first();
        $this->assertNotNull($ad);

        $initialImpressions = $ad->impressions_count;
        $initialClicks = $ad->clicks_count;

        $impResponse = $this->postJson("/api/v1/advertisements/{$ad->id}/impression");
        $impResponse->assertStatus(200);

        $ad->refresh();
        $this->assertEquals($initialImpressions + 1, $ad->impressions_count);

        $clickResponse = $this->postJson("/api/v1/advertisements/{$ad->id}/click");
        $clickResponse->assertStatus(200);

        $ad->refresh();
        $this->assertEquals($initialClicks + 1, $ad->clicks_count);
    }

    public function test_admin_can_manage_and_view_advertisement_analytics(): void
    {
        $admin = User::whereHas('roles', fn($q) => $q->where('name', 'administrator'))->first();
        $this->assertNotNull($admin);

        // Fetch admin listing
        $listResponse = $this->actingAs($admin)->getJson('/api/v1/admin/advertisements');
        $listResponse->assertStatus(200);

        // Fetch analytics
        $analyticsResponse = $this->actingAs($admin)->getJson('/api/v1/admin/advertisements/analytics');
        $analyticsResponse->assertStatus(200)
            ->assertJsonStructure([
                'success',
                'data' => [
                    'summary' => [
                        'total_campaigns',
                        'active_campaigns',
                        'total_impressions',
                        'total_clicks',
                        'overall_ctr',
                    ],
                    'by_category',
                    'by_placement',
                ],
            ]);

        // Toggle ad status
        $ad = Advertisement::first();
        $toggleResponse = $this->actingAs($admin)->patchJson("/api/v1/admin/advertisements/{$ad->id}/status", [
            'status' => 'paused',
        ]);
        $toggleResponse->assertStatus(200);
        $this->assertEquals('paused', $ad->fresh()->status);
    }

    public function test_employer_can_create_and_manage_own_campaigns(): void
    {
        $employerUser = User::whereHas('roles', fn($q) => $q->where('name', 'employer'))->first();
        $this->assertNotNull($employerUser);

        // 1. Employer creates campaign
        $createResponse = $this->actingAs($employerUser)->postJson('/api/v1/admin/advertisements', [
            'title' => 'Employer Sponsored Tech Drive',
            'category' => 'recruitment_campaigns',
            'placement' => 'hero',
            'image_url' => 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf',
            'cta_type' => 'explore_jobs',
            'cta_text' => 'Explore Openings',
            'cta_target' => '/jobs',
            'start_date' => now()->toDateString(),
            'end_date' => now()->addDays(30)->toDateString(),
        ]);

        $createResponse->assertStatus(201);
        $createdId = $createResponse->json('data.id');
        $this->assertNotNull($createdId);

        // 2. Employer lists campaigns
        $listResponse = $this->actingAs($employerUser)->getJson('/api/v1/admin/advertisements');
        $listResponse->assertStatus(200);
        $this->assertGreaterThanOrEqual(1, count($listResponse->json('data')));

        // 3. Employer views own analytics
        $analyticsResponse = $this->actingAs($employerUser)->getJson('/api/v1/admin/advertisements/analytics');
        $analyticsResponse->assertStatus(200)
            ->assertJsonStructure([
                'success',
                'data' => [
                    'summary',
                    'by_category',
                    'by_placement',
                ],
            ]);

        // 4. Employer toggles own campaign status
        $toggleResponse = $this->actingAs($employerUser)->patchJson("/api/v1/admin/advertisements/{$createdId}/status", [
            'status' => 'paused',
        ]);
        $toggleResponse->assertStatus(200);

        // 5. Employer updates (edits) own campaign
        $updateResponse = $this->actingAs($employerUser)->putJson("/api/v1/admin/advertisements/{$createdId}", [
            'title' => 'Employer Sponsored Tech Drive (Updated)',
            'cta_text' => 'Apply Immediately',
        ]);
        $updateResponse->assertStatus(200);
        $this->assertEquals('Employer Sponsored Tech Drive (Updated)', Advertisement::find($createdId)->title);
        $this->assertEquals('Apply Immediately', Advertisement::find($createdId)->cta_text);

        // 6. Employer deletes own campaign
        $deleteResponse = $this->actingAs($employerUser)->deleteJson("/api/v1/admin/advertisements/{$createdId}");
        $deleteResponse->assertStatus(200);
        $this->assertNull(Advertisement::find($createdId));
    }
}
