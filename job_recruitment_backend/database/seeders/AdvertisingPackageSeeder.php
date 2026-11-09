<?php

namespace Database\Seeders;

use App\Models\AdvertisingPackage;
use Illuminate\Database\Seeder;

class AdvertisingPackageSeeder extends Seeder
{
    public function run(): void
    {
        $packages = [
            [
                'name' => 'Basic Campaign',
                'slug' => 'basic-campaign',
                'description' => 'Ideal for single job promotions and local hiring with standard exposure.',
                'duration_days' => 7,
                'price_etb' => 1500.00,
                'allowed_placements' => ['job_list', 'sidebar'],
                'allowed_categories' => ['featured_jobs', 'sponsored_vacancies'],
                'benefits' => [
                    '7 Days high-visibility listing',
                    'Standard search placement boost',
                    'Dedicated applicant tracking link',
                    'Basic click and impression performance metrics',
                ],
                'badge_label' => 'Starter',
                'is_active' => true,
                'priority_level' => 1,
            ],
            [
                'name' => 'Standard Package',
                'slug' => 'standard-package',
                'description' => 'Expanded reach across dashboards and categorized job feeds for 15 days.',
                'duration_days' => 15,
                'price_etb' => 3500.00,
                'allowed_placements' => ['dashboard', 'job_list', 'sidebar'],
                'allowed_categories' => ['featured_jobs', 'company_promotions', 'sponsored_vacancies'],
                'benefits' => [
                    '15 Days active campaign duration',
                    'Employer & Candidate Dashboard prominent placement',
                    'Targeted skill & category recommendation inclusion',
                    'Real-time CTR and reach telemetry',
                    'Priority in applicant matching radar',
                ],
                'badge_label' => 'Popular',
                'is_active' => true,
                'priority_level' => 2,
            ],
            [
                'name' => 'Premium Brand & Vacancy',
                'slug' => 'premium-brand-vacancy',
                'description' => 'Maximum visibility with Homepage Hero banner and top-tier placement for a full month.',
                'duration_days' => 30,
                'price_etb' => 7000.00,
                'allowed_placements' => ['hero', 'dashboard', 'job_list', 'sidebar', 'search_sponsored'],
                'allowed_categories' => ['featured_jobs', 'company_promotions', 'recruitment_campaigns', 'sponsored_vacancies', 'announcements'],
                'benefits' => [
                    '30 Days prime top-of-feed & hero billboard positioning',
                    'Homepage Hero Carousel prominent rotation',
                    'All placements unlocked across platforms',
                    'Custom brand banner & Amharic bilingual promotion',
                    'Full conversion and candidate attribution reports',
                    'Verified Employer promotion badge',
                ],
                'badge_label' => 'Best Value',
                'is_active' => true,
                'priority_level' => 3,
            ],
            [
                'name' => 'Featured Job Spotlight',
                'slug' => 'featured-job-spotlight',
                'description' => 'Tailored exclusively for fast hiring needs with gold highlight badge on search & vacancies.',
                'duration_days' => 15,
                'price_etb' => 2800.00,
                'allowed_placements' => ['hero', 'job_list', 'search_sponsored'],
                'allowed_categories' => ['featured_jobs', 'sponsored_vacancies'],
                'benefits' => [
                    '15 Days dedicated job vacancy spotlight',
                    'Gold "Featured Vacancy" badge on job cards',
                    'Top-ranked position on search results',
                    'Instant alert notification dispatched to matching candidates',
                    'Accelerated applicant intake',
                ],
                'badge_label' => 'Fast Hire',
                'is_active' => true,
                'priority_level' => 2,
            ],
            [
                'name' => 'Enterprise Custom Campaign',
                'slug' => 'enterprise-custom-campaign',
                'description' => 'Comprehensive multi-vacancy package with 60 days duration, subcity radar targeting, and VIP support.',
                'duration_days' => 60,
                'price_etb' => 15000.00,
                'allowed_placements' => ['hero', 'dashboard', 'job_list', 'sidebar', 'search_sponsored', 'category_specific'],
                'allowed_categories' => ['featured_jobs', 'company_promotions', 'recruitment_campaigns', 'sponsored_vacancies', 'announcements'],
                'benefits' => [
                    '60 Days maximum campaign visibility',
                    'Multi-vacancy bundle & Company brand takeover',
                    'All placements across mobile and web platforms',
                    'Dedicated campaign performance consultation',
                    'Custom geographic subcity radar targeting',
                    'Priority administrative review queue',
                ],
                'badge_label' => 'Enterprise',
                'is_active' => true,
                'priority_level' => 4,
            ],
        ];

        foreach ($packages as $pkg) {
            AdvertisingPackage::updateOrCreate(
                ['slug' => $pkg['slug']],
                $pkg
            );
        }
    }
}
