<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::table('advertisements', function (Blueprint $table) {
            if (!Schema::hasColumn('advertisements', 'description')) {
                $table->text('description')->nullable()->after('subtitle_am');
            }
            if (!Schema::hasColumn('advertisements', 'placements')) {
                $table->json('placements')->nullable()->after('placement'); // Selected multi-placement list
            }
            if (!Schema::hasColumn('advertisements', 'target_locations')) {
                $table->json('target_locations')->nullable()->after('target_category'); // Ethiopian geographic targeting
            }
            if (!Schema::hasColumn('advertisements', 'target_audience')) {
                $table->json('target_audience')->nullable()->after('target_locations');
            }
            if (!Schema::hasColumn('advertisements', 'approval_status')) {
                $table->string('approval_status', 30)->default('draft')->after('status'); // draft, pending_approval, approved, rejected
            }
            if (!Schema::hasColumn('advertisements', 'approved_by')) {
                $table->foreignId('approved_by')->nullable()->after('approval_status')->constrained('users')->nullOnDelete();
            }
            if (!Schema::hasColumn('advertisements', 'approved_at')) {
                $table->dateTime('approved_at')->nullable()->after('approved_by');
            }
            if (!Schema::hasColumn('advertisements', 'rejection_reason')) {
                $table->text('rejection_reason')->nullable()->after('approved_at');
            }
            if (!Schema::hasColumn('advertisements', 'payment_status')) {
                $table->string('payment_status', 30)->default('unpaid')->after('rejection_reason'); // unpaid, pending, paid, failed, refunded
            }
            if (!Schema::hasColumn('advertisements', 'price_paid')) {
                $table->decimal('price_paid', 12, 2)->default(0.00)->after('payment_status');
            }
        });
    }

    public function down(): void {
        Schema::table('advertisements', function (Blueprint $table) {
            $columnsToDrop = [];
            foreach (['description', 'placements', 'target_locations', 'target_audience', 'approval_status', 'approved_by', 'approved_at', 'rejection_reason', 'payment_status', 'price_paid'] as $col) {
                if (Schema::hasColumn('advertisements', $col)) {
                    $columnsToDrop[] = $col;
                }
            }
            if (!empty($columnsToDrop)) {
                $table->dropColumn($columnsToDrop);
            }
        });
    }
};
