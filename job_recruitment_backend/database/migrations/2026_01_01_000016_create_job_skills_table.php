<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('job_skills', function (Blueprint $table) {
            $table->id();
            $table->foreignId('job_id')->constrained('jobs')->onDelete('cascade');
            $table->foreignId('skill_id')->constrained('skills')->onDelete('restrict');
            $table->string('importance', 20)->default('required');
            $table->string('minimum_proficiency', 30)->nullable();
            $table->timestamps();
            $table->unique(['job_id', 'skill_id'], 'uq_job_skill');
        });
    }

    public function down(): void {
        Schema::dropIfExists('job_skills');
    }
};