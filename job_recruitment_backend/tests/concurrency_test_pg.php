<?php

require __DIR__ . '/../vendor/autoload.php';
$app = require_once __DIR__ . '/../bootstrap/app.php';

$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;
use App\Models\Employer;
use App\Models\AdvertisingPackage;
use App\Models\Advertisement;
use App\Models\PaymentTransaction;
use App\Models\PaymentRefund;
use App\Services\Payment\PaymentManagerService;
use Illuminate\Support\Facades\DB;

// Verify database driver compatibility (PostgreSQL or SQLite)
$driver = DB::connection()->getDriverName();
echo "Connected Database Driver: {$driver}\n";
if ($driver !== 'pgsql' && $driver !== 'sqlite') {
    echo "ERROR: Concurrency test must run against PostgreSQL or SQLite. Current driver: {$driver}\n";
    exit(1);
}

$mode = $argv[1] ?? 'setup';

if ($mode === 'setup') {
    // Setup test records
    DB::beginTransaction();
    try {
        $admin = User::firstOrCreate(
            ['email' => 'admin_concurrency@example.com'],
            ['name' => 'Admin Concurrency', 'password' => bcrypt('Secret123!')]
        );
        $employerUser = User::firstOrCreate(
            ['email' => 'emp_concurrency@example.com'],
            ['name' => 'Emp Concurrency', 'password' => bcrypt('Secret123!')]
        );
        $employer = Employer::firstOrCreate(
            ['organization_name' => 'Concurrency Corp'],
            ['phone' => '+251911999999', 'verification_status' => 'verified']
        );
        $package = AdvertisingPackage::firstOrCreate(
            ['slug' => 'pkg-concurrency-test'],
            ['name' => 'Concurrency Pkg', 'price_etb' => 5000.00, 'duration_days' => 30, 'is_active' => true]
        );
        $ad = Advertisement::firstOrCreate(
            ['title' => 'Concurrency Test Ad'],
            [
                'employer_id' => $employer->id,
                'package_id' => $package->id,
                'created_by' => $employerUser->id,
                'image_url' => 'https://example.com/banner.png',
                'category' => 'company_promotions',
                'placement' => 'dashboard',
                'cta_type' => 'explore_jobs',
                'cta_text' => 'View Campaign',
                'cta_target' => 'https://example.com',
                'status' => 'draft',
                'approval_status' => 'approved',
                'payment_status' => 'pending',
                'start_date' => now(),
                'end_date' => now()->addDays(30)
            ]
        );

        $tx = PaymentTransaction::updateOrCreate(
            ['transaction_reference' => 'TXN-CONCURRENCY-5000'],
            [
                'merchant_reference' => 'CMP-CONC-001',
                'payment_method' => 'chapa',
                'employer_name_snapshot' => $employer->organization_name,
                'employer_id' => $employer->id,
                'user_id' => $employerUser->id,
                'advertisement_id' => $ad->id,
                'campaign_title_snapshot' => $ad->title,
                'package_id' => $package->id,
                'package_name_snapshot' => $package->name,
                'expected_amount_etb' => 5000.00,
                'confirmed_amount_etb' => 5000.00,
                'currency' => 'ETB',
                'payment_status' => 'successful',
                'verified_at' => now(),
                'verified_by' => 'concurrency_setup',
                'receipt_number' => 'RCP-CONC-5000',
            ]
        );

        // Clear previous refunds for this transaction
        PaymentRefund::where('transaction_id', $tx->id)->delete();

        DB::commit();
        echo "SETUP_SUCCESS: Transaction ID {$tx->id} ready with 5000 ETB confirmed balance.\n";
    } catch (\Throwable $e) {
        DB::rollBack();
        echo "SETUP_ERROR: " . $e->getMessage() . "\n";
        exit(1);
    }
} elseif ($mode === 'worker') {
    $workerId = $argv[2] ?? 0;
    $refundAmount = (float) ($argv[3] ?? 3500.00);

    // Bind a test gateway adapter that simulates a 100ms provider network call
    app()->bind(\App\Services\Payment\ChapaPaymentGateway::class, function () {
        return new class extends \App\Services\Payment\ChapaPaymentGateway {
            public function __construct() {}
            public function isConfigured(): bool { return true; }
            public function handleRefund(\App\Models\PaymentTransaction $transaction, float $amount, string $reason): array {
                // Simulate gateway latency of 100ms to test concurrency overlap
                usleep(100000);
                return [
                    'success' => true,
                    'provider_refund_id' => 'test_chapa_ref_' . uniqid(),
                    'message' => 'Refund processed by simulated provider',
                ];
            }
        };
    });

    // Fresh instance of PaymentManagerService with test gateway bound
    $paymentManager = app(\App\Services\Payment\PaymentManagerService::class);

    $admin = User::where('email', 'admin_concurrency@example.com')->firstOrFail();
    $tx = PaymentTransaction::where('transaction_reference', 'TXN-CONCURRENCY-5000')->firstOrFail();

    try {
        $refund = $paymentManager->processRefund($tx, $admin, $refundAmount, "Concurrent Worker {$workerId} attempt");
        echo "WORKER_{$workerId}_SUCCESS: Refunded {$refund->amount} ETB (Ref: {$refund->refund_reference})\n";
    } catch (\Throwable $e) {
        echo "WORKER_{$workerId}_REJECTED: " . $e->getMessage() . "\n";
    }
} elseif ($mode === 'verify') {
    $tx = PaymentTransaction::where('transaction_reference', 'TXN-CONCURRENCY-5000')->firstOrFail();
    $totalRefunded = (float) PaymentRefund::where('transaction_id', $tx->id)->where('status', 'completed')->sum('amount');
    $refundCount = PaymentRefund::where('transaction_id', $tx->id)->where('status', 'completed')->count();
    $txFresh = $tx->fresh();

    echo "VERIFY_RESULTS:\n";
    echo "- Confirmed Amount: {$txFresh->confirmed_amount_etb} ETB\n";
    echo "- Total Refunded in DB: {$totalRefunded} ETB\n";
    echo "- Completed Refund Records: {$refundCount}\n";
    echo "- Payment Status: {$txFresh->payment_status}\n";

    if ($totalRefunded > (float) $txFresh->confirmed_amount_etb) {
        echo "VERIFY_FAIL: Race condition occurred! Over-refunded {$totalRefunded} > {$txFresh->confirmed_amount_etb}\n";
        exit(1);
    } else {
        echo "VERIFY_PASS: Row-level locking prevented over-refund. Exactly {$totalRefunded} ETB refunded.\n";
        exit(0);
    }
}
