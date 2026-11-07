<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('job_seeker_skills', function (Blueprint $table) {
            $table->id();
            $table->foreignId('profile_id')->constrained('job_seeker_profiles')->onDelete('cascade');
            $table->foreignId('skill_id')->constrained('skills')->onDelete('restrict');
            $table->string('proficiency_level', 30);
            $table->decimal('years_experience', 4, 1)->default(0);
            $table->timestamps();
            $table->unique(['profile_id', 'skill_id'], 'uq_profile_skill');
        });
    }

    public function down(): void {
        Schema::dropIfExists('job_seeker_skills');
    }
};