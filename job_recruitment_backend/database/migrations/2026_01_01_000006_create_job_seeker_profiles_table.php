<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('job_seeker_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->onDelete('restrict');
            $table->date('date_of_birth')->nullable();
            $table->string('gender', 30)->nullable();
            $table->string('education_level', 100)->nullable();
            $table->string('field_of_study', 150)->nullable();
            $table->decimal('experience_years', 4, 1)->default(0);
            $table->string('location', 150)->nullable();
            $table->text('biography')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void {
        Schema::dropIfExists('job_seeker_profiles');
    }
};