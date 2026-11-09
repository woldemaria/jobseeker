<?php

namespace Tests\Feature;

use App\Models\Advertisement;
use App\Models\AdvertisingPackage;
use App\Models\AuditLog;
use App\Models\Employer;
use App\Models\Notification;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CampaignManagementTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    protected function getAdminUser(): User
    {
        $admin = User::firstOrCreate(
            ['email' => 'admin_camp@jobrecruitment.et'],
            [
                'name' => 'Admin Reviewer',
                'password' => bcrypt('Password@123'),
                'status' => 'active',
            ]
        );
        $role = Role::firstOrCreate(['name' => 'administrator']);
        $admin->roles()->syncWithoutDetaching([$role->id]);
        return $admin;
    }

    protected function getEmployerUser(string $email = 'employer_camp@example.com'): User
    {
        $user = User::firstOrCreate(
            ['email' => $email],
            [
                'name' => 'Recruitment Manager',
                'password' => bcrypt('Password@123'),
                'status' => 'active',
            ]
        );
        $role = Role::firstOrCreate(['name' => 'employer']);
        $user->roles()->syncWithoutDetaching([$role->id]);

        $employer = Employer::firstOrCreate(
            ['email' => $email],
            [
                'organization_name' => 'Tech Corp ' . substr(md5($email), 0, 6),
                'phone' => '+251911000222',
                'verification_status' => 'approved',
            ]
        );
        $user->employers()->syncWithoutDetaching([$employer->id => ['member_role' => 'admin']]);

        return $user;
    }

    public function test_can_fetch_ethiopian_targeting_locations(): void
    {
        $response = $this->getJson('/api/v1/campaigns/locations');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'success',
                'data' => [
                    'hierarchy',
                    'all_locations',
                ],
            ]);

        $locations = $response->json('data.all_locations');
        $this->assertContains('All Ethiopia', $locations);
        $this->assertContains('Bole', $locations);
        $this->assertContains('Hawassa', $locations);
    }

    public function test_employer_can_create_campaign_draft_or_submit_for_approval(): void
    {
        $employerUser = $this->getEmployerUser();
        $package = AdvertisingPackage::where('slug', 'basic-campaign')->first();
        $this->assertNotNull($package);

        $payload = [
            'package_id' => $package->id,
            'title' => 'Urgent Senior Flutter Engineer Hiring',
            'subtitle' => 'Join our fintech core team in Bole.',
            'category' => 'featured_jobs',
            'placement' => 'job_list',
            'cta_type' => 'apply_now',
            'cta_text' => 'Apply Online',
            'cta_target' => '/jobs/1',
            'start_date' => now()->toDateString(),
            'end_date' => now()->addDays(5)->toDateString(),
            'target_locations' => ['Bole', 'Kirkos'],
            'image_url' => 'https://example.com/banner.jpg',
            'is_draft' => true,
        ];

        $response = $this->actingAs($employerUser, 'sanctum')->postJson('/api/v1/advertiser/campaigns', $payload);

        $response->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data' => [
                    'title' => 'Urgent Senior Flutter Engineer Hiring',
                    'status' => 'draft',
                    'approval_status' => 'draft',
                    'payment_status' => 'unpaid',
                ],
            ]);

        $this->assertDatabaseHas('advertisements', [
            'title' => 'Urgent Senior Flutter Engineer Hiring',
            'created_by' => $employerUser->id,
            'approval_status' => 'draft',
            'payment_status' => 'unpaid',
        ]);
    }

    public function test_campaign_creation_fails_if_placement_not_allowed_by_package(): void
    {
        $employerUser = $this->getEmployerUser();
        // Basic campaign only allows job_list and sidebar, NOT hero
        $package = AdvertisingPackage::where('slug', 'basic-campaign')->first();

        $payload = [
            'package_id' => $package->id,
            'title' => 'Illegal Placement Campaign',
            'category' => 'featured_jobs',
            'placement' => 'hero', // Not allowed by basic-campaign!
            'cta_type' => 'apply_now',
            'cta_text' => 'Apply',
            'cta_target' => '/jobs/1',
            'start_date' => now()->toDateString(),
            'end_date' => now()->addDays(5)->toDateString(),
            'image_url' => 'https://example.com/banner.jpg',
        ];

        $response = $this->actingAs($employerUser, 'sanctum')->postJson('/api/v1/advertiser/campaigns', $payload);

        $response->assertStatus(422)
            ->assertJson(['success' => false]);
    }

    public function test_campaign_creation_fails_if_category_not_allowed_by_package(): void
    {
        $employerUser = $this->getEmployerUser();
        // Basic campaign does not allow announcements
        $package = AdvertisingPackage::where('slug', 'basic-campaign')->first();

        $payload = [
            'package_id' => $package->id,
            'title' => 'Disallowed Category Campaign',
            'category' => 'announcements', // Not allowed in basic-campaign
            'placement' => 'job_list',
            'cta_type' => 'explore_jobs',
            'cta_text' => 'Explore',
            'cta_target' => '/jobs',
            'start_date' => now()->toDateString(),
            'end_date' => now()->addDays(5)->toDateString(),
            'image_url' => 'https://example.com/banner.jpg',
        ];

        $response = $this->actingAs($employerUser, 'sanctum')->postJson('/api/v1/advertiser/campaigns', $payload);

        $response->assertStatus(422)
            ->assertJson(['success' => false]);
    }

    public function test_campaign_duration_cannot_exceed_package_limit(): void
    {
        $employerUser = $this->getEmployerUser();
        // Basic campaign limit is 7 days
        $package = AdvertisingPackage::where('slug', 'basic-campaign')->first();

        $payload = [
            'package_id' => $package->id,
            'title' => 'Too Long Campaign',
            'category' => 'featured_jobs',
            'placement' => 'job_list',
            'cta_type' => 'apply_now',
            'cta_text' => 'Apply',
            'cta_target' => '/jobs',
            'start_date' => now()->toDateString(),
            'end_date' => now()->addDays(14)->toDateString(), // 15 days duration > 7 days limit!
            'image_url' => 'https://example.com/banner.jpg',
        ];

        $response = $this->actingAs($employerUser, 'sanctum')->postJson('/api/v1/advertiser/campaigns', $payload);

        $response->assertStatus(422)
            ->assertJson(['success' => false]);
    }

    public function test_campaign_geographic_targeting_validates_locations(): void
    {
        $employerUser = $this->getEmployerUser();
        $package = AdvertisingPackage::where('slug', 'standard-package')->first();

        $payload = [
            'package_id' => $package->id,
            'title' => 'Invalid Geography Campaign',
            'category' => 'featured_jobs',
            'placement' => 'job_list',
            'cta_type' => 'apply_now',
            'cta_text' => 'Apply',
            'cta_target' => '/jobs',
            'start_date' => now()->toDateString(),
            'end_date' => now()->addDays(5)->toDateString(),
            'target_locations' => ['NonExistentPlanetLocation123'], // Invalid!
            'image_url' => 'https://example.com/banner.jpg',
        ];

        $response = $this->actingAs($employerUser, 'sanctum')->postJson('/api/v1/advertiser/campaigns', $payload);

        $response->assertStatus(422)
            ->assertJson(['success' => false]);
    }

    public function test_idor_protection_employer_cannot_access_or_edit_another_employers_campaign(): void
    {
        $employerA = $this->getEmployerUser('empA@example.com');
        $employerB = $this->getEmployerUser('empB@example.com');
        $package = AdvertisingPackage::first();

        $campaignA = Advertisement::create([
            'employer_id' => $employerA->employers()->first()->id,
            'package_id' => $package->id,
            'created_by' => $employerA->id,
            'title' => 'Employer A Secret Campaign',
            'category' => 'featured_jobs',
            'placement' => 'job_list',
            'cta_type' => 'apply_now',
            'cta_text' => 'Apply',
            'cta_target' => '/jobs',
            'image_url' => 'https://example.com/banner.jpg',
            'status' => 'draft',
            'approval_status' => 'draft',
            'payment_status' => 'unpaid',
            'start_date' => now(),
            'end_date' => now()->addDays(5),
        ]);

        // Employer B tries to view Employer A's campaign
        $viewResponse = $this->actingAs($employerB, 'sanctum')->getJson("/api/v1/advertiser/campaigns/{$campaignA->id}");
        $viewResponse->assertStatus(403);

        // Employer B tries to update Employer A's campaign
        $updateResponse = $this->actingAs($employerB, 'sanctum')->putJson("/api/v1/advertiser/campaigns/{$campaignA->id}", [
            'title' => 'Hacked Title',
        ]);
        $updateResponse->assertStatus(403);

        // Employer B tries to submit Employer A's campaign
        $submitResponse = $this->actingAs($employerB, 'sanctum')->postJson("/api/v1/advertiser/campaigns/{$campaignA->id}/submit");
        $submitResponse->assertStatus(403);

        // Employer B tries to pause Employer A's campaign
        $pauseResponse = $this->actingAs($employerB, 'sanctum')->postJson("/api/v1/advertiser/campaigns/{$campaignA->id}/pause");
        $pauseResponse->assertStatus(403);
    }

    public function test_employer_can_edit_draft_and_submit_for_approval(): void
    {
        $employer = $this->getEmployerUser();
        $package = AdvertisingPackage::where('slug', 'basic-campaign')->first();

        $campaign = Advertisement::create([
            'employer_id' => $employer->employers()->first()->id,
            'package_id' => $package->id,
            'created_by' => $employer->id,
            'title' => 'Original Draft Title',
            'category' => 'featured_jobs',
            'placement' => 'job_list',
            'cta_type' => 'apply_now',
            'cta_text' => 'Apply',
            'cta_target' => '/jobs',
            'image_url' => 'https://example.com/banner.jpg',
            'status' => 'draft',
            'approval_status' => 'draft',
            'payment_status' => 'unpaid',
            'start_date' => now(),
            'end_date' => now()->addDays(5),
        ]);

        // Edit draft
        $editResponse = $this->actingAs($employer, 'sanctum')->putJson("/api/v1/advertiser/campaigns/{$campaign->id}", [
            'title' => 'Revised Draft Title',
            'is_draft' => true,
        ]);
        $editResponse->assertStatus(200)
            ->assertJson(['data' => ['title' => 'Revised Draft Title']]);

        // Submit for approval
        $submitResponse = $this->actingAs($employer, 'sanctum')->postJson("/api/v1/advertiser/campaigns/{$campaign->id}/submit");
        $submitResponse->assertStatus(200)
            ->assertJson([
                'data' => [
                    'approval_status' => 'pending_approval',
                    'status' => 'pending_approval',
                ],
            ]);

        $this->assertEquals('pending_approval', $campaign->fresh()->approval_status);

        // Trying to edit while pending_approval must be rejected
        $cannotEditResponse = $this->actingAs($employer, 'sanctum')->putJson("/api/v1/advertiser/campaigns/{$campaign->id}", [
            'title' => 'Attempted Edit During Review',
        ]);
        $cannotEditResponse->assertStatus(422);
    }

    public function test_admin_can_approve_campaign_and_employer_is_notified(): void
    {
        $admin = $this->getAdminUser();
        $employer = $this->getEmployerUser();
        $package = AdvertisingPackage::first();

        $campaign = Advertisement::create([
            'employer_id' => $employer->employers()->first()->id,
            'package_id' => $package->id,
            'created_by' => $employer->id,
            'title' => 'Awaiting Approval Campaign',
            'category' => 'featured_jobs',
            'placement' => 'job_list',
            'cta_type' => 'apply_now',
            'cta_text' => 'Apply',
            'cta_target' => '/jobs',
            'image_url' => 'https://example.com/banner.jpg',
            'status' => 'pending_approval',
            'approval_status' => 'pending_approval',
            'payment_status' => 'unpaid',
            'start_date' => now(),
            'end_date' => now()->addDays(5),
        ]);

        $response = $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/campaigns/{$campaign->id}/approve");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'approval_status' => 'approved',
                    'approved_by' => [
                        'id' => $admin->id,
                    ],
                ],
            ]);

        $this->assertEquals('approved', $campaign->fresh()->approval_status);
        $this->assertNotNull($campaign->fresh()->approved_at);

        // Verify employer received in-app notification
        $this->assertDatabaseHas('notifications', [
            'user_id' => $employer->id,
            'notification_type' => 'campaign_approved',
        ]);

        $this->assertDatabaseHas('audit_logs', [
            'user_id' => $admin->id,
            'action' => 'campaign_approved_by_admin',
        ]);
    }

    public function test_admin_can_reject_campaign_with_mandatory_reason(): void
    {
        $admin = $this->getAdminUser();
        $employer = $this->getEmployerUser();
        $package = AdvertisingPackage::first();

        $campaign = Advertisement::create([
            'employer_id' => $employer->employers()->first()->id,
            'package_id' => $package->id,
            'created_by' => $employer->id,
            'title' => 'Low Quality Creative Campaign',
            'category' => 'featured_jobs',
            'placement' => 'job_list',
            'cta_type' => 'apply_now',
            'cta_text' => 'Apply',
            'cta_target' => '/jobs',
            'image_url' => 'https://example.com/banner.jpg',
            'status' => 'pending_approval',
            'approval_status' => 'pending_approval',
            'payment_status' => 'unpaid',
            'start_date' => now(),
            'end_date' => now()->addDays(5),
        ]);

        // Rejection without reason must fail validation
        $failResponse = $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/campaigns/{$campaign->id}/reject", []);
        $failResponse->assertStatus(422)
            ->assertJsonValidationErrors(['rejection_reason']);

        // Rejection with reason succeeds
        $rejectResponse = $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/campaigns/{$campaign->id}/reject", [
            'rejection_reason' => 'Advertisement image banner is blurry and fails contrast requirements. Please re-upload high resolution banner.',
        ]);

        $rejectResponse->assertStatus(200)
            ->assertJson([
                'data' => [
                    'approval_status' => 'rejected',
                    'status' => 'rejected',
                ],
            ]);

        $this->assertEquals('rejected', $campaign->fresh()->approval_status);
        $this->assertNotNull($campaign->fresh()->rejection_reason);

        // Verify employer received notification with reason
        $this->assertDatabaseHas('notifications', [
            'user_id' => $employer->id,
            'notification_type' => 'campaign_rejected',
        ]);

        // Employer can now edit and fix rejected campaign
        $fixResponse = $this->actingAs($employer, 'sanctum')->putJson("/api/v1/advertiser/campaigns/{$campaign->id}", [
            'title' => 'High Quality Creative Campaign Fixed',
            'image_url' => 'https://example.com/hd_banner.jpg',
            'is_draft' => true,
        ]);
        $fixResponse->assertStatus(200);
    }

    public function test_unpaid_campaign_cannot_become_active_or_serve_to_public(): void
    {
        $employer = $this->getEmployerUser();
        $package = AdvertisingPackage::where('price_etb', '>', 0)->first();

        // Approved by admin, but payment_status = unpaid
        $unpaidCampaign = Advertisement::create([
            'employer_id' => $employer->employers()->first()->id,
            'package_id' => $package->id,
            'created_by' => $employer->id,
            'title' => 'Unpaid Approved Campaign',
            'category' => 'featured_jobs',
            'placement' => 'hero',
            'cta_type' => 'apply_now',
            'cta_text' => 'Apply',
            'cta_target' => '/jobs',
            'image_url' => 'https://example.com/banner.jpg',
            'status' => 'paused',
            'approval_status' => 'approved',
            'payment_status' => 'unpaid',
            'price_paid' => $package->price_etb,
            'start_date' => now()->subDay(),
            'end_date' => now()->addDays(5),
        ]);

        // Employer attempts to resume/activate unpaid campaign
        $resumeResponse = $this->actingAs($employer, 'sanctum')->postJson("/api/v1/advertiser/campaigns/{$unpaidCampaign->id}/resume");
        $resumeResponse->assertStatus(422)
            ->assertJson(['success' => false]);

        // Ensure unpaid campaign is excluded from public active ads scope
        $publicAds = Advertisement::active()->pluck('id')->all();
        $this->assertNotContains($unpaidCampaign->id, $publicAds);
    }
}
