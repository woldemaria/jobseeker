<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::table('applications', function (Blueprint $table) {
            $table->dateTime('interview_at')->nullable()->after('status');
            $table->string('interview_type', 50)->nullable()->after('interview_at'); // video, in_person, phone
            $table->string('interview_location', 255)->nullable()->after('interview_type'); // URL or physical address
            $table->text('interview_notes')->nullable()->after('interview_location');
            $table->string('interview_status', 30)->nullable()->default('scheduled')->after('interview_notes'); // scheduled, confirmed, rescheduled, completed, cancelled
        });
    }

    public function down(): void {
        Schema::table('applications', function (Blueprint $table) {
            $table->dropColumn([
                'interview_at',
                'interview_type',
                'interview_location',
                'interview_notes',
                'interview_status',
            ]);
        });
    }
};
