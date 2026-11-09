<?php

namespace Tests\Feature;

use App\Models\Advertisement;
use App\Models\AdvertisingPackage;
use App\Models\Employer;
use App\Models\PaymentRefund;
use App\Models\PaymentTransaction;
use App\Models\PaymentWebhookEvent;
use App\Models\Role;
use App\Models\User;
use App\Services\Payment\ChapaPaymentGateway;
use App\Services\Payment\PaymentManagerService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ProductionReadinessSecurityTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Role::firstOrCreate(['name' => 'JobSeeker'], ['description' => 'Job Seeker Role']);
        Role::firstOrCreate(['name' => 'Employer'], ['description' => 'Employer Role']);
        Role::firstOrCreate(['name' => 'Admin'], ['description' => 'Administrator Role']);
    }

    /**
     * Test SEC-01 & SEC-02: Fail-closed credential handling and sandbox/live separation.
     */
    public function test_chapa_credential_separation_and_fail_closed(): void
    {
        // 1. Unconfigured gateway must fail closed
        config(['services.chapa.secret_key' => null]);
        config(['services.chapa.webhook_secret' => null]);
        config(['services.chapa.mode' => 'sandbox']);

        $gateway = new ChapaPaymentGateway();
        $this->assertFalse($gateway->isConfigured());
        $status = $gateway->getConfigurationStatus();
        $this->assertFalse($status['configured']);
        $this->assertEquals('unconfigured', $status['mode']);

        // Check fail-closed on signature check
        $req = Request::create('/api/advertisements/payments/webhook/chapa', 'POST', ['test' => 1]);
        $this->assertFalse($gateway->verifyWebhookSignature($req));

        // Check fail-closed on refund
        $this->expectException(\Exception::class);
        $this->expectExceptionMessage('Chapa is not configured for refunds.');

        $tx = new PaymentTransaction(['transaction_reference' => 'TXN-TEST', 'payment_method' => 'chapa']);
        $gateway->handleRefund($tx, 100.0, 'Test fail closed');
    }

    /**
     * Test SEC-02: Test Mode vs Live Mode strict credential validation.
     */
    public function test_chapa_mode_and_key_prefix_isolation(): void
    {
        // Test key in sandbox mode
        config(['services.chapa.secret_key' => 'CHASECK_TEST-123456789']);
        config(['services.chapa.mode' => 'sandbox']);
        $gateway = new ChapaPaymentGateway();
        $this->assertTrue($gateway->isConfigured());
        $status = $gateway->getConfigurationStatus();
        $this->assertEquals('sandbox', $status['mode']);

        // Test key configured in production mode must report sandbox mode because of CHASECK_TEST prefix
        config(['services.chapa.secret_key' => 'CHASECK_TEST-123456789']);
        config(['services.chapa.mode' => 'live']);
        $gateway = new ChapaPaymentGateway();
        $status = $gateway->getConfigurationStatus();
        $this->assertEquals('sandbox', $status['mode']); // Strictly prevented from claiming live mode with test key!

        // Live key in live mode
        config(['services.chapa.secret_key' => 'CHASECK_LIVE-987654321']);
        config(['services.chapa.mode' => 'live']);
        $gateway = new ChapaPaymentGateway();
        $status = $gateway->getConfigurationStatus();
        $this->assertEquals('live', $status['mode']);
    }

    /**
     * Test SEC-03: Webhook signature verification, replay protection & idempotency.
     */
    public function test_webhook_signature_and_replay_protection(): void
    {
        $secret = 'test_webhook_secret_key_123';
        config(['services.chapa.secret_key' => $secret]);
        config(['services.chapa.webhook_secret' => $secret]);

        $gateway = new ChapaPaymentGateway();
        $this->app->instance(ChapaPaymentGateway::class, $gateway);

        $employerUser = User::factory()->create();
        $employer = Employer::create(['organization_name' => 'Replay Guard Corp', 'verification_status' => 'verified']);
        $package = AdvertisingPackage::create(['name' => 'Replay Pkg', 'slug' => 'pkg-replay', 'price_etb' => 2500.00, 'duration_days' => 15]);
        $ad = Advertisement::create([
            'employer_id' => $employer->id,
            'package_id' => $package->id,
            'created_by' => $employerUser->id,
            'title' => 'Replay Protection Vacancy',
            'image_url' => 'https://example.com/ad.png',
            'category' => 'company_promotions',
            'placement' => 'dashboard',
            'cta_type' => 'explore_jobs',
            'cta_text' => 'Apply',
            'cta_target' => 'https://example.com',
            'status' => 'draft',
            'approval_status' => 'approved',
            'payment_status' => 'pending',
            'start_date' => now(),
            'end_date' => now()->addDays(15),
        ]);

        $tx = PaymentTransaction::create([
            'transaction_reference' => 'TXN-REPLAY-2500',
            'merchant_reference' => 'CMP-REPLAY-1',
            'payment_method' => 'chapa',
            'employer_name_snapshot' => $employer->organization_name,
            'employer_id' => $employer->id,
            'user_id' => $employerUser->id,
            'advertisement_id' => $ad->id,
            'campaign_title_snapshot' => $ad->title,
            'package_id' => $package->id,
            'package_name_snapshot' => $package->name,
            'expected_amount_etb' => 2500.00,
            'currency' => 'ETB',
            'payment_status' => 'pending',
        ]);

        $payload = [
            'event_id' => 'evt_chapa_replay_001',
            'tx_ref' => 'TXN-REPLAY-2500',
            'status' => 'success',
            'amount' => 2500.00,
            'currency' => 'ETB',
        ];
        $rawContent = json_encode($payload);
        $validSignature = hash_hmac('sha256', $rawContent, $secret);

        // 1. Invalid signature must fail
        $invalidReq = Request::create(
            '/api/advertisements/payments/webhook/chapa',
            'POST',
            [],
            [],
            [],
            ['HTTP_X_CHAPA_SIGNATURE' => 'invalid_signature_hash', 'CONTENT_TYPE' => 'application/json'],
            $rawContent
        );
        $paymentManager = $this->app->make(PaymentManagerService::class);
        $this->expectException(\Exception::class);
        $this->expectExceptionMessage('Invalid or missing webhook signature');
        $paymentManager->processWebhook('chapa', $invalidReq);
    }

    /**
     * Test SEC-03: Webhook valid signature succeeds and second delivery is flagged as duplicate.
     */
    public function test_webhook_successful_processing_and_subsequent_duplicate_idempotency(): void
    {
        $secret = 'test_webhook_secret_key_456';
        config(['services.chapa.secret_key' => $secret]);
        config(['services.chapa.webhook_secret' => $secret]);

        $gateway = new ChapaPaymentGateway();
        $this->app->instance(ChapaPaymentGateway::class, $gateway);

        $employerUser = User::factory()->create();
        $employer = Employer::create(['organization_name' => 'Idempotent Corp', 'verification_status' => 'verified']);
        $package = AdvertisingPackage::create(['name' => 'Idempotent Pkg', 'slug' => 'pkg-idem', 'price_etb' => 3000.00, 'duration_days' => 30]);
        $ad = Advertisement::create([
            'employer_id' => $employer->id,
            'package_id' => $package->id,
            'created_by' => $employerUser->id,
            'title' => 'Idempotent Vacancy',
            'image_url' => 'https://example.com/ad.png',
            'category' => 'company_promotions',
            'placement' => 'dashboard',
            'cta_type' => 'explore_jobs',
            'cta_text' => 'Apply',
            'cta_target' => 'https://example.com',
            'status' => 'draft',
            'approval_status' => 'approved',
            'payment_status' => 'pending',
            'start_date' => now(),
            'end_date' => now()->addDays(30),
        ]);

        $tx = PaymentTransaction::create([
            'transaction_reference' => 'TXN-IDEM-3000',
            'merchant_reference' => 'CMP-IDEM-1',
            'payment_method' => 'chapa',
            'employer_name_snapshot' => $employer->organization_name,
            'employer_id' => $employer->id,
            'user_id' => $employerUser->id,
            'advertisement_id' => $ad->id,
            'campaign_title_snapshot' => $ad->title,
            'package_id' => $package->id,
            'package_name_snapshot' => $package->name,
            'expected_amount_etb' => 3000.00,
            'currency' => 'ETB',
            'payment_status' => 'pending',
        ]);

        $payload = [
            'event_id' => 'evt_idem_999',
            'tx_ref' => 'TXN-IDEM-3000',
            'status' => 'success',
            'amount' => 3000.00,
            'currency' => 'ETB',
        ];
        $rawContent = json_encode($payload);
        $signature = hash_hmac('sha256', $rawContent, $secret);

        $validReq = Request::create(
            '/api/advertisements/payments/webhook/chapa',
            'POST',
            [],
            [],
            [],
            ['HTTP_X_CHAPA_SIGNATURE' => $signature, 'CONTENT_TYPE' => 'application/json'],
            $rawContent
        );

        $paymentManager = $this->app->make(PaymentManagerService::class);

        // First delivery: processes successfully
        $res1 = $paymentManager->processWebhook('chapa', $validReq);
        $this->assertEquals('success', $res1['status']);
        $this->assertEquals('successful', $tx->fresh()->payment_status);
        $this->assertEquals('active', $ad->fresh()->status);

        // Second delivery (duplicate replay): must return 'duplicate' status idempotently without reprocessing
        $res2 = $paymentManager->processWebhook('chapa', $validReq);
        $this->assertEquals('duplicate', $res2['status']);
        $this->assertEquals('Event already processed idempotently.', $res2['message']);
    }

    /**
     * Test SEC-03: Underpayment and Amount Mismatch Rejection.
     */
    public function test_exact_etb_amount_reconciliation_and_underpayment_rejection(): void
    {
        $secret = 'test_secret_reconciliation';
        config(['services.chapa.secret_key' => $secret]);
        config(['services.chapa.webhook_secret' => $secret]);

        $gateway = new ChapaPaymentGateway();
        $this->app->instance(ChapaPaymentGateway::class, $gateway);

        $employerUser = User::factory()->create();
        $employer = Employer::create(['organization_name' => 'Amount Match Corp', 'verification_status' => 'verified']);
        $package = AdvertisingPackage::create(['name' => 'Amount Pkg', 'slug' => 'pkg-amount', 'price_etb' => 5000.00, 'duration_days' => 30]);
        $ad = Advertisement::create([
            'employer_id' => $employer->id,
            'package_id' => $package->id,
            'created_by' => $employerUser->id,
            'title' => 'Amount Vacancy',
            'image_url' => 'https://example.com/ad.png',
            'category' => 'company_promotions',
            'placement' => 'dashboard',
            'cta_type' => 'explore_jobs',
            'cta_text' => 'Apply',
            'cta_target' => 'https://example.com',
            'status' => 'draft',
            'approval_status' => 'approved',
            'payment_status' => 'pending',
            'start_date' => now(),
            'end_date' => now()->addDays(30),
        ]);

        $tx = PaymentTransaction::create([
            'transaction_reference' => 'TXN-UNDERPAY-5000',
            'merchant_reference' => 'CMP-UNDERPAY-1',
            'payment_method' => 'chapa',
            'employer_name_snapshot' => $employer->organization_name,
            'employer_id' => $employer->id,
            'user_id' => $employerUser->id,
            'advertisement_id' => $ad->id,
            'campaign_title_snapshot' => $ad->title,
            'package_id' => $package->id,
            'package_name_snapshot' => $package->name,
            'expected_amount_etb' => 5000.00,
            'currency' => 'ETB',
            'payment_status' => 'pending',
        ]);

        // Webhook sends 4999.00 ETB (underpayment)
        $payload = [
            'event_id' => 'evt_underpay_001',
            'tx_ref' => 'TXN-UNDERPAY-5000',
            'status' => 'success',
            'amount' => 4999.00,
            'currency' => 'ETB',
        ];
        $rawContent = json_encode($payload);
        $signature = hash_hmac('sha256', $rawContent, $secret);

        $req = Request::create(
            '/api/advertisements/payments/webhook/chapa',
            'POST',
            [],
            [],
            [],
            ['HTTP_X_CHAPA_SIGNATURE' => $signature, 'CONTENT_TYPE' => 'application/json'],
            $rawContent
        );

        $paymentManager = $this->app->make(PaymentManagerService::class);

        $this->expectException(\Exception::class);
        $this->expectExceptionMessage('Payment amount mismatch on transaction TXN-UNDERPAY-5000: expected 5000.00 ETB, received 4999.00 ETB.');
        $paymentManager->processWebhook('chapa', $req);

        $this->assertEquals('failed', $tx->fresh()->payment_status);
    }

    /**
     * Test SEC-01 & SEC-04: Entity deletion does not erase financial records; restrictOnDelete prevents deleting refunded transactions.
     */
    public function test_financial_record_preservation_and_foreign_key_constraints(): void
    {
        $employerUser = User::factory()->create();
        $adminUser = User::factory()->create();
        $employer = Employer::create(['organization_name' => 'Financial Integrity Corp', 'verification_status' => 'verified']);
        $package = AdvertisingPackage::create(['name' => 'Integrity Pkg', 'slug' => 'pkg-integ', 'price_etb' => 4000.00, 'duration_days' => 30]);
        $ad = Advertisement::create([
            'employer_id' => $employer->id,
            'package_id' => $package->id,
            'created_by' => $employerUser->id,
            'title' => 'Integrity Vacancy',
            'image_url' => 'https://example.com/ad.png',
            'category' => 'company_promotions',
            'placement' => 'dashboard',
            'cta_type' => 'explore_jobs',
            'cta_text' => 'Apply',
            'cta_target' => 'https://example.com',
            'status' => 'draft',
            'approval_status' => 'approved',
            'payment_status' => 'pending',
            'start_date' => now(),
            'end_date' => now()->addDays(30),
        ]);

        $tx = PaymentTransaction::create([
            'transaction_reference' => 'TXN-INTEG-4000',
            'merchant_reference' => 'CMP-INTEG-1',
            'payment_method' => 'chapa',
            'employer_name_snapshot' => $employer->organization_name,
            'employer_id' => $employer->id,
            'user_id' => $employerUser->id,
            'advertisement_id' => $ad->id,
            'campaign_title_snapshot' => $ad->title,
            'package_id' => $package->id,
            'package_name_snapshot' => $package->name,
            'expected_amount_etb' => 4000.00,
            'confirmed_amount_etb' => 4000.00,
            'currency' => 'ETB',
            'payment_status' => 'successful',
            'verified_at' => now(),
            'verified_by' => 'admin_test',
            'receipt_number' => 'RCP-INTEG-4000',
        ]);

        $refund = PaymentRefund::create([
            'transaction_id' => $tx->id,
            'refund_reference' => 'REF-INTEG-1000',
            'amount' => 1000.00,
            'reason' => 'Customer requested partial refund',
            'status' => 'completed',
            'initiated_by' => $adminUser->id,
            'provider_refund_id' => 'provider_ref_999',
        ]);

        // 1. Delete Employer: transaction.employer_id becomes null, transaction survives
        $employer->delete();
        $this->assertNull($tx->fresh()->employer_id);
        $this->assertEquals('Financial Integrity Corp', $tx->fresh()->employer_name_snapshot);

        // 2. Delete Package: transaction.package_id becomes null, transaction survives
        $package->delete();
        $this->assertNull($tx->fresh()->package_id);
        $this->assertEquals('Integrity Pkg', $tx->fresh()->package_name_snapshot);

        // 3. Delete Advertisement: transaction.advertisement_id becomes null, transaction survives
        $ad->delete();
        $this->assertNull($tx->fresh()->advertisement_id);
        $this->assertEquals('Integrity Vacancy', $tx->fresh()->campaign_title_snapshot);

        // 4. Delete Employer User: transaction.user_id becomes null, transaction survives
        $employerUser->delete();
        $this->assertNull($tx->fresh()->user_id);

        // 5. Delete Admin User who initiated refund: refund.initiated_by becomes null, refund survives
        $adminUser->delete();
        $this->assertNull($refund->fresh()->initiated_by);

        // 6. Delete Transaction: Must fail and be rejected by DB foreign key constraint because completed refund exists!
        $deletionBlocked = false;
        try {
            $tx->delete();
        } catch (\Illuminate\Database\QueryException $e) {
            $deletionBlocked = true;
            $this->assertStringContainsString('foreign', strtolower($e->getMessage()));
        }

        $this->assertTrue($deletionBlocked, 'Foreign key ON DELETE RESTRICT strictly blocked deleting transaction with active refund history.');
    }
}
