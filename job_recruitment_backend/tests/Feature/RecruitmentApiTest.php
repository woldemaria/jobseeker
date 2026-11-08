<?php

namespace Tests\Feature;

use App\Models\Document;
use App\Models\Employer;
use App\Models\EmployerMember;
use App\Models\Job;
use App\Models\JobSeekerProfile;
use App\Models\Role;
use App\Models\Skill;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class RecruitmentApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    /** TC-001: User registration */
    public function test_user_registration_creates_account_and_profile(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Sara Daniel',
            'email' => 'sara@test.com',
            'phone' => '+251912345678',
            'password' => 'Password@123',
            'password_confirmation' => 'Password@123',
            'role' => 'job_seeker',
        ]);

        $response->assertStatus(201)
                 ->assertJson(['success' => true]);

        $this->assertDatabaseHas('users', ['email' => 'sara@test.com']);
        $this->assertDatabaseHas('job_seeker_profiles', [
            'user_id' => User::where('email', 'sara@test.com')->first()->id
        ]);
    }

    /** TC-002: User login */
    public function test_user_can_login_and_receive_token(): void
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'jobseeker@example.com',
            'password' => 'Seeker@123456',
        ]);

        $response->assertStatus(200)
                 ->assertJson(['success' => true])
                 ->assertJsonStructure(['data' => ['token', 'user']]);
    }

    /** TC-003: Invalid login rejected */
    public function test_invalid_login_rejected(): void
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'jobseeker@example.com',
            'password' => 'WrongPassword',
        ]);

        $response->assertStatus(401)
                 ->assertJson(['success' => false]);
    }

    /** TC-004: Update profile */
    public function test_job_seeker_can_update_profile(): void
    {
        $user = User::where('email', 'jobseeker@example.com')->first();

        $response = $this->actingAs($user, 'sanctum')->putJson('/api/v1/profile', [
            'location' => 'Hawassa',
            'biography' => 'Updated senior software engineer biography.',
            'experience_years' => 4.0,
        ]);

        $response->assertStatus(200)
                 ->assertJson(['success' => true]);

        $this->assertDatabaseHas('job_seeker_profiles', [
            'user_id' => $user->id,
            'location' => 'Hawassa',
        ]);
    }

    /** TC-005: Employer can create vacancy */
    public function test_employer_can_create_vacancy(): void
    {
        $employerUser = User::where('email', 'recruitment@example.com')->first();

        $response = $this->actingAs($employerUser, 'sanctum')->postJson('/api/v1/jobs', [
            'title' => 'Senior Mobile Architect',
            'description' => 'Architecting resilient mobile solutions.',
            'location' => 'Addis Ababa',
            'employment_type' => 'Full-time',
            'experience_required' => 5.0,
            'salary_min' => 50000,
            'salary_max' => 70000,
            'deadline' => now()->addDays(30)->toDateString(),
            'status' => 'published',
        ]);

        $response->assertStatus(201)
                 ->assertJson(['success' => true]);

        $this->assertDatabaseHas('jobs', ['title' => 'Senior Mobile Architect']);
    }

    /** TC-006: Search jobs */
    public function test_search_jobs_with_keyword_and_location(): void
    {
        $response = $this->getJson('/api/v1/jobs?keyword=Flutter&location=Addis');

        $response->assertStatus(200)
                 ->assertJson(['success' => true]);
        $this->assertNotEmpty($response->json('data'));
    }

    /** TC-007 & TC-008: Apply for job and duplicate application rejection */
    public function test_apply_for_job_and_prevent_duplicate_submission(): void
    {
        $user = User::where('email', 'jobseeker@example.com')->first();
        $job = Job::where('title', 'Junior Flutter Developer')->first();
        $doc = Document::where('user_id', $user->id)->first();

        // 1. Submit first application
        $response1 = $this->actingAs($user, 'sanctum')->postJson("/api/v1/jobs/{$job->id}/applications", [
            'cv_document_id' => $doc->id,
            'cover_letter' => 'I am very excited to apply for this position.',
        ]);

        $response1->assertStatus(201)
                  ->assertJson(['success' => true]);

        $this->assertDatabaseHas('applications', [
            'job_id' => $job->id,
            'profile_id' => $user->jobSeekerProfile->id,
        ]);

        // 2. Duplicate submission must be rejected
        $response2 = $this->actingAs($user, 'sanctum')->postJson("/api/v1/jobs/{$job->id}/applications", [
            'cv_document_id' => $doc->id,
            'cover_letter' => 'Second attempt should fail.',
        ]);

        $response2->assertStatus(422);
    }

    /** TC-009: Application status update */
    public function test_employer_can_update_application_status(): void
    {
        $jobSeeker = User::where('email', 'jobseeker@example.com')->first();
        $employer = User::where('email', 'recruitment@example.com')->first();
        $job = Job::where('title', 'Junior Flutter Developer')->first();
        $doc = Document::where('user_id', $jobSeeker->id)->first();

        // Create application
        $this->actingAs($jobSeeker, 'sanctum')->postJson("/api/v1/jobs/{$job->id}/applications", [
            'cv_document_id' => $doc->id,
        ]);

        $application = $job->applications()->first();

        // Employer updates status
        $updateResp = $this->actingAs($employer, 'sanctum')->patchJson("/api/v1/applications/{$application->id}/status", [
            'status' => 'shortlisted',
            'notes' => 'Candidate has strong Flutter portfolio.',
        ]);

        $updateResp->assertStatus(200)
                   ->assertJson(['success' => true]);

        $this->assertDatabaseHas('applications', [
            'id' => $application->id,
            'status' => 'shortlisted',
        ]);

        $this->assertDatabaseHas('application_status_histories', [
            'application_id' => $application->id,
            'new_status' => 'shortlisted',
        ]);
    }

    /** TC-010: View recommendation and explainable match score */
    public function test_skills_based_recommendations_and_explanation(): void
    {
        $user = User::where('email', 'jobseeker@example.com')->first();
        $job = Job::where('title', 'Junior Flutter Developer')->first();

        // Check recommendations
        $recResp = $this->actingAs($user, 'sanctum')->getJson('/api/v1/recommendations/jobs');
        $recResp->assertStatus(200)
                ->assertJson(['success' => true]);

        // Check match details
        $matchResp = $this->actingAs($user, 'sanctum')->getJson("/api/v1/jobs/{$job->id}/match");
        $matchResp->assertStatus(200)
                  ->assertJson(['success' => true])
                  ->assertJsonStructure([
                      'data' => [
                          'match_analysis' => [
                              'match_score',
                              'breakdown' => [
                                  'skills',
                                  'education',
                                  'experience',
                                  'location',
                              ],
                              'explanation',
                          ]
                      ]
                  ]);

        $score = $matchResp->json('data.match_analysis.match_score');
        $this->assertGreaterThan(70, $score);
    }

    /** TC-011: Unauthorized access rejection */
    public function test_unauthenticated_requests_are_rejected(): void
    {
        $response = $this->getJson('/api/v1/profile');
        $response->assertStatus(401);
    }

    /** TC-012: Upload invalid file extension */
    public function test_invalid_file_upload_rejected(): void
    {
        Storage::fake('local');
        $user = User::where('email', 'jobseeker@example.com')->first();

        $file = UploadedFile::fake()->create('malicious.exe', 500);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/documents', [
            'file' => $file,
            'document_type' => 'cv',
        ]);

        $response->assertStatus(422);
    }

    /** TC-013: Employer can schedule interview and candidate confirms */
    public function test_employer_schedules_interview_and_candidate_confirms(): void
    {
        $employerUser = User::where('email', 'recruitment@example.com')->first();
        $candidateUser = User::where('email', 'jobseeker@example.com')->first();
        $job = Job::first();

        // Ensure candidate has application
        $application = \App\Models\Application::firstOrCreate(
            ['job_id' => $job->id, 'profile_id' => $candidateUser->jobSeekerProfile->id],
            [
                'cv_document_id' => Document::first()->id,
                'status' => 'shortlisted',
                'applied_at' => now(),
            ]
        );

        // Employer schedules interview
        $scheduleResp = $this->actingAs($employerUser, 'sanctum')->postJson("/api/v1/applications/{$application->id}/interview", [
            'interview_at' => '2026-11-15 10:00:00',
            'interview_type' => 'video',
            'interview_location' => 'https://meet.google.com/test-room',
            'interview_notes' => 'Prepare coding test walkthrough.',
        ]);

        $scheduleResp->assertStatus(200)
                     ->assertJson(['success' => true]);

        $this->assertDatabaseHas('applications', [
            'id' => $application->id,
            'status' => 'interview',
            'interview_type' => 'video',
            'interview_status' => 'scheduled',
        ]);

        // Candidate confirms interview
        $confirmResp = $this->actingAs($candidateUser, 'sanctum')->postJson("/api/v1/applications/{$application->id}/interview/confirm");
        $confirmResp->assertStatus(200)
                    ->assertJson(['success' => true]);

        $this->assertDatabaseHas('applications', [
            'id' => $application->id,
            'interview_status' => 'confirmed',
        ]);
    }

    /** TC-014: ProfileRequest professional validation error handling */
    public function test_profile_request_validation_returns_professional_error_structure(): void
    {
        $candidateUser = User::where('email', 'jobseeker@example.com')->first();

        // Submit invalid phone format, negative experience, future date of birth
        $response = $this->actingAs($candidateUser, 'sanctum')->putJson('/api/v1/profile', [
            'name' => 'A', // too short (< 2 chars)
            'phone' => 'invalid-phone-letters#$%',
            'experience_years' => -5,
            'date_of_birth' => '2099-01-01', // future date
            'gender' => 'invalid_gender_val',
        ]);

        $response->assertStatus(422)
                 ->assertJson([
                     'success' => false,
                     'data' => null,
                 ])
                 ->assertJsonStructure([
                     'success',
                     'message',
                     'data',
                     'errors' => [
                         'name',
                         'phone',
                         'experience_years',
                         'date_of_birth',
                         'gender',
                     ]
                 ]);
    }

    /** TC-015: Job seeker can create, update, and delete education records */
    public function test_job_seeker_can_manage_education_lifecycle(): void
    {
        $candidateUser = User::where('email', 'jobseeker@example.com')->first();

        // 1. Create education
        $createResp = $this->actingAs($candidateUser, 'sanctum')->postJson('/api/v1/profile/education', [
            'institution_name' => 'Addis Ababa University',
            'qualification' => 'B.Sc. in Computer Science',
            'field_of_study' => 'Software Engineering',
            'start_date' => '2019-09-01',
            'end_date' => '2023-07-01',
            'grade' => '3.85',
            'description' => 'Graduated with Great Distinction.',
        ]);
        $createResp->assertStatus(201)
                   ->assertJson(['success' => true]);
        $eduId = $createResp->json('data.id');

        $this->assertDatabaseHas('education_records', [
            'id' => $eduId,
            'institution_name' => 'Addis Ababa University',
            'qualification' => 'B.Sc. in Computer Science',
        ]);

        // 2. Update education
        $updateResp = $this->actingAs($candidateUser, 'sanctum')->putJson("/api/v1/profile/education/{$eduId}", [
            'institution_name' => 'Addis Ababa University (AAU)',
            'qualification' => 'M.Sc. in Computer Science',
            'field_of_study' => 'Artificial Intelligence',
            'start_date' => '2023-10-01',
            'grade' => '3.95',
        ]);
        $updateResp->assertStatus(200)
                   ->assertJson(['success' => true]);

        $this->assertDatabaseHas('education_records', [
            'id' => $eduId,
            'institution_name' => 'Addis Ababa University (AAU)',
            'qualification' => 'M.Sc. in Computer Science',
        ]);

        // 3. Delete education
        $deleteResp = $this->actingAs($candidateUser, 'sanctum')->deleteJson("/api/v1/profile/education/{$eduId}");
        $deleteResp->assertStatus(200)
                   ->assertJson(['success' => true]);

        $this->assertDatabaseMissing('education_records', ['id' => $eduId]);
    }

    /** TC-016: Job seeker can create, update, and delete work experience records */
    public function test_job_seeker_can_manage_experience_lifecycle(): void
    {
        $candidateUser = User::where('email', 'jobseeker@example.com')->first();

        // 1. Create experience
        $createResp = $this->actingAs($candidateUser, 'sanctum')->postJson('/api/v1/profile/experience', [
            'company_name' => 'Ethio Telecom',
            'job_title' => 'Junior Developer',
            'employment_type' => 'Full-time',
            'start_date' => '2023-08-01',
            'end_date' => '2024-05-01',
            'is_current' => false,
            'description' => 'Backend development with PHP and Laravel.',
        ]);
        $createResp->assertStatus(201)
                   ->assertJson(['success' => true]);
        $expId = $createResp->json('data.id');

        $this->assertDatabaseHas('work_experiences', [
            'id' => $expId,
            'company_name' => 'Ethio Telecom',
            'job_title' => 'Junior Developer',
        ]);

        // 2. Update experience
        $updateResp = $this->actingAs($candidateUser, 'sanctum')->putJson("/api/v1/profile/experience/{$expId}", [
            'company_name' => 'Ethio Telecom HQ',
            'job_title' => 'Mid-Level Full Stack Developer',
            'employment_type' => 'Full-time',
            'start_date' => '2023-08-01',
            'is_current' => true,
            'description' => 'Promoted to lead backend developer.',
        ]);
        $updateResp->assertStatus(200)
                   ->assertJson(['success' => true]);

        $this->assertDatabaseHas('work_experiences', [
            'id' => $expId,
            'company_name' => 'Ethio Telecom HQ',
            'job_title' => 'Mid-Level Full Stack Developer',
            'is_current' => 1,
        ]);

        // 3. Delete experience
        $deleteResp = $this->actingAs($candidateUser, 'sanctum')->deleteJson("/api/v1/profile/experience/{$expId}");
        $deleteResp->assertStatus(200)
                   ->assertJson(['success' => true]);

        $this->assertDatabaseMissing('work_experiences', ['id' => $expId]);
    }
}
