<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Document;
use App\Models\Job;
use App\Models\JobScreeningQuestion;
use App\Models\Quiz;
use App\Models\QuizOption;
use App\Models\QuizQuestion;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class EthiopianFeaturesTest extends TestCase
{
    use RefreshDatabase;

    private User $seekerUser;
    private User $employerUser;
    private Job $job;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();

        $this->seekerUser = User::where('email', 'jobseeker@example.com')->first();
        $this->employerUser = User::where('email', 'recruitment@example.com')->first();

        // Update first job with coords and notice code
        $this->job = Job::first();
        $this->job->update([
            'latitude' => 8.9806,
            'longitude' => 38.7578,
            'notice_code' => 'ET-JOB-00001',
            'qr_payload' => 'JOBSEEKER://VACANCY/' . $this->job->id,
            'salary_min' => 45000,
            'salary_max' => 65000,
        ]);
    }

    public function test_notice_board_poster_generates_printable_code(): void
    {
        $response = $this->getJson("/api/v1/jobs/{$this->job->id}/poster");
        $response->assertStatus(200)
            ->assertJsonPath('data.notice_code', 'ET-JOB-00001')
            ->assertJsonPath('data.qr_payload', 'JOBSEEKER://VACANCY/' . $this->job->id);
    }

    public function test_hyperlocal_radar_calculates_distance_and_transit_costs(): void
    {
        // Candidate is at Kirkos (8.995, 38.760) which is approx ~2km from Bole (8.9806, 38.7578)
        $response = $this->getJson('/api/v1/jobs/radar?lat=8.995&lon=38.760&radius_km=10');
        $response->assertStatus(200);
        $this->assertGreaterThanOrEqual(1, count($response->json('data.jobs')));
        $item = $response->json('data.jobs.0');
        $this->assertArrayHasKey('distance_km', $item);
        $this->assertArrayHasKey('daily_transit_cost_etb', $item);
        $this->assertArrayHasKey('commute_type', $item);
    }

    public function test_salary_benchmarks_returns_aggregates(): void
    {
        $response = $this->getJson('/api/v1/salary-benchmarks');
        $response->assertStatus(200);
        $this->assertNotEmpty($response->json('data'));
    }

    public function test_quiz_completion_and_skill_badge_award(): void
    {
        $skill = \App\Models\Skill::first() ?? \App\Models\Skill::create(['name' => 'Flutter', 'category' => 'Mobile Development']);

        $quiz = Quiz::create([
            'skill_id' => $skill->id,
            'title' => 'Flutter Developer Assessment',
            'skill_name' => 'Flutter',
            'description' => 'Test your knowledge of Flutter and Dart',
            'passing_score' => 80,
            'time_limit_seconds' => 60,
        ]);

        $q1 = QuizQuestion::create([
            'quiz_id' => $quiz->id,
            'question_text' => 'What is the build method in StatelessWidget?',
            'points' => 10,
        ]);
        $opt1 = QuizOption::create([
            'quiz_question_id' => $q1->id,
            'option_text' => 'A method that describes the UI part represented by the widget.',
            'is_correct' => true,
        ]);
        QuizOption::create([
            'quiz_question_id' => $q1->id,
            'option_text' => 'A method for network requests.',
            'is_correct' => false,
        ]);

        $response = $this->actingAs($this->seekerUser, 'sanctum')
            ->postJson("/api/v1/quizzes/{$quiz->id}/submit", [
                'answers' => [
                    ['question_id' => $q1->id, 'option_id' => $opt1->id],
                ],
            ]);

        $response->assertStatus(200)
            ->assertJsonPath('data.passed', true)
            ->assertJsonPath('data.score_percent', 100);

        // Verify badge was saved
        $this->assertDatabaseHas('user_skill_badges', [
            'user_id' => $this->seekerUser->id,
            'badge_type' => 'verified_skill',
        ]);

        // User badges endpoint
        $badgesResponse = $this->actingAs($this->seekerUser, 'sanctum')->getJson('/api/v1/user/badges');
        $badgesResponse->assertStatus(200)
            ->assertJsonCount(1, 'data');
    }

    public function test_knockout_screening_questions_auto_reject_unqualified(): void
    {
        // Pick a published job where seeker hasn't applied
        $secondJob = Job::where('id', '!=', 1)->where('status', 'published')->first();
        if (!$secondJob) {
            $secondJob = Job::create([
                'employer_id' => $this->job->employer_id,
                'title' => 'Junior Flutter Developer',
                'description' => 'Entry level',
                'location' => 'Addis Ababa',
                'employment_type' => 'full_time',
                'experience_required' => 1.0,
                'salary_min' => 20000,
                'salary_max' => 30000,
                'currency' => 'ETB',
                'status' => 'published',
                'deadline' => now()->addDays(15)->toDateString(),
            ]);
        }

        $q = JobScreeningQuestion::create([
            'job_id' => $secondJob->id,
            'question_text' => 'Do you have at least 4 years of production Flutter experience?',
            'expected_boolean' => true,
            'is_knockout' => true,
        ]);

        $cv = Document::create([
            'user_id' => $this->seekerUser->id,
            'document_type' => 'cv',
            'original_name' => 'resume.pdf',
            'stored_name' => 'resume_123.pdf',
            'storage_path' => 'private/documents/' . $this->seekerUser->id . '/resume.pdf',
            'file_size' => 1024,
            'mime_type' => 'application/pdf',
        ]);

        // Candidate answers "false" to mandatory knockout question
        $response = $this->actingAs($this->seekerUser, 'sanctum')
            ->postJson("/api/v1/jobs/{$secondJob->id}/apply", [
                'cv_document_id' => $cv->id,
                'cover_letter' => 'I am eager to learn.',
                'screening_answers' => [
                    ['question_id' => $q->id, 'answer' => false],
                ],
            ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('applications', [
            'job_id' => $secondJob->id,
            'profile_id' => $this->seekerUser->jobSeekerProfile->id,
            'status' => 'rejected',
        ]);
        $this->assertDatabaseHas('application_screening_answers', [
            'question_id' => $q->id,
            'answer_boolean' => false,
            'passed' => false,
        ]);
    }

    public function test_recruiter_can_export_candidate_pack(): void
    {
        $response = $this->actingAs($this->employerUser, 'sanctum')
            ->postJson("/api/v1/jobs/{$this->job->id}/export-candidates");

        $response->assertStatus(200)
            ->assertJsonPath('data.job_title', $this->job->title);
    }
}
