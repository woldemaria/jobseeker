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
        Schema::table('jobs', function (Blueprint $table) {
            $table->unsignedSmallInteger('fraud_score')->default(0)->after('status');
            $table->string('fraud_risk_level', 20)->default('low')->after('fraud_score'); // low, medium, high, critical
            $table->json('fraud_indicators')->nullable()->after('fraud_risk_level');
            $table->boolean('is_flagged')->default(false)->after('fraud_indicators');
            $table->string('moderation_status', 30)->default('clean')->after('is_flagged'); // clean, flagged, under_review, fraudulent, cleared
            $table->foreignId('moderated_by')->nullable()->after('moderation_status')->constrained('users')->nullOnDelete();
            $table->timestamp('moderated_at')->nullable()->after('moderated_by');
            $table->text('moderation_notes')->nullable()->after('moderated_at');

            $table->index(['is_flagged', 'fraud_score'], 'idx_jobs_fraud_flag_score');
            $table->index('moderation_status', 'idx_jobs_moderation_status');
        });

        Schema::table('reports', function (Blueprint $table) {
            $table->string('action_taken', 50)->nullable()->after('reviewed_by'); // marked_fraudulent, marked_safe, job_takedown, employer_suspended, dismissed
            $table->text('resolution_notes')->nullable()->after('action_taken');
            $table->timestamp('resolved_at')->nullable()->after('resolution_notes');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            $table->dropColumn(['action_taken', 'resolution_notes', 'resolved_at']);
        });

        Schema::table('jobs', function (Blueprint $table) {
            $table->dropForeign(['moderated_by']);
            $table->dropIndex('idx_jobs_fraud_flag_score');
            $table->dropIndex('idx_jobs_moderation_status');
            $table->dropColumn([
                'fraud_score',
                'fraud_risk_level',
                'fraud_indicators',
                'is_flagged',
                'moderation_status',
                'moderated_by',
                'moderated_at',
                'moderation_notes',
            ]);
        });
    }
};
