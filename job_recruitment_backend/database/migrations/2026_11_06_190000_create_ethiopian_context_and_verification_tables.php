<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        // 1. Add geospatial coordinates and notice board reference to jobs
        Schema::table('jobs', function (Blueprint $table) {
            $table->decimal('latitude', 10, 7)->nullable()->after('location');
            $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
            $table->string('notice_code', 50)->nullable()->unique()->after('longitude');
            $table->text('qr_payload')->nullable()->after('notice_code');
        });

        // 2. Skill Quizzes & Assessments
        Schema::create('quizzes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('skill_id')->constrained('skills')->onDelete('cascade');
            $table->string('title', 150);
            $table->text('description')->nullable();
            $table->integer('passing_score')->default(80);
            $table->integer('duration_seconds')->default(60);
            $table->timestamps();
        });

        Schema::create('quiz_questions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('quiz_id')->constrained('quizzes')->onDelete('cascade');
            $table->text('question_text');
            $table->integer('points')->default(20);
            $table->timestamps();
        });

        Schema::create('quiz_options', function (Blueprint $table) {
            $table->id();
            $table->foreignId('quiz_question_id')->constrained('quiz_questions')->onDelete('cascade');
            $table->text('option_text');
            $table->boolean('is_correct')->default(false);
            $table->timestamps();
        });

        Schema::create('user_skill_badges', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('skill_id')->constrained('skills')->onDelete('cascade');
            $table->foreignId('quiz_id')->nullable()->constrained('quizzes')->onDelete('set null');
            $table->decimal('score', 5, 2);
            $table->string('badge_type', 50)->default('verified_skill');
            $table->timestamp('verified_at')->useCurrent();
            $table->timestamps();

            $table->unique(['user_id', 'skill_id']);
        });

        // 3. Automated Knockout Screening Questions
        Schema::create('job_screening_questions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('job_id')->constrained('jobs')->onDelete('cascade');
            $table->string('question_text', 255);
            $table->boolean('expected_boolean')->default(true); // Candidate must answer Yes
            $table->boolean('is_knockout')->default(true);
            $table->timestamps();
        });

        Schema::create('application_screening_answers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('application_id')->constrained('applications')->onDelete('cascade');
            $table->foreignId('question_id')->constrained('job_screening_questions')->onDelete('cascade');
            $table->boolean('answer_boolean');
            $table->boolean('passed')->default(true);
            $table->timestamps();
        });

        // 4. SMS Fallback Delivery Log
        Schema::create('sms_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->string('phone', 30);
            $table->text('message');
            $table->string('gateway_status', 50)->default('delivered');
            $table->timestamp('sent_at')->useCurrent();
            $table->timestamps();
        });
    }

    public function down(): void {
        Schema::dropIfExists('sms_logs');
        Schema::dropIfExists('application_screening_answers');
        Schema::dropIfExists('job_screening_questions');
        Schema::dropIfExists('user_skill_badges');
        Schema::dropIfExists('quiz_options');
        Schema::dropIfExists('quiz_questions');
        Schema::dropIfExists('quizzes');

        Schema::table('jobs', function (Blueprint $table) {
            $table->dropColumn(['latitude', 'longitude', 'notice_code', 'qr_payload']);
        });
    }
};
