<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('advertisements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employer_id')->nullable()->constrained('employers')->nullOnDelete();
            $table->foreignId('job_id')->nullable()->constrained('jobs')->nullOnDelete();
            $table->foreignId('created_by')->constrained('users')->onDelete('cascade');
            $table->string('title', 200);
            $table->string('title_am', 200)->nullable();
            $table->string('subtitle', 300)->nullable();
            $table->string('subtitle_am', 300)->nullable();
            $table->string('badge_text', 50)->nullable();
            $table->string('badge_text_am', 50)->nullable();
            $table->text('image_url');
            $table->string('category', 50); // featured_jobs, company_promotions, recruitment_campaigns, sponsored_vacancies, announcements
            $table->string('placement', 50); // hero, dashboard, job_list, category_specific
            $table->string('target_role', 30)->default('all'); // all, job_seeker, employer
            $table->json('target_skills')->nullable();
            $table->string('target_category', 100)->nullable();
            $table->string('cta_type', 50); // apply_now, view_details, explore_jobs, register, visit_company, external_link
            $table->string('cta_text', 60);
            $table->string('cta_text_am', 60)->nullable();
            $table->text('cta_target'); // Route or URL
            $table->string('background_color', 30)->default('#0D6B4F');
            $table->string('status', 30)->default('active'); // active, scheduled, paused, expired, pending_approval
            $table->integer('priority')->default(0);
            $table->dateTime('start_date');
            $table->dateTime('end_date');
            $table->unsignedBigInteger('impressions_count')->default(0);
            $table->unsignedBigInteger('clicks_count')->default(0);
            $table->timestamps();
        });

        Schema::create('advertisement_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('advertisement_id')->constrained('advertisements')->onDelete('cascade');
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('event_type', 30); // impression, click
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->timestamp('created_at')->useCurrent();
        });
    }

    public function down(): void {
        Schema::dropIfExists('advertisement_events');
        Schema::dropIfExists('advertisements');
    }
};
