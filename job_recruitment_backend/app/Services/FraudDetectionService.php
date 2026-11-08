<?php

namespace App\Services;

use App\Models\Employer;
use App\Models\Job;
use App\Models\Report;

class FraudDetectionService
{
    /**
     * Rule definitions with weights and pattern regexes.
     */
    private const SCAM_KEYWORDS = [
        // Upfront Fees and Payments
        [
            'pattern' => '/\b(upfront|processing|registration|training|interview|placement|documentation|medical\s*exam|visa\s*processing)\s*(fee|charge|deposit|cost|payment|birr|etb|\$)\b/i',
            'score' => 45,
            'indicator' => 'Demands upfront payment, registration, or processing fees',
            'critical' => true,
        ],
        [
            'pattern' => '/\b(send|transfer|wire|pay|deposit)\s+(money|funds|etb|birr|cash|dollars?|usd)\s+(before|prior\s*to|to\s*apply|for\s*processing|guarantee)/i',
            'score' => 45,
            'indicator' => 'Demands advance money transfer before hiring or interview',
            'critical' => true,
        ],
        [
            'pattern' => '/\b(western\s*union|moneygram|gift\s*card|crypto|usdt|bitcoin|check\s*cashing|cashing\s*check|secret\s*shopper|envelope\s*stuffing)\b/i',
            'score' => 40,
            'indicator' => 'Mentions high-risk payment channels or check cashing scams',
            'critical' => true,
        ],

        // Channel Evasion (Redirecting off platform without verification)
        [
            'pattern' => '/\b(apply|contact|message|reach\s*out)\s+(only|strictly|exclusively)?\s*(via|on|through)?\s*telegram\b/i',
            'score' => 25,
            'indicator' => 'Requires application strictly via Telegram without official corporate channels',
            'critical' => false,
        ],
        [
            'pattern' => '/(t\.me\/|telegram\s*:\s*@)/i',
            'score' => 15,
            'indicator' => 'Directs candidates to external personal Telegram handles',
            'critical' => false,
        ],
        [
            'pattern' => '/\b(apply|message)\s+(only|strictly)\s+(via|on)?\s*whatsapp\b/i',
            'score' => 20,
            'indicator' => 'Requires application strictly via personal WhatsApp',
            'critical' => false,
        ],

        // Credential / Identity Harvesting
        [
            'pattern' => '/\b(credit\s*card|debit\s*card|cvv|pin\s*code|bank\s*login|online\s*banking\s*password|bank\s*credentials)\b/i',
            'score' => 50,
            'indicator' => 'Sollicits private banking credentials, PINs, or card details',
            'critical' => true,
        ],
        [
            'pattern' => '/\b(send|upload)\s+(passport|national\s*id|kebele\s*id)\s+(copy|details|photo)\s+(before|prior\s*to)\s+(interview|contact|screening)/i',
            'score' => 25,
            'indicator' => 'Demands immediate identity document copies prior to any legitimate screening',
            'critical' => false,
        ],

        // Unrealistic Guarantees & Exploitative Claims
        [
            'pattern' => '/\b(guaranteed\s*visa|visa\s*sponsorship\s*guaranteed|guaranteed\s*work\s*permit|guaranteed\s*overseas\s*job)\b/i',
            'score' => 30,
            'indicator' => 'Guarantees foreign visas or overseas work permits',
            'critical' => false,
        ],
        [
            'pattern' => '/\b(no\s*experience|zero\s*experience|no\s*skills?\s*needed)\b.{1,40}\b(earn|salary|make)\s*([0-9]{2,}\s*(000|k)|\$?[0-9]{4,})\b/i',
            'score' => 35,
            'indicator' => 'Offers exorbitant salary for no qualifications or experience',
            'critical' => false,
        ],
        [
            'pattern' => '/\b(earn|make)\s+([0-9,]+)\s*(etb|birr|usd|\$)\s*(per\s*day|daily|every\s*day)\b/i',
            'score' => 25,
            'indicator' => 'Promises unrealistic daily cash returns typical of pyramid or task scams',
            'critical' => false,
        ],
        [
            'pattern' => '/\b(instant\s*hire|no\s*interview\s*needed|guaranteed\s*placement\s*today)\b/i',
            'score' => 20,
            'indicator' => 'Claims instant hiring with no standard interview process',
            'critical' => false,
        ],
    ];

    /**
     * Assess a job vacancy / advertisement payload for fraudulent patterns.
     */
    public function assess(
        string $title,
        string $description,
        ?string $requirements = null,
        ?string $responsibilities = null,
        ?float $salaryMax = null,
        ?float $salaryMin = null,
        ?float $experienceRequired = null,
        ?Employer $employer = null,
        int $reportCount = 0
    ): array {
        $content = $title . "\n" . $description . "\n" . ($requirements ?? '') . "\n" . ($responsibilities ?? '');
        $score = 0;
        $indicators = [];
        $isCritical = false;

        // 1. Text & Scam Keyword Matching
        foreach (self::SCAM_KEYWORDS as $rule) {
            if (preg_match($rule['pattern'], $content)) {
                $score += $rule['score'];
                $indicators[] = $rule['indicator'];
                if (!empty($rule['critical'])) {
                    $isCritical = true;
                }
            }
        }

        // 2. Suspicious Exorbitant Salary vs. Experience
        if ($salaryMax !== null && $salaryMax >= 250000 && ($experienceRequired === null || $experienceRequired <= 1.0)) {
            $score += 25;
            $indicators[] = 'Abnormally high salary compensation (>250,000 ETB) for zero/entry-level experience';
        }

        // 3. Ultra-short description with grandiose keywords
        $descLen = strlen(trim($description));
        if ($descLen > 0 && $descLen < 80 && ($score > 0 || stripos($content, 'earn') !== false)) {
            $score += 15;
            $indicators[] = 'Vague, extremely brief description lacking formal job duties';
        }

        // 4. Employer Verification & Credibility Checks
        if ($employer) {
            if ($employer->verification_status !== 'approved') {
                $score += 10;
                $indicators[] = 'Posted by an unverified organization';
            }

            // Free webmail domain check
            if (!empty($employer->email)) {
                $emailDomain = strtolower(substr(strrchr($employer->email, "@"), 1));
                $freeDomains = ['gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 'yandex.com', 'mail.ru'];
                if (in_array($emailDomain, $freeDomains)) {
                    $score += 5;
                    $indicators[] = "Organization uses free public email (@{$emailDomain}) rather than corporate domain";
                }
            }
        }

        // 5. Existing Crowd-Sourced Abuse Reports Weight
        if ($reportCount > 0) {
            $reportBoost = min(50, $reportCount * 20);
            $score += $reportBoost;
            $indicators[] = "Flagged by {$reportCount} community report(s)";
        }

        // Clamp score between 0 and 100
        $score = max(0, min(100, $score));

        // Determine Risk Level
        if ($score >= 80 || ($isCritical && $score >= 60)) {
            $riskLevel = 'critical';
            $recommendedAction = 'auto_quarantine';
        } elseif ($score >= 60) {
            $riskLevel = 'high';
            $recommendedAction = 'flag_for_review';
        } elseif ($score >= 30) {
            $riskLevel = 'medium';
            $recommendedAction = 'warning_badge';
        } else {
            $riskLevel = 'low';
            $recommendedAction = 'allow';
        }

        $isFlagged = ($score >= 60) || ($reportCount >= 2) || $isCritical;

        return [
            'fraud_score' => $score,
            'fraud_risk_level' => $riskLevel,
            'fraud_indicators' => array_values(array_unique($indicators)),
            'is_flagged' => $isFlagged,
            'recommended_action' => $recommendedAction,
            'safety_checklist' => [
                'Never pay money or application fees before receiving a legitimate written contract.',
                'Verify company physical headquarters and commercial registration (TIN/License).',
                'Avoid off-platform informal communications (e.g. personal Telegram bots) for sensitive recruitment.',
                'Report suspicious advertisements directly through the platform flagging system.',
            ],
        ];
    }

    /**
     * Assess an Eloquent Job model.
     */
    public function assessJob(Job $job): array
    {
        $reportCount = Report::where('job_id', $job->id)
            ->where(function ($q) {
                $q->where('reason', 'like', '%fraud%')
                  ->orWhere('reason', 'like', '%scam%')
                  ->orWhere('reason', 'like', '%fee%');
            })
            ->count();

        return $this->assess(
            title: $job->title,
            description: $job->description,
            requirements: $job->requirements,
            responsibilities: $job->responsibilities,
            salaryMax: $job->salary_max !== null ? (float)$job->salary_max : null,
            salaryMin: $job->salary_min !== null ? (float)$job->salary_min : null,
            experienceRequired: $job->experience_required !== null ? (float)$job->experience_required : null,
            employer: $job->employer,
            reportCount: $reportCount
        );
    }

    /**
     * Assess raw request data before creating or updating a Job.
     */
    public function assessJobData(array $data, ?Employer $employer = null): array
    {
        return $this->assess(
            title: $data['title'] ?? '',
            description: $data['description'] ?? '',
            requirements: $data['requirements'] ?? null,
            responsibilities: $data['responsibilities'] ?? null,
            salaryMax: isset($data['salary_max']) ? (float)$data['salary_max'] : null,
            salaryMin: isset($data['salary_min']) ? (float)$data['salary_min'] : null,
            experienceRequired: isset($data['experience_required']) ? (float)$data['experience_required'] : null,
            employer: $employer,
            reportCount: 0
        );
    }

    /**
     * Compute assessment and persist to the Job model.
     */
    public function applyToJob(Job $job): Job
    {
        $assessment = $this->assessJob($job);

        $job->fraud_score = $assessment['fraud_score'];
        $job->fraud_risk_level = $assessment['fraud_risk_level'];
        $job->fraud_indicators = $assessment['fraud_indicators'];
        $job->is_flagged = $assessment['is_flagged'];

        // Automatically change moderation status if critical
        if ($assessment['recommended_action'] === 'auto_quarantine' && $job->moderation_status === 'clean') {
            $job->moderation_status = 'under_review';
            // Unpublish automatically if critically fraudulent to protect job seekers
            if ($job->status === 'published') {
                $job->status = 'draft';
            }
        } elseif ($assessment['is_flagged'] && $job->moderation_status === 'clean') {
            $job->moderation_status = 'flagged';
        }

        $job->save();
        return $job;
    }

    /**
     * Platform-wide fraud scan across all jobs.
     */
    public function scanAllJobs(): array
    {
        $jobs = Job::with('employer')->get();
        $scanned = 0;
        $flagged = 0;
        $quarantined = 0;

        foreach ($jobs as $job) {
            $this->applyToJob($job);
            $scanned++;
            if ($job->is_flagged) {
                $flagged++;
            }
            if ($job->moderation_status === 'under_review' || $job->moderation_status === 'fraudulent') {
                $quarantined++;
            }
        }

        return [
            'total_scanned' => $scanned,
            'flagged_count' => $flagged,
            'quarantined_count' => $quarantined,
            'scanned_at' => now()->toIso8601String(),
        ];
    }
}
