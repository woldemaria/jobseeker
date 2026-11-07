<?php

namespace Database\Seeders;

use App\Models\Document;
use App\Models\EducationRecord;
use App\Models\Employer;
use App\Models\EmployerMember;
use App\Models\EmployerVerification;
use App\Models\Job;
use App\Models\JobSeekerProfile;
use App\Models\JobSeekerSkill;
use App\Models\JobSkill;
use App\Models\Notification;
use App\Models\Permission;
use App\Models\Role;
use App\Models\Skill;
use App\Models\User;
use App\Models\WorkExperience;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // 0. Seed Ethiopian Standard Categories and Job Titles
        $this->call(JobTitleCategorySeeder::class);

        // 1. Roles
        $roleJobSeeker = Role::firstOrCreate(
            ['name' => 'job_seeker'],
            ['description' => 'Individual looking for employment']
        );
        $roleEmployer = Role::firstOrCreate(
            ['name' => 'employer'],
            ['description' => 'Organization recruitment user']
        );
        $roleAdmin = Role::firstOrCreate(
            ['name' => 'administrator'],
            ['description' => 'System administrator']
        );

        // 2. Permissions
        $permissions = [
            ['name' => 'manage_users', 'description' => 'Manage user accounts and statuses'],
            ['name' => 'create_jobs', 'description' => 'Create new vacancies'],
            ['name' => 'update_jobs', 'description' => 'Edit vacancies and close vacancies'],
            ['name' => 'review_applications', 'description' => 'Review applicant resumes and update status'],
            ['name' => 'verify_employers', 'description' => 'Review and verify employer organizations'],
            ['name' => 'moderate_jobs', 'description' => 'Moderate job postings'],
            ['name' => 'view_reports', 'description' => 'Review reported vacancies and abuse'],
        ];

        foreach ($permissions as $p) {
            $perm = Permission::firstOrCreate(['name' => $p['name']], ['description' => $p['description']]);
            $roleAdmin->permissions()->syncWithoutDetaching([$perm->id]);
            if (in_array($p['name'], ['create_jobs', 'update_jobs', 'review_applications'])) {
                $roleEmployer->permissions()->syncWithoutDetaching([$perm->id]);
            }
        }

        // 3. Initial Skills from Chapter 10.2
        $skillsData = [
            ['name' => 'Flutter', 'category' => 'Mobile Development'],
            ['name' => 'Dart', 'category' => 'Programming'],
            ['name' => 'Laravel', 'category' => 'Backend Development'],
            ['name' => 'PHP', 'category' => 'Programming'],
            ['name' => 'MySQL', 'category' => 'Database'],
            ['name' => 'Java', 'category' => 'Programming'],
            ['name' => 'Python', 'category' => 'Programming'],
            ['name' => 'REST API', 'category' => 'Backend Development'],
            ['name' => 'Git', 'category' => 'Development Tools'],
            ['name' => 'Communication', 'category' => 'Soft Skills'],
            ['name' => 'Project Management', 'category' => 'Soft Skills'],
            ['name' => 'Problem Solving', 'category' => 'Soft Skills'],
            ['name' => 'Firebase', 'category' => 'Cloud & Backend'],
            ['name' => 'Swift', 'category' => 'Mobile Development'],
            ['name' => 'Kotlin', 'category' => 'Mobile Development'],
        ];

        $skillModels = [];
        foreach ($skillsData as $s) {
            $skillModels[$s['name']] = Skill::firstOrCreate(['name' => $s['name']], $s);
        }

        // 4. Sample Admin User
        $adminUser = User::firstOrCreate(
            ['email' => 'admin@jobrecruitment.et'],
            [
                'name' => 'System Administrator',
                'phone' => '+251911000001',
                'password' => Hash::make('Admin@123456'),
                'status' => 'active',
                'email_verified_at' => now(),
            ]
        );
        $adminUser->roles()->syncWithoutDetaching([$roleAdmin->id]);

        // 5. Sample Employer User & Organization from Chapter 10.3
        $employerUser = User::firstOrCreate(
            ['email' => 'recruitment@example.com'],
            [
                'name' => 'Tech Recruiter',
                'phone' => '+251911223344',
                'password' => Hash::make('Employer@123456'),
                'status' => 'active',
                'email_verified_at' => now(),
            ]
        );
        $employerUser->roles()->syncWithoutDetaching([$roleEmployer->id]);

        $employer = Employer::firstOrCreate(
            ['organization_name' => 'Example Technology Company'],
            [
                'organization_type' => 'Private Company',
                'registration_number' => 'ET-COMP-2026-99',
                'email' => 'recruitment@example.com',
                'phone' => '+251911223344',
                'website' => 'https://example.com',
                'address' => 'Bole Subcity, Addis Ababa, Ethiopia',
                'verification_status' => 'approved',
            ]
        );

        EmployerMember::firstOrCreate(
            [
                'employer_id' => $employer->id,
                'user_id' => $employerUser->id,
            ],
            [
                'member_role' => 'owner',
            ]
        );

        // 6. Sample Job Seeker User
        $jobSeekerUser = User::firstOrCreate(
            ['email' => 'jobseeker@example.com'],
            [
                'name' => 'Abebe Bikila',
                'phone' => '+251911556677',
                'password' => Hash::make('Seeker@123456'),
                'status' => 'active',
                'email_verified_at' => now(),
            ]
        );
        $jobSeekerUser->roles()->syncWithoutDetaching([$roleJobSeeker->id]);

        $profile = JobSeekerProfile::firstOrCreate(
            ['user_id' => $jobSeekerUser->id],
            [
                'date_of_birth' => '1998-05-15',
                'gender' => 'Male',
                'education_level' => 'Bachelor Degree',
                'field_of_study' => 'Computer Science',
                'experience_years' => 2.5,
                'location' => 'Addis Ababa',
                'biography' => 'Passionate software engineer experienced in Flutter and Laravel REST APIs.',
            ]
        );

        // Assign skills to Job Seeker
        if (isset($skillModels['Flutter'])) {
            JobSeekerSkill::firstOrCreate([
                'profile_id' => $profile->id,
                'skill_id' => $skillModels['Flutter']->id,
            ], [
                'proficiency_level' => 'advanced',
                'years_experience' => 2.5,
            ]);
        }
        if (isset($skillModels['Dart'])) {
            JobSeekerSkill::firstOrCreate([
                'profile_id' => $profile->id,
                'skill_id' => $skillModels['Dart']->id,
            ], [
                'proficiency_level' => 'advanced',
                'years_experience' => 2.5,
            ]);
        }
        if (isset($skillModels['REST API'])) {
            JobSeekerSkill::firstOrCreate([
                'profile_id' => $profile->id,
                'skill_id' => $skillModels['REST API']->id,
            ], [
                'proficiency_level' => 'intermediate',
                'years_experience' => 2.0,
            ]);
        }
        if (isset($skillModels['Laravel'])) {
            JobSeekerSkill::firstOrCreate([
                'profile_id' => $profile->id,
                'skill_id' => $skillModels['Laravel']->id,
            ], [
                'proficiency_level' => 'intermediate',
                'years_experience' => 1.5,
            ]);
        }

        // Education
        EducationRecord::firstOrCreate([
            'profile_id' => $profile->id,
            'institution_name' => 'Addis Ababa University',
            'qualification' => 'Bachelor of Science',
            'field_of_study' => 'Computer Science',
            'start_date' => '2019-10-01',
            'end_date' => '2023-07-15',
            'grade' => '3.82',
            'description' => 'Focused on software engineering, database systems, and mobile development.',
        ]);

        // Work experience
        WorkExperience::firstOrCreate([
            'profile_id' => $profile->id,
            'company_name' => 'Fintech Solutions Ethiopia',
            'job_title' => 'Junior Mobile Developer',
            'employment_type' => 'Full-time',
            'start_date' => '2023-08-01',
            'end_date' => '2025-02-28',
            'is_current' => false,
            'description' => 'Built cross-platform Flutter applications integrating banking and payment APIs.',
        ]);

        // Sample CV Document
        $cvDoc = Document::firstOrCreate([
            'user_id' => $jobSeekerUser->id,
            'original_name' => 'Abebe_Bikila_CV.pdf',
        ], [
            'storage_path' => 'documents/sample_cv.pdf',
            'mime_type' => 'application/pdf',
            'file_size' => 124500,
            'document_type' => 'cv',
        ]);

        // 7. Sample Jobs
        $job1 = Job::firstOrCreate([
            'employer_id' => $employer->id,
            'title' => 'Junior Flutter Developer',
        ], [
            'category_id' => 15, // Information Technology
            'category' => 'Information Technology',
            'description' => 'We are seeking a motivated Junior Flutter Developer to build modern Android and iOS mobile applications for Ethiopian enterprises. You will collaborate with our backend team to consume RESTful endpoints.',
            'responsibilities' => "- Develop mobile screens in Flutter.\n- Connect with Laravel REST APIs.\n- Ensure UI responsiveness and clean architecture.",
            'requirements' => "- Degree in Computer Science or related field.\n- Experience with Flutter and Dart.\n- Familiarity with RESTful APIs.",
            'location' => 'Addis Ababa (Bole)',
            'employment_type' => 'Full-time',
            'experience_required' => 2.0,
            'salary_min' => 25000.00,
            'salary_max' => 35000.00,
            'currency' => 'ETB',
            'deadline' => now()->addDays(30)->toDateString(),
            'status' => 'published',
            'published_at' => now(),
        ]);

        // Skills for Job 1
        if (isset($skillModels['Flutter'])) {
            JobSkill::firstOrCreate(['job_id' => $job1->id, 'skill_id' => $skillModels['Flutter']->id], ['importance' => 'required', 'minimum_proficiency' => 'intermediate']);
        }
        if (isset($skillModels['Dart'])) {
            JobSkill::firstOrCreate(['job_id' => $job1->id, 'skill_id' => $skillModels['Dart']->id], ['importance' => 'required', 'minimum_proficiency' => 'intermediate']);
        }
        if (isset($skillModels['REST API'])) {
            JobSkill::firstOrCreate(['job_id' => $job1->id, 'skill_id' => $skillModels['REST API']->id], ['importance' => 'required', 'minimum_proficiency' => 'intermediate']);
        }
        if (isset($skillModels['Firebase'])) {
            JobSkill::firstOrCreate(['job_id' => $job1->id, 'skill_id' => $skillModels['Firebase']->id], ['importance' => 'preferred', 'minimum_proficiency' => 'beginner']);
        }

        $job2 = Job::firstOrCreate([
            'employer_id' => $employer->id,
            'title' => 'Backend Laravel Engineer',
        ], [
            'category_id' => 15, // Information Technology
            'category' => 'Information Technology',
            'description' => 'Looking for a skilled Laravel developer to design secure APIs, optimize MySQL databases, and handle microservices.',
            'responsibilities' => "- Build and document RESTful endpoints.\n- Optimize database queries and schema design.\n- Implement Sanctum token authentication.",
            'requirements' => "- Proven experience with PHP and Laravel.\n- Solid knowledge of MySQL database design.\n- Clean code and unit testing mindset.",
            'location' => 'Addis Ababa (Kirkos)',
            'employment_type' => 'Full-time',
            'experience_required' => 2.0,
            'salary_min' => 30000.00,
            'salary_max' => 45000.00,
            'currency' => 'ETB',
            'deadline' => now()->addDays(20)->toDateString(),
            'status' => 'published',
            'published_at' => now(),
        ]);

        if (isset($skillModels['Laravel'])) {
            JobSkill::firstOrCreate(['job_id' => $job2->id, 'skill_id' => $skillModels['Laravel']->id], ['importance' => 'required', 'minimum_proficiency' => 'intermediate']);
        }
        if (isset($skillModels['PHP'])) {
            JobSkill::firstOrCreate(['job_id' => $job2->id, 'skill_id' => $skillModels['PHP']->id], ['importance' => 'required', 'minimum_proficiency' => 'intermediate']);
        }
        if (isset($skillModels['MySQL'])) {
            JobSkill::firstOrCreate(['job_id' => $job2->id, 'skill_id' => $skillModels['MySQL']->id], ['importance' => 'required', 'minimum_proficiency' => 'intermediate']);
        }

        // Additional Ethiopian Sector Jobs from jobtitle.txt
        $job3 = Job::firstOrCreate([
            'employer_id' => $employer->id,
            'title' => 'Agronomist',
        ], [
            'category_id' => 1, // Agriculture and Farming
            'category' => 'Agriculture and Farming',
            'description' => 'Seeking an experienced Agronomist to lead crop yield optimization, soil testing, and modern irrigation implementation in the Rift Valley agricultural corridor.',
            'responsibilities' => "- Conduct soil and crop analysis.\n- Train farm workers on sustainable cultivation practices.\n- Supervise pest control and fertilizer management.",
            'requirements' => "- BSc in Agronomy, Plant Science, or Agricultural Science.\n- 3+ years field experience in Ethiopia.\n- Strong analytical and communication skills.",
            'location' => 'Hawassa',
            'employment_type' => 'Full-time',
            'experience_required' => 3.0,
            'salary_min' => 22000.00,
            'salary_max' => 38000.00,
            'currency' => 'ETB',
            'deadline' => now()->addDays(40)->toDateString(),
            'status' => 'published',
            'published_at' => now(),
        ]);

        $job4 = Job::firstOrCreate([
            'employer_id' => $employer->id,
            'title' => 'Civil Engineer',
        ], [
            'category_id' => 3, // Construction and Engineering
            'category' => 'Construction and Engineering',
            'description' => 'Experienced Site Civil Engineer required for high-rise commercial construction project in Bole, Addis Ababa. Must oversee structural compliance and materials quality.',
            'responsibilities' => "- Supervise daily site civil construction activities.\n- Coordinate with structural consultants and subcontractors.\n- Ensure compliance with Ethiopian building code standards.",
            'requirements' => "- BSc in Civil Engineering from recognized Ethiopian university.\n- Licensed Practicing Engineer.\n- 4+ years on commercial site projects.",
            'location' => 'Addis Ababa (Bole)',
            'employment_type' => 'Full-time',
            'experience_required' => 4.0,
            'salary_min' => 35000.00,
            'salary_max' => 60000.00,
            'currency' => 'ETB',
            'deadline' => now()->addDays(25)->toDateString(),
            'status' => 'published',
            'published_at' => now(),
        ]);

        $job5 = Job::firstOrCreate([
            'employer_id' => $employer->id,
            'title' => 'Accountant',
        ], [
            'category_id' => 7, // Accounting and Finance
            'category' => 'Accounting and Finance',
            'description' => 'Senior Accountant needed to oversee financial ledger, IFRS compliance, VAT filings, and ERCA tax audits for our expanding enterprise.',
            'responsibilities' => "- Prepare monthly profit and loss reports and balance sheets.\n- Manage Ethiopian tax declarations and payroll.\n- Reconcile commercial bank accounts and cash flow.",
            'requirements' => "- BA in Accounting and Finance.\n- Proficiency with Peachtree or QuickBooks.\n- Deep understanding of Ethiopian tax laws.",
            'location' => 'Addis Ababa (Kirkos)',
            'employment_type' => 'Full-time',
            'experience_required' => 3.0,
            'salary_min' => 24000.00,
            'salary_max' => 42000.00,
            'currency' => 'ETB',
            'deadline' => now()->addDays(15)->toDateString(),
            'status' => 'published',
            'published_at' => now(),
        ]);

        $job6 = Job::firstOrCreate([
            'employer_id' => $employer->id,
            'title' => 'Primary School Teacher',
        ], [
            'category_id' => 5, // Education and Teaching
            'category' => 'Education and Teaching',
            'description' => 'Dedicated Primary School Teacher wanted for an accredited community academy in Adama. Teach English, science, and elementary mathematics.',
            'responsibilities' => "- Plan and conduct engaging classroom lessons.\n- Evaluate student performance and report to parents.\n- Foster positive classroom environment.",
            'requirements' => "- Diploma or Degree in Teaching / Education.\n- Fluency in English and Amharic / Afaan Oromo.\n- 2+ years classroom experience.",
            'location' => 'Adama',
            'employment_type' => 'Full-time',
            'experience_required' => 2.0,
            'salary_min' => 15000.00,
            'salary_max' => 25000.00,
            'currency' => 'ETB',
            'deadline' => now()->addDays(35)->toDateString(),
            'status' => 'published',
            'published_at' => now(),
        ]);

        $job7 = Job::firstOrCreate([
            'employer_id' => $employer->id,
            'title' => 'Logistics Officer',
        ], [
            'category_id' => 12, // Transportation and Logistics
            'category' => 'Transportation and Logistics',
            'description' => 'Coordinate freight transportation, customs clearance at Mojo dry port, and fleet distribution across regional depots in Ethiopia.',
            'responsibilities' => "- Dispatch trucks and coordinate delivery routes.\n- Track shipping containers and handle customs documents.\n- Minimize transit time and reduce transport expenses.",
            'requirements' => "- BA in Logistics, Supply Chain Management, or Management.\n- 3+ years in Ethiopian transport or freight forwarding.\n- Problem-solving under tight deadlines.",
            'location' => 'Addis Ababa (Akaki Kality)',
            'employment_type' => 'Full-time',
            'experience_required' => 3.0,
            'salary_min' => 20000.00,
            'salary_max' => 36000.00,
            'currency' => 'ETB',
            'deadline' => now()->addDays(20)->toDateString(),
            'status' => 'published',
            'published_at' => now(),
        ]);

        // Sample notification
        Notification::firstOrCreate([
            'user_id' => $jobSeekerUser->id,
            'title' => 'Welcome to the Recruitment App',
        ], [
            'message' => 'Your profile is ready. Browse recommended vacancies and apply today.',
            'notification_type' => 'system',
            'is_read' => false,
        ]);

        // Production Advertisements
        $this->call(AdvertisementSeeder::class);

        // Community & Friends Chat Groups
        $group1 = \App\Models\ChatGroup::firstOrCreate(
            ['name' => 'Ethiopian Tech Careers & Opportunities'],
            [
                'description' => 'A community group for professionals and job seekers to share vacancies, exchange advice, and discuss hiring trends in Ethiopia.',
                'created_by' => $adminUser->id,
                'is_private' => false,
            ]
        );
        \App\Models\ChatGroupMember::firstOrCreate(
            ['group_id' => $group1->id, 'user_id' => $adminUser->id],
            ['role' => 'owner', 'joined_at' => now()]
        );
        \App\Models\ChatGroupMember::firstOrCreate(
            ['group_id' => $group1->id, 'user_id' => $jobSeekerUser->id],
            ['role' => 'member', 'joined_at' => now()]
        );
        \App\Models\ChatMessage::firstOrCreate(
            ['group_id' => $group1->id, 'user_id' => $adminUser->id],
            [
                'message' => 'Welcome everyone! Share new job vacancies and interview preparation tips here.',
                'message_type' => 'text',
            ]
        );

        $group2 = \App\Models\ChatGroup::firstOrCreate(
            ['name' => 'Addis Software Developers Network'],
            [
                'description' => 'Networking, tech jobs, and peer discussions for software engineers across Ethiopia.',
                'created_by' => $jobSeekerUser->id,
                'is_private' => false,
            ]
        );
        \App\Models\ChatGroupMember::firstOrCreate(
            ['group_id' => $group2->id, 'user_id' => $jobSeekerUser->id],
            ['role' => 'owner', 'joined_at' => now()]
        );

        // 7. Micro-Skill Assessment Quizzes
        $flutterSkill = Skill::where('name', 'Flutter')->first();
        if ($flutterSkill) {
            $quiz = \App\Models\Quiz::firstOrCreate(
                ['skill_id' => $flutterSkill->id],
                [
                    'title' => 'Flutter & Dart Professional Assessment',
                    'description' => 'Test your knowledge of Flutter widgets, state management, and async Dart.',
                    'passing_score' => 80,
                    'duration_seconds' => 60,
                ]
            );

            $q1 = \App\Models\QuizQuestion::firstOrCreate(
                ['quiz_id' => $quiz->id, 'question_text' => 'What is the primary difference between a StatelessWidget and a StatefulWidget?'],
                ['points' => 20]
            );
            \App\Models\QuizOption::firstOrCreate(['quiz_question_id' => $q1->id, 'option_text' => 'StatefulWidget maintains mutable state across its lifetime.'], ['is_correct' => true]);
            \App\Models\QuizOption::firstOrCreate(['quiz_question_id' => $q1->id, 'option_text' => 'StatelessWidget can rebuild anytime without external changes.'], ['is_correct' => false]);
            \App\Models\QuizOption::firstOrCreate(['quiz_question_id' => $q1->id, 'option_text' => 'StatefulWidget cannot accept constructor parameters.'], ['is_correct' => false]);

            $q2 = \App\Models\QuizQuestion::firstOrCreate(
                ['quiz_id' => $quiz->id, 'question_text' => 'Which keyword in Dart is used to handle asynchronous operations cleanly without callback hell?'],
                ['points' => 20]
            );
            \App\Models\QuizOption::firstOrCreate(['quiz_question_id' => $q2->id, 'option_text' => 'async and await'], ['is_correct' => true]);
            \App\Models\QuizOption::firstOrCreate(['quiz_question_id' => $q2->id, 'option_text' => 'defer and resolve'], ['is_correct' => false]);
            \App\Models\QuizOption::firstOrCreate(['quiz_question_id' => $q2->id, 'option_text' => 'thread.sleep'], ['is_correct' => false]);

            $q3 = \App\Models\QuizQuestion::firstOrCreate(
                ['quiz_id' => $quiz->id, 'question_text' => 'Which method is called only once when a StatefulWidget is first inserted into the widget tree?'],
                ['points' => 20]
            );
            \App\Models\QuizOption::firstOrCreate(['quiz_question_id' => $q3->id, 'option_text' => 'initState()'], ['is_correct' => true]);
            \App\Models\QuizOption::firstOrCreate(['quiz_question_id' => $q3->id, 'option_text' => 'build()'], ['is_correct' => false]);
            \App\Models\QuizOption::firstOrCreate(['quiz_question_id' => $q3->id, 'option_text' => 'dispose()'], ['is_correct' => false]);

            $q4 = \App\Models\QuizQuestion::firstOrCreate(
                ['quiz_id' => $quiz->id, 'question_text' => 'What is the function of the BuildContext parameter in Flutter build methods?'],
                ['points' => 20]
            );
            \App\Models\QuizOption::firstOrCreate(['quiz_question_id' => $q4->id, 'option_text' => 'It represents the location of a widget in the widget tree.'], ['is_correct' => true]);
            \App\Models\QuizOption::firstOrCreate(['quiz_question_id' => $q4->id, 'option_text' => 'It stores the device hardware IP address.'], ['is_correct' => false]);
            \App\Models\QuizOption::firstOrCreate(['quiz_question_id' => $q4->id, 'option_text' => 'It compiles Dart code to machine code.'], ['is_correct' => false]);

            $q5 = \App\Models\QuizQuestion::firstOrCreate(
                ['quiz_id' => $quiz->id, 'question_text' => 'Which widget is used to place child widgets on top of each other like layers?'],
                ['points' => 20]
            );
            \App\Models\QuizOption::firstOrCreate(['quiz_question_id' => $q5->id, 'option_text' => 'Stack'], ['is_correct' => true]);
            \App\Models\QuizOption::firstOrCreate(['quiz_question_id' => $q5->id, 'option_text' => 'Column'], ['is_correct' => false]);
            \App\Models\QuizOption::firstOrCreate(['quiz_question_id' => $q5->id, 'option_text' => 'Row'], ['is_correct' => false]);
        }
    }
}
