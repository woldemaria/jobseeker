<?php

namespace Tests\Feature;

use App\Models\Employer;
use App\Models\EmployerMember;
use App\Models\Job;
use App\Models\Report;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FraudulentJobAdvertisementTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private User $employerUser;
    private Employer $employer;
    private User $jobSeeker;

    protected function setUp(): void
    {
        parent::setUp();

        $adminRole = Role::firstOrCreate(['name' => 'administrator'], ['description' => 'System Admin']);
        $employerRole = Role::firstOrCreate(['name' => 'employer'], ['description' => 'Employer']);
        $seekerRole = Role::firstOrCreate(['name' => 'job_seeker'], ['description' => 'Job Seeker']);

        // Admin User
        $this->admin = User::factory()->create(['status' => 'active', 'email' => 'admin@safejobs.et']);
        $this->admin->roles()->sync([$adminRole->id]);

        // Verified Employer
        $this->employerUser = User::factory()->create(['status' => 'active', 'email' => 'hr@safecorp.com']);
        $this->employerUser->roles()->sync([$employerRole->id]);

        $this->employer = Employer::create([
            'organization_name' => 'Safe Corporate Ltd',
            'email' => 'contact@safecorp.com',
            'phone' => '+251911000000',
            'verification_status' => 'approved',
        ]);

        EmployerMember::create([
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'member_role' => 'owner',
        ]);

        // Job Seeker
        $this->jobSeeker = User::factory()->create(['status' => 'active', 'email' => 'seeker@example.com']);
        $this->jobSeeker->roles()->sync([$seekerRole->id]);
    }

    public function test_legitimate_job_creation_gets_low_fraud_score(): void
    {
        $response = $this->actingAs($this->employerUser, 'sanctum')->postJson('/api/v1/jobs', [
            'title' => 'Senior Laravel Backend Engineer',
            'description' => 'We are seeking an experienced software engineer to build scalable RESTful microservices using Laravel, MySQL, and Docker. Responsibilities include system architecture and automated unit testing.',
            'requirements' => 'Bachelor degree in Computer Science, 4+ years of professional PHP/Laravel experience.',
            'location' => 'Bole, Addis Ababa',
            'employment_type' => 'Full-time',
            'experience_required' => 4,
            'salary_min' => 40000,
            'salary_max' => 60000,
            'currency' => 'ETB',
            'deadline' => now()->addDays(20)->toDateString(),
            'status' => 'published',
        ]);

        $response->assertStatus(201);
        $data = $response->json('data');

        $this->assertEquals('low', $data['fraud_risk_level']);
        $this->assertLessThan(30, $data['fraud_score']);
        $this->assertFalse((bool)$data['is_flagged']);
        $this->assertEquals('clean', $data['moderation_status']);
    }

    public function test_scam_job_with_upfront_fee_is_flagged_and_quarantined(): void
    {
        $response = $this->actingAs($this->employerUser, 'sanctum')->postJson('/api/v1/jobs', [
            'title' => 'Urgent Office Assistant - Guaranteed Visa',
            'description' => 'Guaranteed overseas job! Zero experience needed. Earn 150000 ETB daily. Send registration fee of 5000 ETB before interview via western union or contact only via telegram @scam_agent.',
            'requirements' => 'Must send money upfront to process security clearance.',
            'location' => 'Addis Ababa',
            'employment_type' => 'Full-time',
            'salary_min' => 100000,
            'salary_max' => 300000,
            'experience_required' => 0,
            'currency' => 'ETB',
            'deadline' => now()->addDays(15)->toDateString(),
            'status' => 'published',
        ]);

        $response->assertStatus(201);
        $data = $response->json('data');

        $this->assertGreaterThanOrEqual(60, $data['fraud_score']);
        $this->assertTrue((bool)$data['is_flagged']);
        $this->assertEquals('under_review', $data['moderation_status']);
        $this->assertEquals('draft', $data['status']); // Auto-quarantined to draft
        $this->assertNotEmpty($data['fraud_indicators']);
    }

    public function test_pre_submission_check_endpoint(): void
    {
        $response = $this->actingAs($this->employerUser, 'sanctum')->postJson('/api/v1/jobs/check-fraud', [
            'title' => 'Data Entry Remote',
            'description' => 'Pay 2000 ETB processing fee prior to receiving interview credentials. Message only via telegram.',
            'salary_max' => 200000,
            'experience_required' => 0,
        ]);

        $response->assertStatus(200);
        $data = $response->json('data');

        $this->assertGreaterThanOrEqual(45, $data['fraud_score']);
        $this->assertContains('Demands upfront payment, registration, or processing fees', $data['fraud_indicators']);
    }

    public function test_public_fraud_assessment_transparency(): void
    {
        $job = Job::create([
            'employer_id' => $this->employer->id,
            'title' => 'Accountant Vacancy',
            'description' => 'Standard corporate accountant role with verified audit duties.',
            'location' => 'Addis Ababa',
            'employment_type' => 'Full-time',
            'deadline' => now()->addDays(10)->toDateString(),
            'status' => 'published',
            'fraud_score' => 5,
            'fraud_risk_level' => 'low',
        ]);

        $response = $this->getJson("/api/v1/jobs/{$job->id}/fraud-assessment");

        $response->assertStatus(200)
            ->assertJsonPath('data.job_id', $job->id)
            ->assertJsonPath('data.is_verified_employer', true)
            ->assertJsonPath('data.fraud_risk_level', 'low');
    }

    public function test_admin_can_list_flagged_fraudulent_jobs(): void
    {
        // Clean job
        Job::create([
            'employer_id' => $this->employer->id,
            'title' => 'Safe Clean Job',
            'description' => 'Safe description without flags.',
            'location' => 'Addis Ababa',
            'employment_type' => 'Full-time',
            'deadline' => now()->addDays(10)->toDateString(),
            'status' => 'published',
            'fraud_score' => 10,
            'fraud_risk_level' => 'low',
            'is_flagged' => false,
        ]);

        // Suspicious job
        $badJob = Job::create([
            'employer_id' => $this->employer->id,
            'title' => 'Suspicious Money Mule Job',
            'description' => 'Cash check for processing fee wire transfer.',
            'location' => 'Addis Ababa',
            'employment_type' => 'Full-time',
            'deadline' => now()->addDays(10)->toDateString(),
            'status' => 'draft',
            'fraud_score' => 85,
            'fraud_risk_level' => 'critical',
            'is_flagged' => true,
            'moderation_status' => 'under_review',
        ]);

        $response = $this->actingAs($this->admin, 'sanctum')->getJson('/api/v1/admin/fraud-jobs');

        $response->assertStatus(200);
        $this->assertCount(1, $response->json('data'));
        $this->assertEquals($badJob->id, $response->json('data.0.id'));
    }

    public function test_admin_can_moderate_fraud_job_and_take_down(): void
    {
        $job = Job::create([
            'employer_id' => $this->employer->id,
            'title' => 'Scam Vacancy',
            'description' => 'Pay training deposit before interview.',
            'location' => 'Addis Ababa',
            'employment_type' => 'Full-time',
            'deadline' => now()->addDays(10)->toDateString(),
            'status' => 'published',
            'fraud_score' => 75,
            'fraud_risk_level' => 'high',
            'is_flagged' => true,
            'moderation_status' => 'flagged',
        ]);

        // Create a report by job seeker
        $report = Report::create([
            'reporter_id' => $this->jobSeeker->id,
            'job_id' => $job->id,
            'reason' => 'Fraudulent / Scam Listing',
            'description' => 'They asked for money transfer.',
            'status' => 'pending',
        ]);

        $response = $this->actingAs($this->admin, 'sanctum')->postJson("/api/v1/admin/fraud-jobs/{$job->id}/moderate", [
            'action' => 'mark_fraudulent',
            'notes' => 'Confirmed upfront fee extortion scam.',
        ]);

        $response->assertStatus(200);

        $freshJob = $job->fresh();
        $this->assertEquals('fraudulent', $freshJob->moderation_status);
        $this->assertEquals('archived', $freshJob->status);
        $this->assertTrue((bool)$freshJob->is_flagged);

        // Associated report should be resolved
        $freshReport = $report->fresh();
        $this->assertEquals('resolved', $freshReport->status);
        $this->assertEquals('marked_fraudulent', $freshReport->action_taken);
    }

    public function test_admin_can_mark_safe_and_restore_quarantined_job(): void
    {
        $job = Job::create([
            'employer_id' => $this->employer->id,
            'title' => 'Misunderstood Opportunity',
            'description' => 'Legitimate listing mistakenly flagged.',
            'location' => 'Addis Ababa',
            'employment_type' => 'Full-time',
            'deadline' => now()->addDays(10)->toDateString(),
            'status' => 'draft',
            'fraud_score' => 65,
            'fraud_risk_level' => 'high',
            'is_flagged' => true,
            'moderation_status' => 'under_review',
        ]);

        $response = $this->actingAs($this->admin, 'sanctum')->postJson("/api/v1/admin/fraud-jobs/{$job->id}/moderate", [
            'action' => 'mark_safe',
            'notes' => 'Employer license validated and approved.',
        ]);

        $response->assertStatus(200);

        $freshJob = $job->fresh();
        $this->assertEquals('cleared', $freshJob->moderation_status);
        $this->assertEquals('published', $freshJob->status);
        $this->assertFalse((bool)$freshJob->is_flagged);
    }

    public function test_admin_can_run_platform_fraud_scan(): void
    {
        Job::create([
            'employer_id' => $this->employer->id,
            'title' => 'Deposit fee before starting',
            'description' => 'Pay registration fee of 1000 ETB. Contact only via telegram @bot',
            'location' => 'Addis Ababa',
            'employment_type' => 'Full-time',
            'deadline' => now()->addDays(10)->toDateString(),
            'status' => 'published',
        ]);

        $response = $this->actingAs($this->admin, 'sanctum')->postJson('/api/v1/admin/fraud-scan');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data' => ['total_scanned', 'flagged_count', 'quarantined_count', 'scanned_at'],
            ]);

        $this->assertGreaterThanOrEqual(1, $response->json('data.total_scanned'));
        $this->assertGreaterThanOrEqual(1, $response->json('data.flagged_count'));
    }

    public function test_user_scam_report_triggers_job_reassessment(): void
    {
        $job = Job::create([
            'employer_id' => $this->employer->id,
            'title' => 'Marketing Associate',
            'description' => 'Marketing executive position in Addis Ababa.',
            'location' => 'Addis Ababa',
            'employment_type' => 'Full-time',
            'deadline' => now()->addDays(10)->toDateString(),
            'status' => 'published',
            'fraud_score' => 0,
            'fraud_risk_level' => 'low',
        ]);

        $response = $this->actingAs($this->jobSeeker, 'sanctum')->postJson('/api/v1/reports', [
            'job_id' => $job->id,
            'reason' => 'Fraudulent / Scam Listing',
            'description' => 'The contact person asked for money via Telegram.',
        ]);

        $response->assertStatus(201);

        $freshJob = $job->fresh();
        $this->assertGreaterThan(0, $freshJob->fraud_score);
    }
}
