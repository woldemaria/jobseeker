<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('jobs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employer_id')->constrained('employers')->onDelete('restrict');
            $table->string('title', 200);
            $table->longText('description');
            $table->text('responsibilities')->nullable();
            $table->text('requirements')->nullable();
            $table->string('location', 150);
            $table->string('employment_type', 50);
            $table->decimal('experience_required', 4, 1)->nullable();
            $table->decimal('salary_min', 12, 2)->nullable();
            $table->decimal('salary_max', 12, 2)->nullable();
            $table->string('currency', 10)->default('ETB');
            $table->date('deadline');
            $table->string('status', 30)->default('draft');
            $table->timestamp('published_at')->nullable();
            $table->timestamps();

            $table->index(['status', 'deadline'], 'idx_job_status_deadline');
            $table->index('location', 'idx_job_location');
            $table->index('employer_id', 'idx_job_employer');
        });
    }

    public function down(): void {
        Schema::dropIfExists('jobs');
    }
};