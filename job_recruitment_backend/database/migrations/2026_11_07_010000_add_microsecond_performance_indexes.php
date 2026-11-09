<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations for microsecond-tier query performance.
     */
    public function up(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->index(['status', 'category_id'], 'idx_jobs_status_cat');
            $table->index(['status', 'job_title_id'], 'idx_jobs_status_title');
            $table->index(['status', 'published_at'], 'idx_jobs_status_pub');
        });

        Schema::table('applications', function (Blueprint $table) {
            $applicantCol = Schema::hasColumn('applications', 'user_id') ? 'user_id' : 'profile_id';
            $table->index([$applicantCol, 'status'], 'idx_apps_user_status');
            $table->index(['job_id', 'status'], 'idx_apps_job_status');
        });

        Schema::table('saved_jobs', function (Blueprint $table) {
            $table->index(['user_id'], 'idx_saved_jobs_user');
        });

        Schema::table('advertisements', function (Blueprint $table) {
            $table->index(['status', 'placement', 'priority'], 'idx_ads_status_place_priority');
        });

        Schema::table('job_seeker_profiles', function (Blueprint $table) {
            $table->index(['preferred_category_id'], 'idx_profile_pref_cat');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->dropIndex('idx_jobs_status_cat');
            $table->dropIndex('idx_jobs_status_title');
            $table->dropIndex('idx_jobs_status_pub');
        });

        Schema::table('applications', function (Blueprint $table) {
            $table->dropIndex('idx_apps_user_status');
            $table->dropIndex('idx_apps_job_status');
        });

        Schema::table('saved_jobs', function (Blueprint $table) {
            $table->dropIndex('idx_saved_jobs_user');
        });

        Schema::table('advertisements', function (Blueprint $table) {
            $table->dropIndex('idx_ads_status_place_priority');
        });

        Schema::table('job_seeker_profiles', function (Blueprint $table) {
            $table->dropIndex('idx_profile_pref_cat');
        });
    }
};
