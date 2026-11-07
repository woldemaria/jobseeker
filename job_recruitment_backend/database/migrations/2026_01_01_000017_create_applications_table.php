<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('applications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('job_id')->constrained('jobs')->onDelete('restrict');
            $table->foreignId('profile_id')->constrained('job_seeker_profiles')->onDelete('restrict');
            $table->foreignId('cv_document_id')->constrained('documents')->onDelete('restrict');
            $table->text('cover_letter')->nullable();
            $table->string('status', 30)->default('submitted');
            $table->timestamp('applied_at')->useCurrent();
            $table->timestamps();

            $table->unique(['job_id', 'profile_id'], 'uq_job_applicant');
            $table->index('profile_id', 'idx_application_profile');
            $table->index('status', 'idx_application_status');
        });
    }

    public function down(): void {
        Schema::dropIfExists('applications');
    }
};