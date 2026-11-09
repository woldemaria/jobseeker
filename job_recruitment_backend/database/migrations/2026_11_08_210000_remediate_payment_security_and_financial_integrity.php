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
        Schema::table('payment_transactions', function (Blueprint $table) {
            $table->string('employer_name_snapshot', 150)->nullable()->after('payment_method');
            $table->string('campaign_title_snapshot', 255)->nullable()->after('advertisement_id');
            $table->string('package_name_snapshot', 100)->nullable()->after('package_id');
        });

        // Recreate payment_webhook_events with compound uniqueness (provider, event_id) and preserve data
        Schema::create('payment_webhook_events_temp', function (Blueprint $table) {
            $table->id();
            $table->string('provider', 50)->index();
            $table->string('event_id', 150);
            $table->string('transaction_reference', 100)->nullable()->index();
            $table->json('payload');
            $table->string('signature', 255)->nullable();
            $table->boolean('processed')->default(false);
            $table->text('processing_notes')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->unique(['provider', 'event_id'], 'payment_webhooks_provider_event_unique');
        });

        DB::statement('INSERT INTO payment_webhook_events_temp SELECT * FROM payment_webhook_events');
        Schema::drop('payment_webhook_events');
        Schema::rename('payment_webhook_events_temp', 'payment_webhook_events');

        // Recreate payment_transactions to change foreign keys from cascadeOnDelete to nullOnDelete
        Schema::create('payment_transactions_temp', function (Blueprint $table) {
            $table->id();
            $table->string('transaction_reference', 100)->unique();
            $table->string('merchant_reference', 100)->index();
            $table->string('provider_reference', 150)->nullable()->index();
            $table->text('checkout_url')->nullable();
            $table->string('payment_method', 50)->index();
            $table->string('employer_name_snapshot', 150)->nullable();
            $table->foreignId('employer_id')->nullable()->constrained('employers')->nullOnDelete();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('advertisement_id')->nullable()->constrained('advertisements')->nullOnDelete();
            $table->string('campaign_title_snapshot', 255)->nullable();
            $table->foreignId('package_id')->nullable()->constrained('advertising_packages')->nullOnDelete();
            $table->string('package_name_snapshot', 100)->nullable();
            $table->decimal('expected_amount_etb', 12, 2);
            $table->decimal('confirmed_amount_etb', 12, 2)->nullable();
            $table->string('currency', 3)->default('ETB');
            $table->string('payment_status', 30)->default('pending')->index();
            $table->timestamp('verified_at')->nullable();
            $table->string('verified_by', 100)->nullable();
            $table->text('failure_reason')->nullable();
            $table->string('receipt_number', 64)->nullable()->unique();
            $table->json('payment_metadata')->nullable();
            $table->timestamps();
        });

        DB::statement('INSERT INTO payment_transactions_temp (
            id, transaction_reference, merchant_reference, provider_reference, checkout_url,
            payment_method, employer_name_snapshot, employer_id, user_id, advertisement_id,
            campaign_title_snapshot, package_id, package_name_snapshot, expected_amount_etb,
            confirmed_amount_etb, currency, payment_status, verified_at, verified_by,
            failure_reason, receipt_number, payment_metadata, created_at, updated_at
        ) SELECT 
            id, transaction_reference, merchant_reference, provider_reference, checkout_url,
            payment_method, NULL, employer_id, user_id, advertisement_id,
            NULL, package_id, NULL, expected_amount_etb,
            confirmed_amount_etb, currency, payment_status, verified_at, verified_by,
            failure_reason, receipt_number, payment_metadata, created_at, updated_at
        FROM payment_transactions');

        // Recreate payment_refunds to enforce restrictOnDelete on transaction_id and nullOnDelete on initiated_by
        Schema::create('payment_refunds_temp', function (Blueprint $table) {
            $table->id();
            $table->foreignId('transaction_id')->constrained('payment_transactions')->restrictOnDelete();
            $table->string('refund_reference', 100)->unique();
            $table->decimal('amount', 12, 2);
            $table->text('reason');
            $table->string('status', 30)->default('pending')->index();
            $table->foreignId('initiated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('provider_refund_id', 150)->nullable();
            $table->json('metadata')->nullable();
            $table->timestamps();
        });

        DB::statement('INSERT INTO payment_refunds_temp SELECT * FROM payment_refunds');

        // Swap tables cleanly across SQLite, PostgreSQL, and MySQL
        $driver = DB::getDriverName();
        if ($driver === 'sqlite') {
            DB::statement('PRAGMA foreign_keys = OFF');
            Schema::drop('payment_refunds');
            Schema::drop('payment_transactions');
            Schema::rename('payment_transactions_temp', 'payment_transactions');
            Schema::rename('payment_refunds_temp', 'payment_refunds');
            DB::statement('PRAGMA foreign_keys = ON');
        } elseif ($driver === 'pgsql') {
            DB::statement('DROP TABLE payment_refunds CASCADE');
            DB::statement('DROP TABLE payment_transactions CASCADE');
            Schema::rename('payment_transactions_temp', 'payment_transactions');
            Schema::rename('payment_refunds_temp', 'payment_refunds');
            DB::statement('ALTER TABLE payment_refunds ADD CONSTRAINT payment_refunds_transaction_id_foreign FOREIGN KEY (transaction_id) REFERENCES payment_transactions(id) ON DELETE RESTRICT');
        } else {
            DB::statement('SET FOREIGN_KEY_CHECKS=0');
            Schema::drop('payment_refunds');
            Schema::drop('payment_transactions');
            Schema::rename('payment_transactions_temp', 'payment_transactions');
            Schema::rename('payment_refunds_temp', 'payment_refunds');
            DB::statement('SET FOREIGN_KEY_CHECKS=1');
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('payment_webhook_events', function (Blueprint $table) {
            $table->dropUnique('payment_webhooks_provider_event_unique');
            $table->unique('event_id');
        });
    }
};
