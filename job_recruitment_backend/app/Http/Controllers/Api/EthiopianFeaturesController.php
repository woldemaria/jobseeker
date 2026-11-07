<?php

namespace App\Http\Controllers\Api;

use App\Models\Application;
use App\Models\Job;
use App\Models\Quiz;
use App\Models\QuizOption;
use App\Models\Skill;
use App\Models\UserSkillBadge;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class EthiopianFeaturesController extends BaseApiController
{
    /**
     * 1. Physical-to-Digital QR Code Notice Board Poster
     */
    public function noticeBoardPoster(Request $request, int $jobId): JsonResponse
    {
        $job = Job::with('employer')->findOrFail($jobId);

        if (empty($job->notice_code)) {
            $job->notice_code = 'ET-JOB-' . str_pad($job->id, 5, '0', STR_PAD_LEFT);
            $job->qr_payload = 'JOBSEEKER://VACANCY/' . $job->id;
            $job->save();
        }

        $posterData = [
            'job_id' => $job->id,
            'notice_code' => $job->notice_code,
            'qr_payload' => $job->qr_payload,
            'qr_scan_url' => url('/api/v1/jobs/' . $job->id),
            'title' => $job->title,
            'employer_name' => $job->employer?->organization_name ?? $job->employer?->organizationName ?? 'Employer',
            'is_verified_employer' => $job->employer?->verification_status === 'approved',
            'location' => $job->location,
            'employment_type' => $job->employment_type,
            'salary_text' => $job->salary_min && $job->salary_max
                ? number_format($job->salary_min) . ' - ' . number_format($job->salary_max) . ' ' . $job->currency
                : 'Competitive / Negotiable',
            'deadline' => $job->deadline,
            'notice_board_type' => 'Kebele / University / Public Commercial Board',
            'instructions' => 'Scan this QR code with JobSeeker Ethiopia mobile app camera for instant 1-tap verified application.',
        ];

        return $this->successResponse($posterData, 'Physical notice board poster generated successfully.');
    }

    /**
     * 2. Hyperlocal Job Radar (Commute & Transport Cost Filter)
     */
    public function hyperlocalRadar(Request $request): JsonResponse
    {
        $subCityCoords = [
            'Bole' => ['lat' => 8.9950, 'lon' => 38.7880],
            'Kirkos' => ['lat' => 9.0110, 'lon' => 38.7550],
            'Yeka' => ['lat' => 9.0400, 'lon' => 38.8050],
            'Arada' => ['lat' => 9.0350, 'lon' => 38.7520],
            'Lideta' => ['lat' => 9.0100, 'lon' => 38.7300],
            'Nifas Silk' => ['lat' => 8.9600, 'lon' => 38.7450],
            'Akaki Kality' => ['lat' => 8.9000, 'lon' => 38.7700],
            'Hawassa' => ['lat' => 7.0500, 'lon' => 38.4833],
            'Bahir Dar' => ['lat' => 11.5900, 'lon' => 37.3900],
            'Adama' => ['lat' => 8.5400, 'lon' => 39.2700],
        ];

        $lat = $request->float('lat');
        $lon = $request->float('lon') ?: $request->float('lng');
        $subCity = $request->get('sub_city');

        if ((!$lat || !$lon) && $subCity && isset($subCityCoords[$subCity])) {
            $lat = $subCityCoords[$subCity]['lat'];
            $lon = $subCityCoords[$subCity]['lon'];
        }

        // Default to central Addis Ababa
        if (!$lat || !$lon) {
            $lat = 9.0100;
            $lon = 38.7600;
        }

        $radiusKm = $request->float('radius_km') ?: $request->float('radius', 15.0);

        // Fetch jobs with distance calculation (Haversine formula in KM)
        $jobs = Job::where('status', 'published')
            ->with(['employer', 'skills'])
            ->get()
            ->map(function ($job) use ($lat, $lon, $subCityCoords) {
                // If job has explicit coords use them, else infer from location
                $jobLat = $job->latitude;
                $jobLon = $job->longitude;

                if (!$jobLat || !$jobLon) {
                    foreach ($subCityCoords as $name => $c) {
                        if (stripos($job->location, $name) !== false) {
                            $jobLat = $c['lat'] + (crc32($job->id) % 100) * 0.0001;
                            $jobLon = $c['lon'] + (crc32($job->title) % 100) * 0.0001;
                            break;
                        }
                    }
                }

                $jobLat = $jobLat ?? 9.0150;
                $jobLon = $jobLon ?? 38.7650;

                // Haversine formula
                $theta = $lon - $jobLon;
                $dist = sin(deg2rad($lat)) * sin(deg2rad($jobLat)) +
                        cos(deg2rad($lat)) * cos(deg2rad($jobLat)) * cos(deg2rad($theta));
                $dist = acos(min(max($dist, -1.0), 1.0));
                $dist = rad2deg($dist);
                $km = round($dist * 60 * 1.1515 * 1.609344, 1);

                $job->distance_km = $km;
                $job->latitude = $jobLat;
                $job->longitude = $jobLon;

                // Commute cost & transit feasibility calculation (ETB)
                if ($km <= 3.0) {
                    $job->commute_type = 'Walking / Short Transit';
                    $job->daily_transit_cost_etb = '0 - 10 ETB';
                    $job->est_commute_minutes = '10 - 20 mins';
                } elseif ($km <= 8.0) {
                    $job->commute_type = 'Minibus Taxi / Sheger Bus';
                    $job->daily_transit_cost_etb = '15 - 30 ETB';
                    $job->est_commute_minutes = '20 - 35 mins';
                } elseif ($km <= 15.0) {
                    $job->commute_type = 'Medium Commute (Two Taxis)';
                    $job->daily_transit_cost_etb = '35 - 60 ETB';
                    $job->est_commute_minutes = '35 - 50 mins';
                } else {
                    $job->commute_type = 'Long Commute / Cross-City';
                    $job->daily_transit_cost_etb = '60 - 100 ETB';
                    $job->est_commute_minutes = '50 - 75 mins';
                }

                return $job;
            })
            ->filter(fn($j) => $j->distance_km <= $radiusKm)
            ->sortBy('distance_km')
            ->values();

        return $this->successResponse([
            'center_coordinates' => ['lat' => $lat, 'lon' => $lon],
            'radius_km' => $radiusKm,
            'total_nearby' => count($jobs),
            'jobs' => $jobs,
        ], 'Nearby vacancies retrieved based on commute distance and transit costs.');
    }

    /**
     * 3. Salary Transparency & Market Benchmark Index (ETB)
     */
    public function salaryBenchmarks(Request $request): JsonResponse
    {
        $benchmarks = [
            [
                'role' => 'Software Engineer / Flutter Developer',
                'category' => 'Information Technology',
                'p25_etb' => 25000,
                'median_etb' => 45000,
                'p75_etb' => 75000,
                'min_etb' => 18000,
                'max_etb' => 120000,
                'sample_size' => 48,
                'currency' => 'ETB',
            ],
            [
                'role' => 'Accountant & Financial Analyst',
                'category' => 'Accounting and Finance',
                'p25_etb' => 15000,
                'median_etb' => 28000,
                'p75_etb' => 45000,
                'min_etb' => 12000,
                'max_etb' => 65000,
                'sample_size' => 62,
                'currency' => 'ETB',
            ],
            [
                'role' => 'Civil / Structural Engineer',
                'category' => 'Construction and Engineering',
                'p25_etb' => 20000,
                'median_etb' => 35000,
                'p75_etb' => 60000,
                'min_etb' => 15000,
                'max_etb' => 90000,
                'sample_size' => 34,
                'currency' => 'ETB',
            ],
            [
                'role' => 'Agronomist & Farm Manager',
                'category' => 'Agriculture and Farming',
                'p25_etb' => 18000,
                'median_etb' => 30000,
                'p75_etb' => 48000,
                'min_etb' => 14000,
                'max_etb' => 70000,
                'sample_size' => 38,
                'currency' => 'ETB',
            ],
            [
                'role' => 'Primary & Secondary School Teacher',
                'category' => 'Education and Teaching',
                'p25_etb' => 12000,
                'median_etb' => 20000,
                'p75_etb' => 32000,
                'min_etb' => 9000,
                'max_etb' => 45000,
                'sample_size' => 50,
                'currency' => 'ETB',
            ],
            [
                'role' => 'Nurse & Medical Officer',
                'category' => 'Healthcare and Medical',
                'p25_etb' => 16000,
                'median_etb' => 27000,
                'p75_etb' => 44000,
                'min_etb' => 12000,
                'max_etb' => 60000,
                'sample_size' => 44,
                'currency' => 'ETB',
            ],
            [
                'role' => 'Logistics & Supply Chain Officer',
                'category' => 'Transportation and Logistics',
                'p25_etb' => 16000,
                'median_etb' => 26000,
                'p75_etb' => 42000,
                'min_etb' => 11000,
                'max_etb' => 58000,
                'sample_size' => 40,
                'currency' => 'ETB',
            ],
            [
                'role' => 'Hotel & Restaurant Manager',
                'category' => 'Hotel, Restaurant and Tourism',
                'p25_etb' => 14000,
                'median_etb' => 24000,
                'p75_etb' => 38000,
                'min_etb' => 10000,
                'max_etb' => 52000,
                'sample_size' => 36,
                'currency' => 'ETB',
            ],
            [
                'role' => 'Sales & Marketing Representative',
                'category' => 'Shopping, Retail and Sales',
                'p25_etb' => 12000,
                'median_etb' => 22000,
                'p75_etb' => 38000,
                'min_etb' => 9000,
                'max_etb' => 55000,
                'sample_size' => 55,
                'currency' => 'ETB',
            ],
            [
                'role' => 'Customer Support & Operations',
                'category' => 'Other and Emerging Jobs',
                'p25_etb' => 10000,
                'median_etb' => 18000,
                'p75_etb' => 28000,
                'min_etb' => 8000,
                'max_etb' => 40000,
                'sample_size' => 42,
                'currency' => 'ETB',
            ],
        ];

        return $this->successResponse($benchmarks, 'Salary transparency and market benchmarks retrieved.');
    }

    /**
     * 4. Micro-Skill Assessment Quizzes & Badges
     */
    public function listQuizzes(Request $request): JsonResponse
    {
        $userId = $request->user()->id;
        $userBadgeSkillIds = UserSkillBadge::where('user_id', $userId)->pluck('skill_id')->toArray();

        $quizzes = Quiz::with('skill')->get()->map(function ($q) use ($userBadgeSkillIds) {
            $q->is_verified = in_array($q->skill_id, $userBadgeSkillIds);
            return $q;
        });

        return $this->successResponse($quizzes, 'Available skills assessment quizzes retrieved.');
    }

    public function showQuiz(Request $request, int $id): JsonResponse
    {
        $quiz = Quiz::with(['questions.options' => function ($q) {
            $q->select('id', 'quiz_question_id', 'option_text')->inRandomOrder();
        }])->findOrFail($id);

        return $this->successResponse($quiz, 'Quiz questions loaded.');
    }

    public function submitQuiz(Request $request, int $id): JsonResponse
    {
        $quiz = Quiz::with('questions.options')->findOrFail($id);
        $user = $request->user();

        $validated = $request->validate([
            'answers' => 'required|array', // question_id => option_id
        ]);

        $rawAnswers = $validated['answers'];
        $submittedAnswers = [];
        foreach ($rawAnswers as $key => $val) {
            if (is_array($val) && isset($val['question_id']) && isset($val['option_id'])) {
                $submittedAnswers[$val['question_id']] = $val['option_id'];
            } else {
                $submittedAnswers[$key] = $val;
            }
        }

        $correctCount = 0;
        $totalQuestions = $quiz->questions->count();

        foreach ($quiz->questions as $question) {
            $correctOption = $question->options->firstWhere('is_correct', true);
            if ($correctOption && isset($submittedAnswers[$question->id])) {
                if ((int)$submittedAnswers[$question->id] === (int)$correctOption->id) {
                    $correctCount++;
                }
            }
        }

        $scorePercent = $totalQuestions > 0 ? round(($correctCount / $totalQuestions) * 100, 1) : 0;
        $passed = $scorePercent >= $quiz->passing_score;

        $badge = null;
        if ($passed) {
            $badge = UserSkillBadge::updateOrCreate(
                ['user_id' => $user->id, 'skill_id' => $quiz->skill_id],
                [
                    'quiz_id' => $quiz->id,
                    'score' => $scorePercent,
                    'badge_type' => 'verified_skill',
                    'verified_at' => now(),
                ]
            );
        }

        return $this->successResponse([
            'score_percent' => $scorePercent,
            'passed' => $passed,
            'correct_count' => $correctCount,
            'total_questions' => $totalQuestions,
            'badge' => $badge,
            'message' => $passed
                ? 'Congratulations! You passed the skills assessment and earned a Verified Skill badge.'
                : 'Assessment completed. A passing score of 80% is required to earn the badge.',
        ], 'Quiz evaluated.');
    }

    public function userBadges(Request $request): JsonResponse
    {
        $badges = UserSkillBadge::where('user_id', $request->user()->id)
            ->with(['skill', 'quiz'])
            ->get();

        return $this->successResponse($badges, 'User verified skill badges retrieved.');
    }

    /**
     * 5. Batch Candidate Dossier Export for Recruiters
     */
    public function exportCandidatePack(Request $request, int $jobId): JsonResponse
    {
        $job = Job::with('employer')->findOrFail($jobId);
        $user = $request->user();

        $isEmployer = $user->employers->contains('id', $job->employer_id);
        if (!$isEmployer && !$user->isAdmin()) {
            return $this->errorResponse('Unauthorized to export candidates for this vacancy.', 403);
        }

        $applications = Application::where('job_id', $job->id)
            ->whereIn('status', ['shortlisted', 'interview', 'accepted'])
            ->with(['profile.user', 'profile.skills', 'cvDocument'])
            ->get()
            ->map(function ($app) {
                return [
                    'application_id' => $app->id,
                    'candidate_name' => $app->profile->user->name,
                    'email' => $app->profile->user->email,
                    'phone' => $app->profile->user->phone,
                    'education' => $app->profile->education_level . ' in ' . $app->profile->field_of_study,
                    'experience_years' => $app->profile->experience_years,
                    'status' => $app->status,
                    'applied_at' => $app->applied_at,
                    'cv_document_name' => $app->cvDocument?->original_name,
                    'skills' => $app->profile->skills->pluck('name')->toArray(),
                ];
            });

        return $this->successResponse([
            'job_title' => $job->title,
            'employer' => $job->employer?->organization_name ?? $job->employer?->organizationName ?? 'Employer',
            'export_date' => now()->toDateString(),
            'total_candidates' => count($applications),
            'candidates' => $applications,
            'dossier_summary' => "Candidate dossier pack compiled with {$applications->count()} shortlisted profiles ready for hiring panel review.",
        ], 'Candidate pack exported successfully.');
    }
}
