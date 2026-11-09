<?php

namespace App\Services;

use App\Models\Job;
use App\Models\JobSeekerProfile;
use Illuminate\Support\Collection;

class MatchingService
{
    /**
     * Weights defined in Chapter 9 of System Implementation and Design Specifications:
     * Skills: 40% (0.40)
     * Education: 20% (0.20)
     * Experience: 15% (0.15)
     * Location: 10% (0.10)
     * Employment Type: 10% (0.10)
     * Other Requirements: 5% (0.05)
     */
    public const WEIGHT_SKILLS = 0.40;
    public const WEIGHT_EDUCATION = 0.20;
    public const WEIGHT_EXPERIENCE = 0.15;
    public const WEIGHT_LOCATION = 0.10;
    public const WEIGHT_EMPLOYMENT = 0.10;
    public const WEIGHT_OTHER = 0.05;

    /**
     * Calculate matching score and return detailed explanation.
     */
    public function calculateMatch(JobSeekerProfile $profile, Job $job): array
    {
        $profile->loadMissing(['skills', 'educationRecords', 'workExperiences']);
        $job->loadMissing(['skills', 'employer']);

        // 1. Skills Score (40%)
        $skillsAnalysis = $this->analyzeSkills($profile, $job);
        $skillsScore = $skillsAnalysis['score'];

        // 2. Education Score (20%)
        $educationAnalysis = $this->analyzeEducation($profile, $job);
        $educationScore = $educationAnalysis['score'];

        // 3. Experience Score (15%)
        $experienceAnalysis = $this->analyzeExperience($profile, $job);
        $experienceScore = $experienceAnalysis['score'];

        // 4. Location Score (10%)
        $locationAnalysis = $this->analyzeLocation($profile, $job);
        $locationScore = $locationAnalysis['score'];

        // 5. Employment Type Score (10%)
        $employmentAnalysis = $this->analyzeEmploymentType($profile, $job);
        $employmentScore = $employmentAnalysis['score'];

        // 6. Other Requirements Score (5%)
        $otherAnalysis = $this->analyzeOtherRequirements($profile, $job);
        $otherScore = $otherAnalysis['score'];

        // Calculate total weighted score
        $totalScore = (
            ($skillsScore * self::WEIGHT_SKILLS) +
            ($educationScore * self::WEIGHT_EDUCATION) +
            ($experienceScore * self::WEIGHT_EXPERIENCE) +
            ($locationScore * self::WEIGHT_LOCATION) +
            ($employmentScore * self::WEIGHT_EMPLOYMENT) +
            ($otherScore * self::WEIGHT_OTHER)
        );

        $matchPercentage = round($totalScore, 1);

        return [
            'match_score' => $matchPercentage,
            'breakdown' => [
                'skills' => [
                    'weight' => '40%',
                    'score' => $skillsScore,
                    'weighted_score' => round($skillsScore * self::WEIGHT_SKILLS, 2),
                    'matching_skills' => $skillsAnalysis['matching_skills'],
                    'missing_required_skills' => $skillsAnalysis['missing_required_skills'],
                    'missing_preferred_skills' => $skillsAnalysis['missing_preferred_skills'],
                ],
                'education' => [
                    'weight' => '20%',
                    'score' => $educationScore,
                    'weighted_score' => round($educationScore * self::WEIGHT_EDUCATION, 2),
                    'status' => $educationAnalysis['status'],
                    'explanation' => $educationAnalysis['explanation'],
                ],
                'experience' => [
                    'weight' => '15%',
                    'score' => $experienceScore,
                    'weighted_score' => round($experienceScore * self::WEIGHT_EXPERIENCE, 2),
                    'status' => $experienceAnalysis['status'],
                    'candidate_years' => (float)$profile->experience_years,
                    'required_years' => (float)($job->experience_required ?? 0),
                    'explanation' => $experienceAnalysis['explanation'],
                ],
                'location' => [
                    'weight' => '10%',
                    'score' => $locationScore,
                    'weighted_score' => round($locationScore * self::WEIGHT_LOCATION, 2),
                    'candidate_location' => $profile->location,
                    'job_location' => $job->location,
                ],
                'employment_type' => [
                    'weight' => '10%',
                    'score' => $employmentScore,
                    'weighted_score' => round($employmentScore * self::WEIGHT_EMPLOYMENT, 2),
                    'job_employment_type' => $job->employment_type,
                ],
                'other_requirements' => [
                    'weight' => '5%',
                    'score' => $otherScore,
                    'weighted_score' => round($otherScore * self::WEIGHT_OTHER, 2),
                    'explanation' => $otherAnalysis['explanation'],
                ],
            ],
            'explanation' => $this->generateSummaryExplanation($matchPercentage, $skillsAnalysis, $educationAnalysis, $experienceAnalysis),
        ];
    }

    /**
     * Get recommended jobs for job seeker sorted by match score.
     */
    public function getRecommendations(JobSeekerProfile $profile, int $limit = 20): Collection
    {
        $publishedJobs = Job::published()
            ->with(['employer', 'skills'])
            ->get();

        $recommendations = $publishedJobs->map(function ($job) use ($profile) {
            $matchResult = $this->calculateMatch($profile, $job);
            $job->match_score = $matchResult['match_score'];
            $job->match_details = $matchResult;
            return $job;
        });

        return $recommendations->sortByDesc('match_score')->values()->take($limit);
    }

    private function analyzeSkills(JobSeekerProfile $profile, Job $job): array
    {
        $candidateSkills = $profile->skills->keyBy(fn($s) => strtolower(trim($s->name)));
        $requiredSkills = $job->skills->filter(fn($s) => $s->pivot->importance === 'required');
        $preferredSkills = $job->skills->filter(fn($s) => $s->pivot->importance === 'preferred');

        $matchingSkills = [];
        $missingRequired = [];
        $missingPreferred = [];

        foreach ($requiredSkills as $skill) {
            $key = strtolower(trim($skill->name));
            if ($candidateSkills->has($key)) {
                $matchingSkills[] = $skill->name;
            } else {
                $missingRequired[] = $skill->name;
            }
        }

        foreach ($preferredSkills as $skill) {
            $key = strtolower(trim($skill->name));
            if ($candidateSkills->has($key)) {
                $matchingSkills[] = $skill->name . ' (preferred)';
            } else {
                $missingPreferred[] = $skill->name;
            }
        }

        $totalRequired = $requiredSkills->count();
        $totalPreferred = $preferredSkills->count();

        if ($totalRequired === 0 && $totalPreferred === 0) {
            return [
                'score' => 85.0,
                'matching_skills' => [],
                'missing_required_skills' => [],
                'missing_preferred_skills' => [],
            ];
        }

        // Required skills weight 70% of skills score, preferred skills weight 30%
        $matchedRequiredCount = $totalRequired - count($missingRequired);
        $matchedPreferredCount = $totalPreferred - count($missingPreferred);

        $reqRatio = $totalRequired > 0 ? ($matchedRequiredCount / $totalRequired) : 1.0;
        $prefRatio = $totalPreferred > 0 ? ($matchedPreferredCount / $totalPreferred) : 1.0;

        $score = ($reqRatio * 70) + ($prefRatio * 30);

        return [
            'score' => round($score, 1),
            'matching_skills' => array_values(array_unique($matchingSkills)),
            'missing_required_skills' => array_values($missingRequired),
            'missing_preferred_skills' => array_values($missingPreferred),
        ];
    }

    private function analyzeEducation(JobSeekerProfile $profile, Job $job): array
    {
        $candidateEdu = strtolower(trim($profile->education_level ?? ''));
        $jobReqs = strtolower(trim(($job->requirements ?? '') . ' ' . ($job->description ?? '')));

        if (empty($candidateEdu)) {
            return [
                'score' => 50.0,
                'status' => 'Not Specified',
                'explanation' => 'Candidate education level is not specified.',
            ];
        }

        $levels = [
            'phd' => 100,
            'doctorate' => 100,
            'master' => 90,
            'msc' => 90,
            'bachelor' => 80,
            'bsc' => 80,
            'degree' => 80,
            'diploma' => 60,
            'high school' => 40,
        ];

        $candidateLevelScore = 70;
        foreach ($levels as $keyword => $val) {
            if (str_contains($candidateEdu, $keyword)) {
                $candidateLevelScore = $val;
                break;
            }
        }

        $isMentionedInJob = false;
        foreach ($levels as $keyword => $val) {
            if (str_contains($jobReqs, $keyword) && str_contains($candidateEdu, $keyword)) {
                $isMentionedInJob = true;
                break;
            }
        }

        $score = $isMentionedInJob ? 100.0 : max($candidateLevelScore, 75.0);

        return [
            'score' => (float)$score,
            'status' => $score >= 80 ? 'Meets Requirement' : 'Partially Meets Requirement',
            'explanation' => "Candidate holds '{$profile->education_level}'.",
        ];
    }

    private function analyzeExperience(JobSeekerProfile $profile, Job $job): array
    {
        $candidateYears = (float)($profile->experience_years ?? 0);
        $requiredYears = (float)($job->experience_required ?? 0);

        if ($requiredYears <= 0) {
            return [
                'score' => 100.0,
                'status' => 'Exceeds or Meets Requirement',
                'explanation' => 'No prior experience strictly mandated.',
            ];
        }

        if ($candidateYears >= $requiredYears) {
            $score = 100.0;
            $status = 'Meets Requirement';
            $explanation = "Candidate has {$candidateYears} yrs which satisfies required {$requiredYears} yrs.";
        } else {
            $ratio = $candidateYears / $requiredYears;
            $score = max(round($ratio * 100, 1), 30.0);
            $status = 'Partially Matches';
            $explanation = "Candidate has {$candidateYears} yrs of {$requiredYears} required yrs.";
        }

        return [
            'score' => (float)$score,
            'status' => $status,
            'explanation' => $explanation,
        ];
    }

    private function analyzeLocation(JobSeekerProfile $profile, Job $job): array
    {
        $cLoc = strtolower(trim($profile->location ?? ''));
        $jLoc = strtolower(trim($job->location ?? ''));

        if (empty($cLoc) || empty($jLoc)) {
            return ['score' => 80.0];
        }

        if ($cLoc === $jLoc || str_contains($cLoc, $jLoc) || str_contains($jLoc, $cLoc) || str_contains($jLoc, 'remote')) {
            return ['score' => 100.0];
        }

        return ['score' => 40.0];
    }

    /**
     * Employment type synonyms used to normalize free-form strings before comparing
     * the candidate's work history with the job's employment_type requirement.
     */
    private const EMPLOYMENT_TYPE_SYNONYMS = [
        'full_time' => ['full_time', 'fulltime', 'full-time', 'permanent', 'full time'],
        'part_time' => ['part_time', 'parttime', 'part-time', 'part time'],
        'contract' => ['contract', 'contractor', 'freelance', 'freelancer', 'consultant'],
        'internship' => ['internship', 'intern', 'trainee', 'graduate_trainee'],
        'temporary' => ['temporary', 'temp', 'seasonal', 'casual'],
    ];

    private function analyzeEmploymentType(JobSeekerProfile $profile, Job $job): array
    {
        $jobType = $this->normalizeEmploymentType((string) ($job->employment_type ?? ''));

        if ($jobType === null) {
            return [
                'score' => 80.0,
                'status' => 'Not Specified',
                'explanation' => 'No employment type mandated by this job.',
            ];
        }

        // Derive the candidate's familiar employment types from their work history.
        $experiencedTypes = $profile->workExperiences
            ->pluck('employment_type')
            ->filter()
            ->map(fn ($type) => $this->normalizeEmploymentType((string) $type))
            ->filter()
            ->unique()
            ->values();

        if ($experiencedTypes->isEmpty()) {
            // No history signal at all: neutral-ish default so the factor neither
            // fully rewards nor punishes the candidate.
            return [
                'score' => 70.0,
                'status' => 'Not Specified',
                'explanation' => "Candidate work history does not indicate employment types; job expects '{$jobType}'.",
            ];
        }

        if ($experiencedTypes->contains($jobType)) {
            return [
                'score' => 100.0,
                'status' => 'Meets Requirement',
                'explanation' => "Candidate has worked in '{$jobType}' roles previously.",
            ];
        }

        // Related-but-different arrangements earn partial credit (e.g. intern who
        // now applies to full-time, or contractor applying to permanent).
        $partialPairs = [
            'full_time' => ['contract', 'part_time'],
            'part_time' => ['full_time', 'temporary'],
            'contract' => ['full_time', 'temporary'],
            'internship' => ['temporary'],
            'temporary' => ['part_time', 'internship'],
        ];

        if (in_array($jobType, $partialPairs[$jobType] ?? [], true) && $experiencedTypes->intersect($partialPairs[$jobType])->isNotEmpty()) {
            return [
                'score' => 60.0,
                'status' => 'Partially Matches',
                'explanation' => "Candidate has related '{$experiencedTypes->implode(', ')}' experience but no '{$jobType}' history.",
            ];
        }

        return [
            'score' => 30.0,
            'status' => 'Does Not Match',
            'explanation' => "Candidate has only '{$experiencedTypes->implode(', ')}' experience while the job expects '{$jobType}'.",
        ];
    }

    /**
     * Normalize a free-form employment type label into a canonical key.
     */
    private function normalizeEmploymentType(string $type): ?string
    {
        $value = strtolower(trim($type));
        if ($value === '') {
            return null;
        }

        foreach (self::EMPLOYMENT_TYPE_SYNONYMS as $canonical => $variants) {
            if (in_array($value, $variants, true)) {
                return $canonical;
            }
        }

        return $value;
    }

    private function analyzeOtherRequirements(JobSeekerProfile $profile, Job $job): array
    {
        $hasBio = !empty($profile->biography);
        $hasEdu = $profile->educationRecords->isNotEmpty();
        $hasExp = $profile->workExperiences->isNotEmpty();

        $score = 50.0;
        if ($hasBio) $score += 20.0;
        if ($hasEdu) $score += 15.0;
        if ($hasExp) $score += 15.0;

        return [
            'score' => min($score, 100.0),
            'explanation' => 'Profile completeness and supporting qualifications analyzed.',
        ];
    }

    private function generateSummaryExplanation(float $score, array $skills, array $edu, array $exp): string
    {
        $parts = [];
        $parts[] = "Match Score: {$score}%";
        if (!empty($skills['matching_skills'])) {
            $parts[] = "Matching skills: " . implode(', ', array_slice($skills['matching_skills'], 0, 4));
        }
        if (!empty($skills['missing_preferred_skills'])) {
            $parts[] = "Missing preferred skills: " . implode(', ', array_slice($skills['missing_preferred_skills'], 0, 3));
        }
        $parts[] = "Education: " . $edu['status'];
        $parts[] = "Experience: " . $exp['status'];

        return implode(". ", $parts);
    }
}
