<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // 1. Job Alerts Table (Section 6 of Job Seeker Specification)
        Schema::create('job_alerts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->string('title', 150); // Label / Name of alert
            $table->string('keyword', 150)->nullable();
            $table->foreignId('category_id')->nullable()->constrained('job_categories')->nullOnDelete();
            $table->string('location', 150)->nullable();
            $table->decimal('min_salary', 12, 2)->nullable();
            $table->string('frequency', 30)->default('daily'); // instant, daily, weekly
            $table->boolean('is_active')->default(true);
            $table->timestamp('last_notified_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'is_active']);
        });

        // 2. Job Offer Management Fields in Applications (Section 11 of Job Seeker Specification)
        Schema::table('applications', function (Blueprint $table) {
            $table->decimal('offer_salary', 12, 2)->nullable()->after('interview_status');
            $table->text('offer_benefits')->nullable()->after('offer_salary');
            $table->text('offer_conditions')->nullable()->after('offer_benefits');
            $table->date('offer_start_date')->nullable()->after('offer_conditions');
            $table->string('offer_status', 30)->default('none')->after('offer_start_date'); // none, offered, accepted, declined, clarification_requested
            $table->text('offer_notes')->nullable()->after('offer_status');
            $table->text('candidate_response_notes')->nullable()->after('offer_notes');
            $table->timestamp('offered_at')->nullable()->after('candidate_response_notes');
            $table->timestamp('offer_responded_at')->nullable()->after('offered_at');

            $table->index('offer_status');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('applications', function (Blueprint $table) {
            $table->dropIndex(['offer_status']);
            $table->dropColumn([
                'offer_salary',
                'offer_benefits',
                'offer_conditions',
                'offer_start_date',
                'offer_status',
                'offer_notes',
                'candidate_response_notes',
                'offered_at',
                'offer_responded_at',
            ]);
        });

        Schema::dropIfExists('job_alerts');
    }
};
