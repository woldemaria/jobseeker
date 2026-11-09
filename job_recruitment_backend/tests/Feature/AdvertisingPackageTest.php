<?php

namespace Tests\Feature;

use App\Models\Advertisement;
use App\Models\AdvertisingPackage;
use App\Models\AuditLog;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdvertisingPackageTest extends TestCase
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
            ['email' => 'admin_test@jobrecruitment.et'],
            [
                'name' => 'Admin Tester',
                'password' => bcrypt('Password@123'),
                'status' => 'active',
            ]
        );
        $role = Role::firstOrCreate(['name' => 'administrator']);
        $admin->roles()->syncWithoutDetaching([$role->id]);
        return $admin;
    }

    protected function getJobSeekerUser(): User
    {
        $seeker = User::firstOrCreate(
            ['email' => 'seeker_test@example.com'],
            [
                'name' => 'Seeker Tester',
                'password' => bcrypt('Password@123'),
                'status' => 'active',
            ]
        );
        $role = Role::firstOrCreate(['name' => 'job_seeker']);
        $seeker->roles()->syncWithoutDetaching([$role->id]);
        return $seeker;
    }

    public function test_public_can_fetch_active_advertising_packages(): void
    {
        $response = $this->getJson('/api/v1/ad-packages');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ])
            ->assertJsonStructure([
                'data' => [
                    '*' => [
                        'id',
                        'name',
                        'slug',
                        'duration_days',
                        'price_etb',
                        'price_formatted',
                        'allowed_placements',
                        'allowed_categories',
                        'benefits',
                        'is_active',
                    ],
                ],
            ]);

        $data = $response->json('data');
        $this->assertNotEmpty($data);
        foreach ($data as $item) {
            $this->assertTrue($item['is_active']);
        }
    }

    public function test_inactive_package_is_hidden_from_public_list(): void
    {
        $pkg = AdvertisingPackage::first();
        $this->assertNotNull($pkg);
        $pkg->update(['is_active' => false]);

        $response = $this->getJson('/api/v1/ad-packages');
        $response->assertStatus(200);

        $ids = collect($response->json('data'))->pluck('id')->all();
        $this->assertNotContains($pkg->id, $ids);
    }

    public function test_public_can_view_single_package(): void
    {
        $pkg = AdvertisingPackage::first();
        $this->assertNotNull($pkg);

        $response = $this->getJson("/api/v1/ad-packages/{$pkg->id}");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'id' => $pkg->id,
                    'name' => $pkg->name,
                ],
            ]);
    }

    public function test_non_admin_cannot_access_admin_package_endpoints(): void
    {
        $seeker = $this->getJobSeekerUser();

        $response = $this->actingAs($seeker, 'sanctum')->getJson('/api/v1/admin/ad-packages');
        $response->assertStatus(403);

        $createResponse = $this->actingAs($seeker, 'sanctum')->postJson('/api/v1/admin/ad-packages', [
            'name' => 'Hacker Package',
            'duration_days' => 7,
            'price_etb' => 10,
            'allowed_placements' => ['hero'],
            'allowed_categories' => ['featured_jobs'],
        ]);
        $createResponse->assertStatus(403);
    }

    public function test_admin_can_list_all_packages_including_inactive(): void
    {
        $admin = $this->getAdminUser();

        // Deactivate one package
        $pkg = AdvertisingPackage::first();
        $pkg->update(['is_active' => false]);

        $response = $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/ad-packages');

        $response->assertStatus(200)
            ->assertJson(['success' => true]);

        $ids = collect($response->json('data'))->pluck('id')->all();
        $this->assertContains($pkg->id, $ids);
    }

    public function test_admin_can_create_new_advertising_package(): void
    {
        $admin = $this->getAdminUser();

        $payload = [
            'name' => 'Flash 3-Day Blast',
            'description' => 'Quick hiring blitz for urgent weekend recruitment.',
            'duration_days' => 3,
            'price_etb' => 950.00,
            'allowed_placements' => ['hero', 'job_list'],
            'allowed_categories' => ['featured_jobs', 'sponsored_vacancies'],
            'benefits' => [
                '72-Hour continuous hero billboard placement',
                'Push notification boost to matching candidates',
            ],
            'badge_label' => 'Flash',
            'is_active' => true,
            'priority_level' => 5,
        ];

        $response = $this->actingAs($admin, 'sanctum')->postJson('/api/v1/admin/ad-packages', $payload);

        $response->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data' => [
                    'name' => 'Flash 3-Day Blast',
                    'slug' => 'flash-3-day-blast',
                    'duration_days' => 3,
                    'price_etb' => 950.00,
                    'badge_label' => 'Flash',
                    'is_active' => true,
                ],
            ]);

        $this->assertDatabaseHas('advertising_packages', [
            'name' => 'Flash 3-Day Blast',
            'slug' => 'flash-3-day-blast',
        ]);

        $this->assertDatabaseHas('audit_logs', [
            'user_id' => $admin->id,
            'action' => 'advertising_package_created',
        ]);
    }

    public function test_package_creation_validation_fails_for_invalid_data(): void
    {
        $admin = $this->getAdminUser();

        $response = $this->actingAs($admin, 'sanctum')->postJson('/api/v1/admin/ad-packages', [
            'name' => '',
            'duration_days' => 0,
            'price_etb' => -50,
            'allowed_placements' => [],
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['name', 'duration_days', 'price_etb', 'allowed_placements', 'allowed_categories']);
    }

    public function test_admin_can_update_package_pricing_and_duration(): void
    {
        $admin = $this->getAdminUser();
        $pkg = AdvertisingPackage::where('slug', 'basic-campaign')->first();
        $this->assertNotNull($pkg);

        $response = $this->actingAs($admin, 'sanctum')->putJson("/api/v1/admin/ad-packages/{$pkg->id}", [
            'price_etb' => 1850.50,
            'duration_days' => 8,
            'description' => 'Updated basic campaign description.',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'id' => $pkg->id,
                    'price_etb' => 1850.50,
                    'duration_days' => 8,
                ],
            ]);

        $this->assertDatabaseHas('advertising_packages', [
            'id' => $pkg->id,
            'price_etb' => 1850.50,
            'duration_days' => 8,
        ]);
    }

    public function test_admin_can_toggle_package_status(): void
    {
        $admin = $this->getAdminUser();
        $pkg = AdvertisingPackage::first();
        $initialStatus = $pkg->is_active;

        $response = $this->actingAs($admin, 'sanctum')->patchJson("/api/v1/admin/ad-packages/{$pkg->id}/toggle-status");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'id' => $pkg->id,
                    'is_active' => !$initialStatus,
                ],
            ]);

        $this->assertEquals(!$initialStatus, $pkg->fresh()->is_active);
    }

    public function test_admin_can_delete_unused_package(): void
    {
        $admin = $this->getAdminUser();

        $pkg = AdvertisingPackage::create([
            'name' => 'Obsolete Package',
            'slug' => 'obsolete-package',
            'duration_days' => 5,
            'price_etb' => 500,
            'allowed_placements' => ['job_list'],
            'allowed_categories' => ['featured_jobs'],
        ]);

        $response = $this->actingAs($admin, 'sanctum')->deleteJson("/api/v1/admin/ad-packages/{$pkg->id}");

        $response->assertStatus(200)
            ->assertJson(['success' => true]);

        $this->assertDatabaseMissing('advertising_packages', ['id' => $pkg->id]);
    }

    public function test_admin_cannot_delete_package_in_use(): void
    {
        $admin = $this->getAdminUser();
        $pkg = AdvertisingPackage::first();
        $ad = Advertisement::first();

        // Associate advertisement with package
        $ad->update(['package_id' => $pkg->id]);

        $response = $this->actingAs($admin, 'sanctum')->deleteJson("/api/v1/admin/ad-packages/{$pkg->id}");

        $response->assertStatus(400)
            ->assertJson(['success' => false]);

        $this->assertDatabaseHas('advertising_packages', ['id' => $pkg->id]);
    }
}
