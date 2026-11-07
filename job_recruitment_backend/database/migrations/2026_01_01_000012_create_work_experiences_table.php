<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('work_experiences', function (Blueprint $table) {
            $table->id();
            $table->foreignId('profile_id')->constrained('job_seeker_profiles')->onDelete('cascade');
            $table->string('company_name', 200);
            $table->string('job_title', 150);
            $table->string('employment_type', 50)->nullable();
            $table->date('start_date')->nullable();
            $table->date('end_date')->nullable();
            $table->boolean('is_current')->default(false);
            $table->text('description')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void {
        Schema::dropIfExists('work_experiences');
    }
};