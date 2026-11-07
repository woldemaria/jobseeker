<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('education_records', function (Blueprint $table) {
            $table->id();
            $table->foreignId('profile_id')->constrained('job_seeker_profiles')->onDelete('cascade');
            $table->string('institution_name', 200);
            $table->string('qualification', 150);
            $table->string('field_of_study', 150)->nullable();
            $table->date('start_date')->nullable();
            $table->date('end_date')->nullable();
            $table->string('grade', 50)->nullable();
            $table->text('description')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void {
        Schema::dropIfExists('education_records');
    }
};