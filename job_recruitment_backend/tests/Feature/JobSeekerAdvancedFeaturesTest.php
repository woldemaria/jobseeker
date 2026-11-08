<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Document;
use App\Models\Employer;
use App\Models\EmployerMember;
use App\Models\Job;
use App\Models\JobAlert;
use App\Models\JobCategory;
use App\Models\JobSeekerProfile;
use App\Models\Role;
use App\Models\Skill;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class JobSeekerAdvancedFeaturesTest extends TestCase
{
    use RefreshDatabase;

    private User $seekerUser;
    private JobSeekerProfile $seekerProfile;
    private User $employerUser;
    private Employer $employer;
    private Job $job;
    private Document $cvDocument;

    protected function setUp(): void
    {
        parent::setUp();

        $employerRole = Role::firstOrCreate(['name' => 'employer'], ['description' => 'Employer']);
        $seekerRole = Role::firstOrCreate(['name' => 'job_seeker'], ['description' => 'Job Seeker']);

        // Seeker
        $this->seekerUser = User::factory()->create([
            'name' => 'Dawit Bekele',
            'email' => 'dawit@example.com',
            'phone' => '+251911223344',
            'status' => 'active',
        ]);
        $this->seekerUser->roles()->sync([$seekerRole->id]);

        $this->seekerProfile = JobSeekerProfile::create([
            'user_id' => $this->seekerUser->id,
            'professional_title' => 'Flutter & Laravel Full Stack Developer',
            'current_location' => 'Bole, Addis Ababa',
            'years_of_experience' => 3.5,
        ]);

        $skillPhp = Skill::firstOrCreate(['name' => 'PHP']);
        $skillFlutter = Skill::firstOrCreate(['name' => 'Flutter']);
        $this->seekerProfile->skills()->attach([
            $skillPhp->id => ['proficiency_level' => 'intermediate'],
            $skillFlutter->id => ['proficiency_level' => 'expert'],
        ]);

        $this->cvDocument = Document::create([
            'user_id' => $this->seekerUser->id,
            'document_type' => 'cv',
            'original_name' => 'Dawit_Bekele_CV.pdf',
            'storage_path' => 'documents/cvs/test.pdf',
            'file_size' => 1024,
            'mime_type' => 'application/pdf',
        ]);

        // Employer
        $this->employerUser = User::factory()->create(['status' => 'active', 'email' => 'hr@fintech.et']);
        $this->employerUser->roles()->sync([$employerRole->id]);

        $this->employer = Employer::create([
            'organization_name' => 'FinTech Ethiopia',
            'email' => 'contact@fintech.et',
            'phone' => '+251911998877',
            'verification_status' => 'approved',
        ]);

        EmployerMember::create([
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'member_role' => 'owner',
        ]);

        // Job
        $category = JobCategory::firstOrCreate(['name' => 'Software & IT', 'slug' => 'software-it']);
        $this->job = Job::create([
            'employer_id' => $this->employer->id,
            'category_id' => $category->id,
            'title' => 'Senior Mobile Developer',
            'description' => 'Build high-performance fintech mobile applications.',
            'requirements' => 'Proficiency in Flutter, PHP, and Docker.',
            'location' => 'Addis Ababa',
            'employment_type' => 'Full-time',
            'salary_min' => 45000,
            'salary_max' => 65000,
            'currency' => 'ETB',
            'deadline' => now()->addDays(25)->toDateString(),
            'status' => 'published',
            'published_at' => now(),
        ]);

        $skillDocker = Skill::firstOrCreate(['name' => 'Docker']);
        $this->job->skills()->attach([
            $skillFlutter->id => ['importance' => 'required'],
            $skillPhp->id => ['importance' => 'required'],
            $skillDocker->id => ['importance' => 'required'],
        ]);
    }

    public function test_seeker_can_create_and_manage_custom_job_alerts(): void
    {
        // 1. Create alert
        $response = $this->actingAs($this->seekerUser, 'sanctum')->postJson('/api/v1/job-alerts', [
            'title' => 'Addis Mobile Dev Alert',
            'keyword' => 'Mobile',
            'location' => 'Addis Ababa',
            'min_salary' => 40000,
            'frequency' => 'daily',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.title', 'Addis Mobile Dev Alert')
            ->assertJsonPath('data.is_active', true);

        $alertId = $response->json('data.id');

        // 2. List alerts
        $listResponse = $this->actingAs($this->seekerUser, 'sanctum')->getJson('/api/v1/job-alerts');
        $listResponse->assertStatus(200);
        $this->assertCount(1, $listResponse->json('data'));
        $this->assertGreaterThanOrEqual(1, $listResponse->json('data.0.matching_jobs_count'));

        // 3. View matches
        $matchesResponse = $this->actingAs($this->seekerUser, 'sanctum')->getJson("/api/v1/job-alerts/{$alertId}/matches");
        $matchesResponse->assertStatus(200);
        $this->assertNotEmpty($matchesResponse->json('data'));

        // 4. Toggle pause
        $toggleResponse = $this->actingAs($this->seekerUser, 'sanctum')->patchJson("/api/v1/job-alerts/{$alertId}/toggle");
        $toggleResponse->assertStatus(200);
        $this->assertFalse((bool)$toggleResponse->json('data.is_active'));

        // 5. Delete alert
        $deleteResponse = $this->actingAs($this->seekerUser, 'sanctum')->deleteJson("/api/v1/job-alerts/{$alertId}");
        $deleteResponse->assertStatus(200);
        $this->assertDatabaseMissing('job_alerts', ['id' => $alertId]);
    }

    public function test_ai_career_assistant_guidance_in_english_and_amharic(): void
    {
        // English
        $responseEn = $this->actingAs($this->seekerUser, 'sanctum')->postJson('/api/v1/career-assistant/ask', [
            'question' => 'How can I prepare for technical interviews and improve my CV?',
            'locale' => 'en',
        ]);

        $responseEn->assertStatus(200)
            ->assertJsonPath('data.category', 'cv_advice');
        $this->assertNotEmpty($responseEn->json('data.reply'));

        // Amharic
        $responseAm = $this->actingAs($this->seekerUser, 'sanctum')->postJson('/api/v1/career-assistant/ask', [
            'question' => 'ለስራ ቃለ-መጠይቅ እንዴት መዘጋጀት እችላለሁ?',
            'locale' => 'am',
        ]);

        $responseAm->assertStatus(200)
            ->assertJsonPath('data.locale', 'am');
        $this->assertStringContainsString('ቃለ-መጠይቅ', $responseAm->json('data.reply'));
    }

    public function test_ai_cover_letter_generator(): void
    {
        $response = $this->actingAs($this->seekerUser, 'sanctum')->postJson('/api/v1/career-assistant/cover-letter', [
            'job_id' => $this->job->id,
            'tone' => 'confident',
            'custom_notes' => 'I developed an offline-first payment wallet using Flutter.',
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('data.company_name', 'FinTech Ethiopia')
            ->assertJsonPath('data.tone', 'confident');

        $letter = $response->json('data.generated_letter');
        $this->assertStringContainsString('Dawit Bekele', $letter);
        $this->assertStringContainsString('Senior Mobile Developer', $letter);
        $this->assertStringContainsString('FinTech Ethiopia', $letter);
        $this->assertStringContainsString('offline-first payment wallet', $letter);
    }

    public function test_ai_interview_practice_and_model_star_answers(): void
    {
        $response = $this->actingAs($this->seekerUser, 'sanctum')->postJson('/api/v1/career-assistant/interview-practice', [
            'job_id' => $this->job->id,
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('data.company', 'FinTech Ethiopia');

        $questions = $response->json('data.questions');
        $this->assertCount(4, $questions);
        $this->assertArrayHasKey('model_answer', $questions[0]);
        $this->assertArrayHasKey('eval_tip', $questions[0]);
    }

    public function test_skill_gap_analysis(): void
    {
        $response = $this->actingAs($this->seekerUser, 'sanctum')->getJson("/api/v1/career-assistant/skill-gap/{$this->job->id}");

        $response->assertStatus(200)
            ->assertJsonPath('data.job_title', 'Senior Mobile Developer');

        $data = $response->json('data');
        $this->assertCount(2, $data['matched_skills']); // Flutter, PHP
        $this->assertCount(1, $data['missing_required_skills']); // Docker
        $this->assertNotEmpty($data['recommended_courses']);
    }

    public function test_job_offer_management_lifecycle(): void
    {
        // 1. Candidate applies
        $application = Application::create([
            'job_id' => $this->job->id,
            'profile_id' => $this->seekerProfile->id,
            'cv_document_id' => $this->cvDocument->id,
            'status' => 'shortlisted',
        ]);

        // 2. Employer issues formal offer
        $offerResponse = $this->actingAs($this->employerUser, 'sanctum')->postJson("/api/v1/applications/{$application->id}/offer", [
            'offer_salary' => 60000,
            'offer_benefits' => 'Health insurance, 10% transport allowance, performance bonus',
            'offer_conditions' => 'Standard 45-day probation period',
            'offer_start_date' => now()->addDays(14)->toDateString(),
            'offer_notes' => 'We were impressed by your technical interview.',
        ]);

        $offerResponse->assertStatus(200)
            ->assertJsonPath('data.offer_status', 'offered')
            ->assertJsonPath('data.status', 'offered');

        // 3. Seeker views offer details
        $viewResponse = $this->actingAs($this->seekerUser, 'sanctum')->getJson("/api/v1/applications/{$application->id}/offer");
        $viewResponse->assertStatus(200)
            ->assertJsonPath('data.company_name', 'FinTech Ethiopia')
            ->assertJsonPath('data.offer_salary', '60000.00');

        // 4. Seeker accepts the offer
        $acceptResponse = $this->actingAs($this->seekerUser, 'sanctum')->postJson("/api/v1/applications/{$application->id}/offer/respond", [
            'action' => 'accepted',
            'notes' => 'Delighted to accept the offer! Ready to start on the proposed date.',
        ]);

        $acceptResponse->assertStatus(200)
            ->assertJsonPath('data.offer_status', 'accepted')
            ->assertJsonPath('data.status', 'accepted');

        // 5. Duplicate response fails with 422
        $duplicateResponse = $this->actingAs($this->seekerUser, 'sanctum')->postJson("/api/v1/applications/{$application->id}/offer/respond", [
            'action' => 'declined',
        ]);
        $duplicateResponse->assertStatus(422);

        // 6. Responding to application without offer fails with 400
        $job2 = Job::create([
            'employer_id' => $this->employer->id,
            'title' => 'Backend Engineer',
            'description' => 'Laravel APIs',
            'location' => 'Addis Ababa',
            'employment_type' => 'Full-time',
            'deadline' => now()->addDays(20)->toDateString(),
            'status' => 'published',
        ]);
        $noOfferApp = Application::create([
            'job_id' => $job2->id,
            'profile_id' => $this->seekerProfile->id,
            'cv_document_id' => $this->cvDocument->id,
            'status' => 'submitted',
        ]);
        $failResponse = $this->actingAs($this->seekerUser, 'sanctum')->postJson("/api/v1/applications/{$noOfferApp->id}/offer/respond", [
            'action' => 'accepted',
        ]);
        $failResponse->assertStatus(400);

        // 7. Expired offer fails with 422
        $job3 = Job::create([
            'employer_id' => $this->employer->id,
            'title' => 'DevOps Engineer',
            'description' => 'CI/CD Pipelines',
            'location' => 'Addis Ababa',
            'employment_type' => 'Full-time',
            'deadline' => now()->addDays(20)->toDateString(),
            'status' => 'published',
        ]);
        $expiredApp = Application::create([
            'job_id' => $job3->id,
            'profile_id' => $this->seekerProfile->id,
            'cv_document_id' => $this->cvDocument->id,
            'status' => 'offered',
            'offer_status' => 'offered',
            'offer_start_date' => now()->subDays(5)->toDateString(),
        ]);
        $expiredResponse = $this->actingAs($this->seekerUser, 'sanctum')->postJson("/api/v1/applications/{$expiredApp->id}/offer/respond", [
            'action' => 'accepted',
        ]);
        $expiredResponse->assertStatus(422);
    }
}
