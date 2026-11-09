<?php

namespace Tests\Feature;

use App\Models\Advertisement;
use App\Models\AdvertisingPackage;
use App\Models\Application;
use App\Models\Document;
use App\Models\Employer;
use App\Models\Job;
use App\Models\JobSeekerProfile;
use App\Models\Notification;
use App\Models\PaymentTransaction;
use App\Models\Role;
use App\Models\Skill;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ComprehensiveSystemE2ETest extends TestCase
{
    use RefreshDatabase;

    protected User $adminUser;
    protected User $employerUser;
    protected User $otherEmployerUser;
    protected User $jobSeekerUser;
    protected Employer $employer;
    protected Employer $otherEmployer;
    protected AdvertisingPackage $package;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();

        $this->adminUser = User::where('email', 'admin@jobrecruitment.et')->first();
        $this->employerUser = User::where('email', 'recruitment@example.com')->first();
        $this->jobSeekerUser = User::where('email', 'jobseeker@example.com')->first();
        $this->employer = Employer::where('organization_name', 'Example Technology Company')->first();

        // Create a second employer for IDOR / cross-organization boundary testing
        $employerRole = Role::firstOrCreate(['name' => 'employer'], ['description' => 'Employer']);
        $this->otherEmployerUser = User::create([
            'name' => 'Other Recruiter',
            'email' => 'other_recruiter@corp.et',
            'phone' => '+251922334455',
            'password' => Hash::make('Employer@123456'),
            'status' => 'active',
        ]);
        $this->otherEmployerUser->roles()->attach($employerRole->id);

        $this->otherEmployer = Employer::create([
            'organization_name' => 'Secondary Enterprise Ltd',
            'email' => 'contact@secondary.et',
            'phone' => '+251922334455',
            'verification_status' => 'verified',
        ]);
        $this->otherEmployer->users()->attach($this->otherEmployerUser->id, ['member_role' => 'owner']);

        $this->package = AdvertisingPackage::create([
            'name' => 'Standard Package (15 Days)',
            'slug' => 'standard-15-e2e',
            'description' => 'High visibility standard campaign',
            'duration_days' => 15,
            'price_etb' => 3500.00,
            'allowed_placements' => ['hero', 'dashboard', 'job_list'],
            'allowed_categories' => ['featured_jobs', 'recruitment_campaigns'],
            'is_active' => true,
            'priority_level' => 2,
        ]);

        config([
            'services.chapa.secret_key' => 'CHASECK_TEST-validtestkey12345',
            'services.chapa.webhook_secret' => 'webhook_secret_key_777',
            'services.chapa.base_url' => 'https://api.chapa.global/v2',
        ]);
    }

    /**
     * E2E-01: Job Seeker End-to-End Recruitment Journey
     * Register -> Login -> Complete Profile -> Search -> View Details -> Apply -> Track Status
     */
    public function test_e2e_01_job_seeker_recruitment_journey(): void
    {
        // 1. Registration
        $regResp = $this->postJson('/api/v1/auth/register', [
            'name' => 'Abebe Kebede',
            'email' => 'abebe.qa@ethiopia.et',
            'phone' => '+251911998877',
            'password' => 'SecurePass@123',
            'password_confirmation' => 'SecurePass@123',
            'role' => 'job_seeker',
        ]);
        $regResp->assertStatus(201)->assertJson(['success' => true]);
        $token = $regResp->json('data.token');
        $this->assertNotEmpty($token);

        // 2. Login
        $loginResp = $this->postJson('/api/v1/auth/login', [
            'email' => 'abebe.qa@ethiopia.et',
            'password' => 'SecurePass@123',
        ]);
        $loginResp->assertStatus(200)->assertJson(['success' => true]);
        $candidate = User::where('email', 'abebe.qa@ethiopia.et')->first();

        // 3. Complete Profile (Headline, Location, Experience)
        $profileResp = $this->actingAs($candidate, 'sanctum')->putJson('/api/v1/profile', [
            'headline' => 'Senior Full Stack QA Automation Engineer',
            'location' => 'Bole, Addis Ababa',
            'experience_years' => 5.5,
            'education_level' => 'Bachelor Degree',
            'field_of_study' => 'Software Engineering',
        ]);
        $profileResp->assertStatus(200);

        // 4. Upload CV Document
        Storage::fake('private');
        $cvFile = UploadedFile::fake()->create('Abebe_Kebede_Resume.pdf', 300, 'application/pdf');
        $docResp = $this->actingAs($candidate, 'sanctum')->post('/api/v1/documents', [
            'file' => $cvFile,
            'document_type' => 'cv',
        ]);
        $docResp->assertStatus(201);
        $docId = $docResp->json('data.id');

        // 5. Search Jobs
        $searchResp = $this->actingAs($candidate, 'sanctum')->getJson('/api/v1/jobs?keyword=Engineer');
        $searchResp->assertStatus(200)->assertJson(['success' => true]);

        // Get an active published job
        $job = Job::where('status', 'published')->first();
        $this->assertNotNull($job);

        // 6. View Job Details
        $detailResp = $this->actingAs($candidate, 'sanctum')->getJson("/api/v1/jobs/{$job->id}");
        $detailResp->assertStatus(200)->assertJson(['success' => true]);

        // 7. Apply for Job
        $applyResp = $this->actingAs($candidate, 'sanctum')->postJson("/api/v1/jobs/{$job->id}/applications", [
            'cv_document_id' => $docId,
            'cover_letter' => 'I am eager to contribute my QA automation experience.',
        ]);
        $applyResp->assertStatus(201)->assertJson(['success' => true]);
        $appId = $applyResp->json('data.id');

        // 8. Track Application in My Applications
        $myAppsResp = $this->actingAs($candidate, 'sanctum')->getJson('/api/v1/applications');
        $myAppsResp->assertStatus(200);
        $this->assertTrue(collect($myAppsResp->json('data'))->contains('id', $appId));
    }

    /**
     * E2E-02 & E2E-04: Employer Job Posting, Review, Shortlisting, Interview, and Job Offer
     */
    public function test_e2e_02_and_04_employer_pipeline_to_offer_acceptance(): void
    {
        // 1. Employer creates vacancy
        $jobResp = $this->actingAs($this->employerUser, 'sanctum')->postJson('/api/v1/jobs', [
            'title' => 'Senior Flutter & Laravel Architect',
            'category' => 'Information Technology',
            'description' => 'Architecting enterprise mobile applications in Ethiopia.',
            'responsibilities' => 'Write clean tests, build scalable APIs, lead team.',
            'requirements' => '5+ years Dart and PHP experience.',
            'location' => 'Addis Ababa',
            'employment_type' => 'Full-time',
            'experience_required' => 5.0,
            'salary_min' => 70000,
            'salary_max' => 95000,
            'deadline' => now()->addDays(30)->toDateString(),
            'status' => 'published',
        ]);
        $jobResp->assertStatus(201);
        $jobId = $jobResp->json('data.id');

        // 2. Candidate applies for vacancy
        Storage::fake('private');
        $cvDoc = Document::create([
            'user_id' => $this->jobSeekerUser->id,
            'original_name' => 'Candidate_CV.pdf',
            'storage_path' => 'documents/' . $this->jobSeekerUser->id . '/cv.pdf',
            'mime_type' => 'application/pdf',
            'file_size' => 2048,
            'document_type' => 'cv',
        ]);

        $applyResp = $this->actingAs($this->jobSeekerUser, 'sanctum')->postJson("/api/v1/jobs/{$jobId}/applications", [
            'cv_document_id' => $cvDoc->id,
            'cover_letter' => 'Passionate about mobile systems architecture.',
        ]);
        $applyResp->assertStatus(201);
        $applicationId = $applyResp->json('data.id');

        // 3. Employer reviews candidate and shortlists
        $statusResp = $this->actingAs($this->employerUser, 'sanctum')->patchJson("/api/v1/applications/{$applicationId}/status", [
            'status' => 'shortlisted',
            'notes' => 'Strong engineering portfolio and verified credentials.',
        ]);
        $statusResp->assertStatus(200);
        $this->assertDatabaseHas('applications', ['id' => $applicationId, 'status' => 'shortlisted']);

        // 4. Employer schedules interview
        $interviewResp = $this->actingAs($this->employerUser, 'sanctum')->postJson("/api/v1/applications/{$applicationId}/interview", [
            'interview_at' => now()->addDays(2)->toIso8601String(),
            'interview_type' => 'video',
            'interview_location' => 'https://meet.google.com/test-recruitment',
            'interview_notes' => 'Technical architectural assessment interview.',
        ]);
        $interviewResp->assertStatus(200);
        $this->assertDatabaseHas('applications', ['id' => $applicationId, 'status' => 'interview', 'interview_status' => 'scheduled']);

        // 5. Candidate confirms interview attendance
        $confirmResp = $this->actingAs($this->jobSeekerUser, 'sanctum')->postJson("/api/v1/applications/{$applicationId}/interview/confirm");
        $confirmResp->assertStatus(200);
        $this->assertDatabaseHas('applications', ['id' => $applicationId, 'interview_status' => 'confirmed']);

        // 6. Employer extends formal job offer
        $offerResp = $this->actingAs($this->employerUser, 'sanctum')->postJson("/api/v1/applications/{$applicationId}/offer", [
            'offer_salary' => 85000.00,
            'offer_start_date' => now()->addDays(14)->toDateString(),
            'offer_benefits' => 'Comprehensive healthcare, gym membership, mobile allowance',
            'offer_conditions' => 'Standard probation period',
            'offer_notes' => 'Welcome to our engineering team!',
        ]);
        $offerResp->assertStatus(200);
        $this->assertDatabaseHas('applications', [
            'id' => $applicationId,
            'status' => 'offered',
            'offer_status' => 'offered',
            'offer_salary' => 85000.00,
        ]);

        // 7. Candidate views offer details
        $viewOfferResp = $this->actingAs($this->jobSeekerUser, 'sanctum')->getJson("/api/v1/applications/{$applicationId}/offer");
        $viewOfferResp->assertStatus(200)
                      ->assertJsonPath('data.offer_status', 'offered');
        $this->assertEquals(85000, (float) $viewOfferResp->json('data.offer_salary'));

        // 8. Candidate accepts formal job offer
        $acceptResp = $this->actingAs($this->jobSeekerUser, 'sanctum')->postJson("/api/v1/applications/{$applicationId}/offer/respond", [
            'action' => 'accepted',
            'notes' => 'I am thrilled to accept the position!',
        ]);
        $acceptResp->assertStatus(200);
        $this->assertDatabaseHas('applications', [
            'id' => $applicationId,
            'status' => 'accepted',
            'offer_status' => 'accepted',
        ]);
    }

    /**
     * E2E-03: Administrator Job Moderation, User Control, and Verification Review
     */
    public function test_e2e_03_administrator_moderation_and_governance(): void
    {
        // 1. Admin views overview statistics
        $statsResp = $this->actingAs($this->adminUser, 'sanctum')->getJson('/api/v1/admin/statistics');
        $statsResp->assertStatus(200)->assertJsonStructure(['data' => ['total_users', 'total_jobs']]);

        // 2. Admin moderates fraudulent/quarantined job
        $scamJob = Job::create([
            'employer_id' => $this->employer->id,
            'title' => 'Earn 5000 ETB Daily From Home Deposit Fee Required',
            'category' => 'Information Technology',
            'description' => 'Pay 500 ETB registration fee via telegram to start earning.',
            'location' => 'Addis Ababa',
            'employment_type' => 'Full-time',
            'deadline' => now()->addDays(10)->toDateString(),
            'status' => 'published',
            'moderation_status' => 'under_review',
            'is_flagged' => true,
        ]);

        $modResp = $this->actingAs($this->adminUser, 'sanctum')->postJson("/api/v1/admin/fraud-jobs/{$scamJob->id}/moderate", [
            'action' => 'mark_fraudulent',
            'notes' => 'Confirmed scam deposit advance fee scheme.',
        ]);
        $modResp->assertStatus(200);
        $this->assertDatabaseHas('jobs', ['id' => $scamJob->id, 'moderation_status' => 'fraudulent', 'status' => 'archived']);

        // 3. Admin user status management
        $candidateUser = User::where('email', 'jobseeker@example.com')->first();
        $statusResp = $this->actingAs($this->adminUser, 'sanctum')->patchJson("/api/v1/admin/users/{$candidateUser->id}/status", [
            'status' => 'active',
        ]);
        $statusResp->assertStatus(200);
        $this->assertDatabaseHas('users', ['id' => $candidateUser->id, 'status' => 'active']);
    }

    /**
     * E2E-05: Advertising Package Selection, Campaign Wizard, Admin Approval, and Payment Security
     */
    public function test_e2e_05_advertising_and_payment_security_workflow(): void
    {
        // 1. Employer creates advertising campaign
        $campResp = $this->actingAs($this->employerUser, 'sanctum')->postJson('/api/v1/advertiser/campaigns', [
            'package_id' => $this->package->id,
            'title' => 'Top Engineering Talent Campaign 2026',
            'image_url' => 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2',
            'category' => 'recruitment_campaigns',
            'placement' => 'hero',
            'start_date' => now()->toDateString(),
            'end_date' => now()->addDays(14)->toDateString(),
            'cta_type' => 'apply_now',
            'cta_text' => 'Apply to Open Positions',
            'cta_target' => '/jobs',
            'target_locations' => ['Bole'],
            'description' => 'Promoted vacancy hiring campaign.',
            'is_draft' => true,
        ]);
        $campResp->assertStatus(201);
        $this->assertEquals('draft', $campResp->json('data.status'));
        $campaignId = $campResp->json('data.id');

        // 2. Employer submits campaign for administrative moderation
        $submitResp = $this->actingAs($this->employerUser, 'sanctum')->postJson("/api/v1/advertiser/campaigns/{$campaignId}/submit");
        $submitResp->assertStatus(200);
        $this->assertDatabaseHas('advertisements', ['id' => $campaignId, 'approval_status' => 'pending_approval']);

        // 3. Admin approves campaign
        $approveResp = $this->actingAs($this->adminUser, 'sanctum')->postJson("/api/v1/admin/campaigns/{$campaignId}/approve");
        $approveResp->assertStatus(200);
        $this->assertDatabaseHas('advertisements', ['id' => $campaignId, 'approval_status' => 'approved']);

        // 4. Test IDOR protection: other employer CANNOT initiate payment for this campaign
        $idorResp = $this->actingAs($this->otherEmployerUser, 'sanctum')->postJson('/api/v1/advertiser/payments/initiate', [
            'advertisement_id' => $campaignId,
            'payment_method' => 'chapa',
        ]);
        $idorResp->assertStatus(403);

        // 5. Unconfigured payment fails closed cleanly (telebirr is unconfigured in test environment)
        $failClosedResp = $this->actingAs($this->employerUser, 'sanctum')->postJson('/api/v1/advertiser/payments/initiate', [
            'advertisement_id' => $campaignId,
            'payment_method' => 'telebirr',
        ]);
        $failClosedResp->assertStatus(400)->assertJson(['success' => false]);

        // 6. Configured Chapa gateway creates payment transaction
        \Illuminate\Support\Facades\Http::fake([
            'https://api.chapa.global/*' => \Illuminate\Support\Facades\Http::response([
                'status' => 'success',
                'message' => 'Hosted checkout session initialized.',
                'data' => [
                    'checkout_url' => 'https://checkout.chapa.co/checkout/payment/mock-session',
                ],
            ], 200),
        ]);

        $initResp = $this->actingAs($this->employerUser, 'sanctum')->postJson('/api/v1/advertiser/payments/initiate', [
            'advertisement_id' => $campaignId,
            'payment_method' => 'chapa',
            'customer_name' => 'Tech Recruiter',
            'customer_email' => 'recruitment@example.com',
            'customer_phone' => '+251911223344',
        ]);
        $initResp->assertStatus(201);
        $txRef = $initResp->json('data.transaction_reference');
        $this->assertNotEmpty($txRef);

        // 7. Signed webhook with underpayment is rejected (SEC-03)
        $underpaymentPayload = json_encode([
            'event_id' => 'evt_underpayment_001',
            'tx_ref' => $txRef,
            'status' => 'success',
            'amount' => 100.00, // Expected 3500.00
            'currency' => 'ETB',
        ]);
        $sigUnderpayment = hash_hmac('sha256', $underpaymentPayload, 'webhook_secret_key_777');

        $underResp = $this->call(
            'POST',
            '/api/v1/payments/chapa/webhook',
            [],
            [],
            [],
            ['HTTP_X-CHAPA-SIGNATURE' => $sigUnderpayment, 'CONTENT_TYPE' => 'application/json'],
            $underpaymentPayload
        );
        $underResp->assertStatus(400);

        // 8. Signed webhook with matching amount confirms transaction and activates campaign (SEC-03 & SEC-04)
        $matchingPayload = json_encode([
            'event_id' => 'evt_valid_payment_002',
            'tx_ref' => $txRef,
            'status' => 'success',
            'amount' => 3500.00,
            'currency' => 'ETB',
            'reference' => 'chapa_settlement_9988',
        ]);
        $sigMatching = hash_hmac('sha256', $matchingPayload, 'webhook_secret_key_777');

        $webhookResp = $this->call(
            'POST',
            '/api/v1/payments/chapa/webhook',
            [],
            [],
            [],
            ['HTTP_X-CHAPA-SIGNATURE' => $sigMatching, 'CONTENT_TYPE' => 'application/json'],
            $matchingPayload
        );
        $webhookResp->assertStatus(200)->assertJson(['status' => 'success']);

        $this->assertDatabaseHas('payment_transactions', [
            'transaction_reference' => $txRef,
            'payment_status' => 'successful',
            'confirmed_amount_etb' => 3500.00,
        ]);
        $this->assertDatabaseHas('advertisements', [
            'id' => $campaignId,
            'status' => 'active',
            'payment_status' => 'paid',
        ]);

        // 9. Admin authorizes a partial refund
        $refundResp = $this->actingAs($this->adminUser, 'sanctum')->postJson("/api/v1/admin/payments/transactions/{$txRef}/refund", [
            'amount' => 1000.00,
            'reason' => 'Partial reimbursement for placement reschedule.',
        ]);
        $refundResp->assertStatus(200)->assertJson(['success' => true]);

        // 10. Attempted over-refund exceeds remaining refundable balance and is rejected (SEC-05)
        $overRefundResp = $this->actingAs($this->adminUser, 'sanctum')->postJson("/api/v1/admin/payments/transactions/{$txRef}/refund", [
            'amount' => 3000.00, // Remaining balance is 2500.00
            'reason' => 'Excessive refund attempt.',
        ]);
        $overRefundResp->assertStatus(400);
    }

    /**
     * NEGATIVE & INTEGRITY TESTS: Non-existent IDs, invalid inputs, duplicate checks
     */
    public function test_negative_validations_and_boundary_checks(): void
    {
        // 1. Non-existent job returns 404
        $resp404 = $this->actingAs($this->jobSeekerUser, 'sanctum')->getJson('/api/v1/jobs/999999');
        $resp404->assertStatus(404);

        // 2. Duplicate job application rejected with 422 or 409
        $job = Job::where('status', 'published')->first();
        $doc = Document::firstOrCreate(
            ['user_id' => $this->jobSeekerUser->id],
            [
                'original_name' => 'cv.pdf',
                'storage_path' => 'documents/cv.pdf',
                'mime_type' => 'application/pdf',
                'file_size' => 1024,
                'document_type' => 'cv',
            ]
        );

        $firstApply = $this->actingAs($this->jobSeekerUser, 'sanctum')->postJson("/api/v1/jobs/{$job->id}/applications", [
            'cv_document_id' => $doc->id,
        ]);
        $firstApply->assertStatus(201);

        $duplicateApply = $this->actingAs($this->jobSeekerUser, 'sanctum')->postJson("/api/v1/jobs/{$job->id}/applications", [
            'cv_document_id' => $doc->id,
        ]);
        $this->assertContains($duplicateApply->status(), [409, 422]);

        // 3. Unauthorized access to admin users list by regular candidate rejected with 403
        $unauthResp = $this->actingAs($this->jobSeekerUser, 'sanctum')->getJson('/api/v1/admin/users');
        $unauthResp->assertStatus(403);
    }
}
