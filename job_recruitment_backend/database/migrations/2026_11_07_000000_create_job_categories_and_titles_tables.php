<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('job_categories', function (Blueprint $table) {
            $table->id();
            $table->string('name', 150)->unique();
            $table->string('slug', 150)->unique();
            $table->string('icon', 50)->nullable();
            $table->text('description')->nullable();
            $table->integer('display_order')->default(0);
            $table->timestamps();
        });

        Schema::create('job_titles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('category_id')->constrained('job_categories')->onDelete('cascade');
            $table->string('title', 200);
            $table->string('slug', 200);
            $table->timestamps();

            $table->index('title');
            $table->index('category_id');
        });

        Schema::table('jobs', function (Blueprint $table) {
            $table->foreignId('category_id')->nullable()->after('employer_id')->constrained('job_categories')->onDelete('set null');
            $table->string('category', 150)->nullable()->after('category_id');
            $table->foreignId('job_title_id')->nullable()->after('title')->constrained('job_titles')->onDelete('set null');

            $table->index('category');
        });

        Schema::table('job_seeker_profiles', function (Blueprint $table) {
            $table->string('preferred_job_title', 200)->nullable()->after('field_of_study');
            $table->foreignId('preferred_category_id')->nullable()->after('preferred_job_title')->constrained('job_categories')->onDelete('set null');
        });
    }

    public function down(): void {
        Schema::table('job_seeker_profiles', function (Blueprint $table) {
            $table->dropForeign(['preferred_category_id']);
            $table->dropColumn(['preferred_job_title', 'preferred_category_id']);
        });

        Schema::table('jobs', function (Blueprint $table) {
            $table->dropForeign(['category_id']);
            $table->dropForeign(['job_title_id']);
            $table->dropColumn(['category_id', 'category', 'job_title_id']);
        });

        Schema::dropIfExists('job_titles');
        Schema::dropIfExists('job_categories');
    }
};
