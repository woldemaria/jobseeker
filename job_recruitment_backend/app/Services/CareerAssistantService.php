<?php

namespace App\Services;

use App\Models\Job;
use App\Models\Skill;
use App\Models\User;

class CareerAssistantService
{
    /**
     * Ask a career-related question with bilingual support (English & Amharic).
     */
    public function askCareerQuestion(string $question, ?User $user = null, string $locale = 'en'): array
    {
        $profile = $user?->jobSeekerProfile;
        $userSkills = $profile ? $profile->skills()->pluck('skills.name')->toArray() : [];
        $userTitle = $profile?->professional_title ?? 'Job Seeker';
        $userExp = $profile?->years_of_experience ?? 0;

        $qLower = strtolower($question);
        $isAmharic = $locale === 'am' || preg_match('/[\x{1200}-\x{137F}]/u', $question);

        $category = 'general_career';
        $answerEn = '';
        $answerAm = '';
        $actionSteps = [];

        if (preg_match('/(cv|resume|curriculum\s*vitae|መረጃ)/iu', $qLower)) {
            $category = 'cv_advice';
            $answerEn = "To craft an outstanding CV in the Ethiopian market: 1) Structure your professional summary around your key achievements; 2) Quantify your impact (e.g. 'Improved efficiency by 20%'); 3) Explicitly list in-demand technical tools like Laravel, Flutter, SQL, or Accounting standards; 4) Ensure your contact details and LinkedIn/GitHub are updated.";
            $answerAm = "ውጤታማ የሥራ ማመልከቻ CV ለማዘጋጀት፡ 1) የሙያ ማጠቃለያዎን በዋና ዋና ስኬቶችዎ ላይ ያተኩሩ፤ 2) የስራ ውጤቶችን በቁጥር ያስደግፉ፤ 3) ተፈላጊ የቴክኒክና የሙያ ክህሎቶችን በግልጽ ይዘርዝሩ፤ 4) የስልክ አድራሻ እና የኢሜል መረጃዎ ትክክለኛ መሆኑን ያረጋግጡ።";
            $actionSteps = [
                'Keep CV concise: 1 to 2 pages maximum.',
                'Match your skills section directly with the job vacancy requirements.',
                'Use clear action verbs: Developed, Directed, Coordinated, Optimized.',
            ];
        } elseif (preg_match('/(interview|ቃለ[\s\-]*መጠይቅ|ጥያቄ)/iu', $qLower)) {
            $category = 'interview_prep';
            $answerEn = "For interview excellence: 1) Research the organization's mission and ongoing Ethiopian initiatives; 2) Master the STAR technique (Situation, Task, Action, Result) for behavioral questions; 3) Prepare 2-3 thoughtful questions to ask the recruiter; 4) Review your technical portfolio.";
            $answerAm = "ለቃለ-መጠይቅ ዝግጅት፡ 1) ስለ ድርጅቱ የስራ ዘርፍ እና ተልዕኮ አስቀድመው ይወቁ፤ 2) ለሚጠየቁት የባህሪ ጥያቄዎች በ STAR ስልት (ሁኔታ፣ ተግባር፣ እርምጃ፣ ውጤት) መልስ ይስጡ፤ 3) ለቃለ-መጠይቅ አድራጊው የሚጠይቋቸውን 2-3 ጠቃሚ ጥያቄዎች ያዘጋጁ።";
            $actionSteps = [
                'Practice your 60-second elevator pitch.',
                'Prepare concrete examples of overcoming technical or workplace challenges.',
                'Dress professionally and arrive 15 minutes before the scheduled time.',
            ];
        } elseif (preg_match('/(fresh\s*graduate|entry\s*level|ተመራቂ|ጀማሪ)/iu', $qLower)) {
            $category = 'fresh_graduate';
            $answerEn = "As a fresh graduate: Highlight academic projects, university leadership, thesis research, and internship experience. Even without decades of experience, demonstrating quick adaptability, verified skill badges, and problem-solving initiative puts you ahead.";
            $answerAm = "ለአዲስ ተመራቂዎች፡ የዩኒቨርሲቲ ፕሮጀክቶችን፣ የተግባር ልምምድ (Internship) እና የተረጋገጡ የክህሎት ማስረጃዎችን አጉልተው ያሳዩ። ተነሳሽነት፣ ለመማር ዝግጁ መሆን እና ጠንካራ የስራ ስነ-ምግባር ለቀጣሪዎች ቁልፍ መስፈርቶች ናቸው።";
            $actionSteps = [
                'Take skill verification quizzes on the platform to earn verified badges.',
                'Apply for graduate trainee, entry-level, and internship listings.',
                'Participate in professional career chat groups to network with peers.',
            ];
        } elseif (preg_match('/(salary|negotiat|ደመወዝ)/iu', $qLower)) {
            $category = 'salary_advice';
            $answerEn = "When negotiating salary in Ethiopia: Research market benchmarks using the platform salary radar. Base your expectations on the role complexity, experience level, and cost of living. Provide a realistic range rather than a fixed number.";
            $answerAm = "የደመወዝ ድርድር ሲያደርጉ፡ በመድረኩ ላይ ያለውን የደመወዝ መረጃ ይጠቀሙ። የሚጠይቁትን ክፍያ በሙያ ልምድዎ እና በስራው ሃላፊነት ላይ ተመስርተው የወሰነ ቁጥር ሳይሆን የመነሻ እና መድረሻ ክልል (Range) ይግለጹ።";
            $actionSteps = [
                'Consult the platform Salary Benchmarks radar for standard market rates.',
                'Consider full benefits (transport allowance, medical insurance, bonus).',
            ];
        } else {
            $answerEn = "Career growth requires continuous learning and strategic positioning. Based on your profile as '{$userTitle}', we recommend targeting roles that build on your core competencies while expanding into high-demand complementary skills.";
            $answerAm = "የተሳካ የስራ ጉዞ ቀጣይነት ያለው ትምህርትን እና ትክክለኛ እቅድን ይጠይቃል። በሙያዎ የበለጠ ስኬታማ ለመሆን ዋና ክህሎቶችዎን እያዳበሩ ተጨማሪ ተፈላጊ ቴክኖሎጂዎችንና ሙያዎችን ይማሩ።";
            $actionSteps = [
                'Review your Skill-Gap analysis on targeted job vacancies.',
                'Set custom job alerts for new opportunities in your preferred city.',
                'Engage with employer postings and practice mock interviews.',
            ];
        }

        return [
            'question' => $question,
            'category' => $category,
            'locale' => $isAmharic ? 'am' : 'en',
            'reply' => $isAmharic ? $answerAm : $answerEn,
            'action_steps' => $actionSteps,
            'user_context' => [
                'title' => $userTitle,
                'skills' => $userSkills,
                'years_of_experience' => $userExp,
            ],
        ];
    }

    /**
     * Generate a tailored professional cover letter draft (Section 8.4).
     */
    public function generateCoverLetter(int $jobId, User $user, string $tone = 'professional', ?string $customNotes = null): array
    {
        $job = Job::with(['employer', 'skills'])->findOrFail($jobId);
        $profile = $user->jobSeekerProfile;
        $fullName = $user->name;
        $title = $profile?->professional_title ?? 'Qualified Professional';
        $location = $profile?->current_location ?? 'Addis Ababa, Ethiopia';
        $company = $job->employer?->organization_name ?? 'Hiring Team';

        $candidateSkills = $profile ? $profile->skills()->pluck('skills.name')->toArray() : [];
        $skillsMention = !empty($candidateSkills) ? implode(', ', array_slice($candidateSkills, 0, 4)) : 'software engineering and organizational expertise';

        $date = now()->format('F d, Y');

        $opening = match ($tone) {
            'enthusiastic' => "I am thrilled to submit my application for the {$job->title} position at {$company}. With an energetic commitment to driving excellence and my foundation in {$skillsMention}, I am eager to contribute immediately to your team.",
            'confident' => "With a proven track record as a {$title} and solid competence in {$skillsMention}, I am writing to express my strong candidacy for the {$job->title} role at {$company}.",
            default => "I am writing to formally express my interest in the {$job->title} position currently open at {$company}. Having reviewed your posted requirements, I believe my qualifications and background in {$skillsMention} make me a compelling match for your team.",
        };

        $bodyParagraph = "Throughout my professional journey, I have developed a disciplined approach to solving complex problems and collaborating across teams. Your vacancy emphasizes '{$job->title}', which closely matches my core capabilities in {$skillsMention}. I pride myself on maintaining high standards of integrity, continuous learning, and adaptability within the Ethiopian fast-paced market.";

        if (!empty($customNotes)) {
            $bodyParagraph .= " Additionally, " . rtrim($customNotes, '.') . ".";
        }

        $closing = "I welcome the opportunity to discuss how my skill set and dedication can deliver measurable value to {$company}. Thank you for your time, consideration, and review of my application.";

        $fullLetter = "{$fullName}\n{$location} • {$user->email}\n{$date}\n\nTo the Hiring Manager,\n{$company}\nRegarding: Application for {$job->title}\n\nDear Hiring Team,\n\n{$opening}\n\n{$bodyParagraph}\n\n{$closing}\n\nSincerely,\n{$fullName}";

        return [
            'job_id' => $job->id,
            'job_title' => $job->title,
            'company_name' => $company,
            'tone' => $tone,
            'generated_letter' => $fullLetter,
            'candidate_skills_highlighted' => array_slice($candidateSkills, 0, 4),
        ];
    }

    /**
     * Generate role-tailored interview practice questions and sample answers (Section 8.5 - 8.7).
     */
    public function generateInterviewPractice(int $jobId, ?string $roleTitle = null): array
    {
        $job = Job::with(['skills', 'employer'])->find($jobId);
        $title = $job?->title ?? $roleTitle ?? 'Software Engineer';
        $company = $job?->employer?->organization_name ?? 'Target Company';

        $questions = [
            [
                'type' => 'Behavioral (STAR Method)',
                'question' => "Tell me about a challenging situation you encountered while working on a project, and how you resolved it.",
                'model_answer' => "Situation: On a critical sprint deadline, we discovered an unexpected API latency bottleneck. Task: My responsibility was to diagnose the issue without delaying the release. Action: I used profiling tools to identify N+1 database queries, refactored the ORM query, and implemented Redis caching. Result: System latency dropped by 65%, and the project deployed successfully on schedule.",
                'eval_tip' => "Focus 10% on the situation, 20% on your task, 50% on your specific actions, and 20% on the measurable outcome.",
            ],
            [
                'type' => 'Role & Technical Competence',
                'question' => "How do your technical qualifications and experience align with the core demands of the {$title} role at {$company}?",
                'model_answer' => "My background has prepared me directly for this position. I have focused on building robust, maintainable solutions adhering to industry best practices. I stay ahead of emerging methodologies, which enables me to hit the ground running and add immediate value.",
                'eval_tip' => "Directly link 2-3 specific requirements from the job description to concrete milestones from your past projects.",
            ],
            [
                'type' => 'Situational & Problem Solving',
                'question' => "If assigned a task with ambiguous requirements and a tight deadline, how would you approach it?",
                'model_answer' => "I would first proactively seek 10 minutes of clarity with the product manager or lead. Simultaneously, I would outline an iterative MVP with assumptions explicitly documented, ensuring we build the right foundation without paralyzing progress.",
                'eval_tip' => "Employers look for candidates who balance autonomy with proactive communication.",
            ],
            [
                'type' => 'Culture & Professional Motivation',
                'question' => "Why are you interested in joining {$company} specifically?",
                'model_answer' => "I have been following {$company}'s growth and impactful solutions in the Ethiopian market. Your focus on quality, ethical standards, and innovation matches my personal career philosophy, making this an ideal environment for long-term contribution.",
                'eval_tip' => "Mention a specific milestone or project the company is known for to demonstrate genuine interest.",
            ],
        ];

        return [
            'job_id' => $jobId,
            'role_title' => $title,
            'company' => $company,
            'questions' => $questions,
            'interview_golden_rules' => [
                'Always use the STAR structure (Situation, Task, Action, Result).',
                'Quantify your results with percentages, timelines, or monetary savings.',
                'Have 3 strategic questions prepared to ask the interviewer at the end.',
            ],
        ];
    }

    /**
     * Deep skill-gap analysis comparing seeker's skills to job requirements (Section 14.2 & 19).
     */
    public function analyzeSkillGap(int $jobId, User $user): array
    {
        $job = Job::with(['skills', 'employer', 'category'])->findOrFail($jobId);
        $profile = $user->jobSeekerProfile;

        $candidateSkills = $profile ? $profile->skills()->pluck('skills.name', 'skills.id')->toArray() : [];
        $candidateSkillNamesLower = array_map('strtolower', array_values($candidateSkills));

        $jobSkills = $job->skills;

        $matchedSkills = [];
        $missingRequiredSkills = [];
        $missingPreferredSkills = [];

        foreach ($jobSkills as $js) {
            $skillName = $js->name;
            $importance = $js->pivot->importance ?? 'required';

            if (in_array(strtolower($skillName), $candidateSkillNamesLower)) {
                $matchedSkills[] = [
                    'id' => $js->id,
                    'name' => $skillName,
                    'importance' => $importance,
                    'status' => 'matched',
                ];
            } else {
                if ($importance === 'preferred') {
                    $missingPreferredSkills[] = [
                        'id' => $js->id,
                        'name' => $skillName,
                        'importance' => $importance,
                        'status' => 'missing',
                    ];
                } else {
                    $missingRequiredSkills[] = [
                        'id' => $js->id,
                        'name' => $skillName,
                        'importance' => $importance,
                        'status' => 'missing',
                    ];
                }
            }
        }

        $totalSkillsCount = $jobSkills->count();
        $matchScore = $totalSkillsCount > 0
            ? round((count($matchedSkills) / $totalSkillsCount) * 100)
            : 85;

        // Suggested learning roadmaps based on missing skills
        $recommendedCourses = [];
        foreach (array_merge($missingRequiredSkills, $missingPreferredSkills) as $missing) {
            $recommendedCourses[] = [
                'skill' => $missing['name'],
                'course_title' => "Mastering {$missing['name']} for Professional Practice",
                'platform' => 'Coursera / edX / Local Ethiopian Tech Academy',
                'duration' => '3 - 6 Weeks',
                'level' => 'Intermediate to Advanced',
            ];
        }

        return [
            'job_id' => $job->id,
            'job_title' => $job->title,
            'employer_name' => $job->employer?->organization_name,
            'match_score' => $matchScore,
            'total_skills_required' => $totalSkillsCount,
            'matched_skills' => $matchedSkills,
            'missing_required_skills' => $missingRequiredSkills,
            'missing_preferred_skills' => $missingPreferredSkills,
            'recommended_courses' => array_slice($recommendedCourses, 0, 5),
            'actionable_advice' => count($missingRequiredSkills) === 0
                ? "You match all critical requirements for this role! Highlight your practical experience in your cover letter."
                : "You have " . count($missingRequiredSkills) . " missing skill(s). We recommend taking the suggested short courses or building a project to demonstrate proficiency.",
        ];
    }
}
