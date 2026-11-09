<?php

namespace Database\Seeders;

use App\Models\Advertisement;
use App\Models\AdvertisementEvent;
use App\Models\Employer;
use App\Models\Job;
use App\Models\User;
use Illuminate\Database\Seeder;

class AdvertisementSeeder extends Seeder
{
    public function run(): void
    {
        $admin = User::whereHas('roles', fn($q) => $q->where('name', 'administrator'))->first()
            ?? User::first();
        $employer = Employer::first();
        $job = Job::first();

        if (!$admin) return;

        $campaigns = [
            [
                'title' => 'Ethiopian Airlines Aviation & Tech Talent Drive 2026',
                'title_am' => 'የኢትዮጵያ አየር መንገድ የአቪዬሽን እና ቴክኖሎጂ የቅጥር ዘመቻ',
                'subtitle' => 'Join Africa\'s leading airline across engineering, cloud infrastructure, and enterprise mobile systems.',
                'subtitle_am' => 'በምህንድስና፣ ክላውድ እና ኢንተርፕራይዝ ሲስተሞች የአፍሪካ ቀዳሚ አየር መንገድን ይቀላቀሉ።',
                'badge_text' => 'SPONSORED CAMPAIGN',
                'badge_text_am' => 'ስፖንሰር የተደረገ ዘመቻ',
                'image_url' => 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=1200&q=80',
                'category' => 'recruitment_campaigns',
                'placement' => 'hero',
                'target_role' => 'all',
                'target_skills' => [1, 3, 5],
                'target_category' => 'Technology & Aviation',
                'cta_type' => 'explore_jobs',
                'cta_text' => 'Explore Positions',
                'cta_text_am' => 'ክፍት የስራ መደቦችን ይመልከቱ',
                'cta_target' => '/jobs',
                'background_color' => '#064E3B',
                'status' => 'active',
                'approval_status' => 'approved',
                'payment_status' => 'paid',
                'approved_by' => $admin->id,
                'approved_at' => now()->subDays(5),
                'priority' => 10,
                'start_date' => now()->subDays(5),
                'end_date' => now()->addDays(60),
                'impressions_count' => 142,
                'clicks_count' => 28,
                'created_by' => $admin->id,
                'employer_id' => $employer?->id,
                'job_id' => $job?->id,
            ],
            [
                'title' => 'CBE Digital Banking & Mobile Core Developer Roles',
                'title_am' => 'የኢትዮጵያ ንግድ ባንክ የዲጂታል ባንኪንግ ክፍት የስራ መደቦች',
                'subtitle' => 'Accelerate financial inclusion with Ethiopia\'s premier commercial banking network.',
                'subtitle_am' => 'ከኢትዮጵያ ቀዳሚ የንግድ ባንክ ጋር የዲጂታል ክፍያዎችን እና የባንክ አገልግሎትን ያሳድጉ።',
                'badge_text' => 'FEATURED EMPLOYER',
                'badge_text_am' => 'ተለይቶ የቀረበ አሰሪ',
                'image_url' => 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1200&q=80',
                'category' => 'featured_jobs',
                'placement' => 'hero',
                'target_role' => 'job_seeker',
                'target_skills' => [1, 2, 8],
                'target_category' => 'Banking & Finance',
                'cta_type' => 'view_details',
                'cta_text' => 'View FinTech Vacancies',
                'cta_text_am' => 'የስራ ዝርዝር ይመልከቱ',
                'cta_target' => '/jobs',
                'background_color' => '#0D6B4F',
                'status' => 'active',
                'priority' => 8,
                'start_date' => now()->subDays(3),
                'end_date' => now()->addDays(45),
                'impressions_count' => 98,
                'clicks_count' => 19,
                'created_by' => $admin->id,
                'employer_id' => $employer?->id,
                'job_id' => $job?->id,
            ],
            [
                'title' => 'Telebirr & Enterprise Cloud Acceleration Initiative',
                'title_am' => 'ቴሌብር እና የኢንተርፕራይዝ ክላውድ ማስፋፊያ የቅጥር ፕሮግራም',
                'subtitle' => 'Scale nationwide mobile money, high-throughput API gateways, and telecommunications architecture.',
                'subtitle_am' => 'ሀገር አቀፍ የሞባይል ገንዘብ እና የቴሌኮም መዋቅርን ያሳድጉ።',
                'badge_text' => 'EXCLUSIVE CAMPAIGN',
                'badge_text_am' => 'ልዩ ዘመቻ',
                'image_url' => 'https://images.unsplash.com/photo-1551836022-d5d88e9218df?auto=format&fit=crop&w=1200&q=80',
                'category' => 'company_promotions',
                'placement' => 'dashboard',
                'target_role' => 'all',
                'target_skills' => [3, 5, 10],
                'target_category' => 'Telecommunications',
                'cta_type' => 'visit_company',
                'cta_text' => 'Visit Organization',
                'cta_text_am' => 'የድርጅቱን መረጃ ይመልከቱ',
                'cta_target' => 'https://www.ethiotelecom.et',
                'background_color' => '#1E3A8A',
                'status' => 'active',
                'priority' => 6,
                'start_date' => now()->subDays(2),
                'end_date' => now()->addDays(90),
                'impressions_count' => 85,
                'clicks_count' => 14,
                'created_by' => $admin->id,
                'employer_id' => $employer?->id,
                'job_id' => null,
            ],
            [
                'title' => 'Safaricom Ethiopia Tech Graduate Program 2026',
                'title_am' => 'የጀማሪ ሶፍትዌር ምህንድስና እና ኔትወርክ አናሊስት ፕሮግራም',
                'subtitle' => 'Fast-track mentorship, competitive compensation, and hands-on telecommunications engineering.',
                'subtitle_am' => 'ፈጣን የስልጠና እድል፣ ተወዳዳሪ ደመወዝ እና የቀጥታ የቴሌኮም ስራ ልምድ።',
                'badge_text' => 'SPONSORED VACANCY',
                'badge_text_am' => 'ስፖንሰር የተደረገ የስራ መደብ',
                'image_url' => 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&w=1200&q=80',
                'category' => 'sponsored_vacancies',
                'placement' => 'job_list',
                'target_role' => 'job_seeker',
                'target_skills' => [1, 2, 4],
                'target_category' => 'Software Engineering',
                'cta_type' => 'apply_now',
                'cta_text' => 'Apply Now',
                'cta_text_am' => 'አሁን ያመልክቱ',
                'cta_target' => '/jobs/1',
                'background_color' => '#9A3412',
                'status' => 'active',
                'priority' => 5,
                'start_date' => now()->subDay(),
                'end_date' => now()->addDays(30),
                'impressions_count' => 120,
                'clicks_count' => 31,
                'created_by' => $admin->id,
                'employer_id' => $employer?->id,
                'job_id' => $job?->id,
            ],
        ];

        foreach ($campaigns as $data) {
            $data['approval_status'] = $data['approval_status'] ?? 'approved';
            $data['payment_status'] = $data['payment_status'] ?? 'paid';
            $data['approved_by'] = $data['approved_by'] ?? $admin->id;
            $data['approved_at'] = $data['approved_at'] ?? now()->subDays(2);

            $ad = Advertisement::create($data);

            // Seed realistic events
            for ($i = 0; $i < min($data['clicks_count'], 10); $i++) {
                AdvertisementEvent::create([
                    'advertisement_id' => $ad->id,
                    'user_id' => $admin->id,
                    'event_type' => 'click',
                    'ip_address' => '127.0.0.1',
                    'user_agent' => 'Mozilla/5.0 Mobile',
                    'created_at' => now()->subHours($i * 4),
                ]);
            }
        }
    }
}
