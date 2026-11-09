<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        if (!Schema::hasTable('advertising_packages')) {
            Schema::create('advertising_packages', function (Blueprint $table) {
                $table->id();
                $table->string('name', 100);
                $table->string('slug', 100)->unique();
                $table->text('description')->nullable();
                $table->integer('duration_days')->default(7);
                $table->decimal('price_etb', 12, 2)->default(0.00);
                $table->json('allowed_placements')->nullable(); // hero, dashboard, job_list, sidebar, search_sponsored
                $table->json('allowed_categories')->nullable(); // featured_jobs, company_promotions, recruitment_campaigns, sponsored_vacancies, announcements
                $table->json('benefits')->nullable(); // Array of benefit highlight strings
                $table->string('badge_label', 50)->nullable(); // e.g. "Popular", "Best Value", "Enterprise"
                $table->boolean('is_active')->default(true);
                $table->integer('priority_level')->default(0);
                $table->timestamps();
            });
        }

        if (Schema::hasTable('advertisements') && !Schema::hasColumn('advertisements', 'package_id')) {
            Schema::table('advertisements', function (Blueprint $table) {
                $table->foreignId('package_id')->nullable()->after('job_id')->constrained('advertising_packages')->nullOnDelete();
            });
        }
    }

    public function down(): void {
        if (Schema::hasTable('advertisements') && Schema::hasColumn('advertisements', 'package_id')) {
            Schema::table('advertisements', function (Blueprint $table) {
                $table->dropForeign(['package_id']);
                $table->dropColumn('package_id');
            });
        }

        Schema::dropIfExists('advertising_packages');
    }
};
