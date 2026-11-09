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
        Schema::create('payment_transactions', function (Blueprint $table) {
            $table->id();
            $table->string('transaction_reference', 100)->unique();
            $table->string('merchant_reference', 100)->index();
            $table->string('provider_reference', 150)->nullable()->index();
            $table->text('checkout_url')->nullable();
            $table->string('payment_method', 50)->index(); // chapa, telebirr, cbe_birr
            $table->foreignId('employer_id')->constrained('employers')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('advertisement_id')->constrained('advertisements')->cascadeOnDelete();
            $table->foreignId('package_id')->constrained('advertising_packages')->cascadeOnDelete();
            $table->decimal('expected_amount_etb', 12, 2);
            $table->decimal('confirmed_amount_etb', 12, 2)->nullable();
            $table->string('currency', 3)->default('ETB');
            $table->string('payment_status', 30)->default('pending')->index(); // pending, processing, successful, failed, cancelled, expired, refunded
            $table->timestamp('verified_at')->nullable();
            $table->string('verified_by', 100)->nullable();
            $table->text('failure_reason')->nullable();
            $table->string('receipt_number', 64)->nullable()->unique();
            $table->json('payment_metadata')->nullable();
            $table->timestamps();
        });

        Schema::create('payment_webhook_events', function (Blueprint $table) {
            $table->id();
            $table->string('provider', 50)->index();
            $table->string('event_id', 150)->unique();
            $table->string('transaction_reference', 100)->nullable()->index();
            $table->json('payload');
            $table->string('signature', 255)->nullable();
            $table->boolean('processed')->default(false);
            $table->text('processing_notes')->nullable();
            $table->timestamp('created_at')->useCurrent();
        });

        Schema::create('payment_refunds', function (Blueprint $table) {
            $table->id();
            $table->foreignId('transaction_id')->constrained('payment_transactions')->cascadeOnDelete();
            $table->string('refund_reference', 100)->unique();
            $table->decimal('amount', 12, 2);
            $table->text('reason');
            $table->string('status', 30)->default('pending')->index(); // pending, completed, failed
            $table->foreignId('initiated_by')->constrained('users');
            $table->string('provider_refund_id', 150)->nullable();
            $table->json('metadata')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('payment_refunds');
        Schema::dropIfExists('payment_webhook_events');
        Schema::dropIfExists('payment_transactions');
    }
};
