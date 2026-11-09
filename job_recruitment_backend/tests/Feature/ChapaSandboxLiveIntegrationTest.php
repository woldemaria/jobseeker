<?php

namespace Tests\Feature;

use App\Models\Advertisement;
use App\Models\AdvertisingPackage;
use App\Models\Employer;
use App\Models\PaymentTransaction;
use App\Models\Role;
use App\Models\User;
use App\Services\Payment\ChapaPaymentGateway;
use App\Services\Payment\PaymentManagerService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class ChapaSandboxLiveIntegrationTest extends TestCase
{
    use RefreshDatabase;

    protected User $employerUser;
    protected Employer $employer;
    protected AdvertisingPackage $package;
    protected Advertisement $ad;

    protected function setUp(): void
    {
        parent::setUp();

        Role::firstOrCreate(['name' => 'JobSeeker'], ['description' => 'Job Seeker']);
        Role::firstOrCreate(['name' => 'Employer'], ['description' => 'Employer']);
        Role::firstOrCreate(['name' => 'Admin'], ['description' => 'Admin']);

        $this->employerUser = User::factory()->create([
            'email' => 'employer_sandbox@example.com',
            'name' => 'Chapa Sandbox Tester',
        ]);

        $this->employer = Employer::create([
            'organization_name' => 'Sandbox Corp Ethiopia',
            'verification_status' => 'verified',
            'phone' => '+251911223344',
        ]);

        $this->package = AdvertisingPackage::create([
            'name' => 'Chapa Sandbox Test Package',
            'slug' => 'pkg-sandbox-chapa',
            'price_etb' => 100.00,
            'duration_days' => 7,
            'is_active' => true,
        ]);

        $this->ad = Advertisement::create([
            'employer_id' => $this->employer->id,
            'package_id' => $this->package->id,
            'created_by' => $this->employerUser->id,
            'title' => 'Chapa Sandbox Verified Vacancy',
            'image_url' => 'https://example.com/banner.png',
            'category' => 'company_promotions',
            'placement' => 'dashboard',
            'cta_type' => 'explore_jobs',
            'cta_text' => 'Apply Online',
            'cta_target' => 'https://example.com/jobs/1',
            'status' => 'draft',
            'approval_status' => 'approved',
            'payment_status' => 'pending',
            'start_date' => now(),
            'end_date' => now()->addDays(7),
        ]);
    }

    /**
     * Category A: Verify v2 hosted checkout request payload, minor-units, and headers.
     */
    public function test_v2_hosted_checkout_request_schema_minor_units_and_idempotency_headers(): void
    {
        config(['services.chapa.secret_key' => 'CHASECK_TEST-dummy-valid-prefix']);
        config(['services.chapa.base_url' => 'https://api.chapa.global/v2']);

        $gateway = new ChapaPaymentGateway();
        $this->app->instance(ChapaPaymentGateway::class, $gateway);

        /** @var PaymentManagerService $paymentManager */
        $paymentManager = $this->app->make(PaymentManagerService::class);

        $interceptedRequest = null;
        Http::fake([
            'https://api.chapa.global/v2/payments/hosted' => function ($request) use (&$interceptedRequest) {
                $interceptedRequest = $request;
                return Http::response([
                    'status' => 'success',
                    'message' => 'Hosted checkout session created',
                    'data' => [
                        'checkout_url' => 'https://checkout.chapa.co/checkout/payment/sandbox_chapa_test_token',
                        'chapa_reference' => 'CH_SANDBOX_REF_12345',
                        'merchant_reference' => $request['merchant_reference'] ?? 'CMP-TEST',
                    ],
                ], 200);
            },
        ]);

        $transaction = $paymentManager->initiateCampaignPayment(
            $this->ad,
            $this->employerUser,
            'chapa',
            ['name' => 'Abebe Kebede', 'email' => 'abebe@example.com', 'phone' => '+251911000000']
        );

        // 1. Verify transaction state
        $this->assertNotNull($transaction);
        $this->assertEquals('pending', $transaction->payment_status);
        $this->assertEquals('https://checkout.chapa.co/checkout/payment/sandbox_chapa_test_token', $transaction->checkout_url);
        $this->assertEquals('CH_SANDBOX_REF_12345', $transaction->provider_reference);
        $this->assertNotNull($transaction->idempotency_key);
        $this->assertStringStartsWith('IDEM-', $transaction->idempotency_key);

        // 2. Verify intercepted request sent to Chapa v2
        $this->assertNotNull($interceptedRequest);
        $this->assertEquals('Bearer CHASECK_TEST-dummy-valid-prefix', $interceptedRequest->header('Authorization')[0]);
        $this->assertEquals($transaction->idempotency_key, $interceptedRequest->header('Idempotency-Key')[0]);

        $payload = $interceptedRequest->data();

        // Amount must be integer minor-units: 100.00 ETB = 10000 minor units
        $this->assertSame(10000, $payload['amount']);
        $this->assertEquals('ETB', $payload['currency']);

        // Merchant reference must be <= 20 characters
        $this->assertLessThanOrEqual(20, strlen($payload['merchant_reference']));
        $this->assertEquals($transaction->merchant_reference, $payload['merchant_reference']);

        // Customer details
        $this->assertEquals('Abebe', $payload['customer']['first_name']);
        $this->assertEquals('Kebede', $payload['customer']['last_name']);
        $this->assertEquals('abebe@example.com', $payload['customer']['email']);
    }

    /**
     * Category A: Verify v2 server-side verification does not activate when status is PENDING.
     */
    public function test_v2_verification_rejects_pending_status_without_activation(): void
    {
        config(['services.chapa.secret_key' => 'CHASECK_TEST-dummy-valid-prefix']);
        config(['services.chapa.base_url' => 'https://api.chapa.global/v2']);

        $gateway = new ChapaPaymentGateway();
        $this->app->instance(ChapaPaymentGateway::class, $gateway);

        $tx = PaymentTransaction::create([
            'transaction_reference' => 'TXN-CHAPA-V2-PEND-001',
            'merchant_reference' => 'CMP-V2-PEND',
            'provider_reference' => 'CH_REF_PEND_111',
            'payment_method' => 'chapa',
            'employer_name_snapshot' => $this->employer->organization_name,
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'advertisement_id' => $this->ad->id,
            'campaign_title_snapshot' => $this->ad->title,
            'package_id' => $this->package->id,
            'package_name_snapshot' => $this->package->name,
            'expected_amount_etb' => 100.00,
            'currency' => 'ETB',
            'payment_status' => 'pending',
        ]);

        Http::fake([
            'https://api.chapa.global/v2/payments/CH_REF_PEND_111/verify' => Http::response([
                'status' => 'success',
                'message' => 'Query OK',
                'data' => [
                    'status' => 'PENDING',
                    'amount' => 10000,
                    'currency' => 'ETB',
                    'chapa_reference' => 'CH_REF_PEND_111',
                ],
            ], 200),
        ]);

        /** @var PaymentManagerService $paymentManager */
        $paymentManager = $this->app->make(PaymentManagerService::class);
        $res = $paymentManager->verifyPayment($tx->transaction_reference);

        $this->assertEquals('pending', $res->payment_status);
        $this->assertEquals('pending', $this->ad->fresh()->payment_status);
        $this->assertNotEquals('active', $this->ad->fresh()->status);
    }

    /**
     * Category A: Verify v2 server-side verification activates campaign upon SUCCESS with minor-units reconciliation.
     */
    public function test_v2_verification_requires_uppercase_success_status_and_reconciles_minor_units(): void
    {
        config(['services.chapa.secret_key' => 'CHASECK_TEST-dummy-valid-prefix']);
        config(['services.chapa.base_url' => 'https://api.chapa.global/v2']);

        $gateway = new ChapaPaymentGateway();
        $this->app->instance(ChapaPaymentGateway::class, $gateway);

        $tx = PaymentTransaction::create([
            'transaction_reference' => 'TXN-CHAPA-V2-VERIFY-001',
            'merchant_reference' => 'CMP-V2-001',
            'provider_reference' => 'CH_REF_VERIFY_999',
            'payment_method' => 'chapa',
            'employer_name_snapshot' => $this->employer->organization_name,
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'advertisement_id' => $this->ad->id,
            'campaign_title_snapshot' => $this->ad->title,
            'package_id' => $this->package->id,
            'package_name_snapshot' => $this->package->name,
            'expected_amount_etb' => 100.00,
            'currency' => 'ETB',
            'payment_status' => 'pending',
        ]);

        Http::fake([
            'https://api.chapa.global/v2/payments/CH_REF_VERIFY_999/verify' => Http::response([
                'status' => 'success',
                'message' => 'Payment verified successfully',
                'data' => [
                    'status' => 'SUCCESS',
                    'amount' => 10000,
                    'currency' => 'ETB',
                    'chapa_reference' => 'CH_REF_VERIFY_999',
                    'merchant_reference' => 'CMP-V2-001',
                ],
            ], 200),
        ]);

        /** @var PaymentManagerService $paymentManager */
        $paymentManager = $this->app->make(PaymentManagerService::class);
        $successTx = $paymentManager->verifyPayment($tx->transaction_reference);

        $this->assertEquals('successful', $successTx->payment_status);
        $this->assertEquals(100.00, (float) $successTx->confirmed_amount_etb);
        $this->assertNotNull($successTx->receipt_number);
        $this->assertEquals('paid', $this->ad->fresh()->payment_status);
        $this->assertEquals('active', $this->ad->fresh()->status);
    }

    /**
     * Category B: Real Chapa Sandbox HTTP integration test (Non-mocked).
     * Strictly verifies live HTTP communication with api.chapa.global when valid key is present.
     */
    public function test_real_chapa_sandbox_hosted_checkout_live_network_call(): void
    {
        $realKey = env('CHAPA_SECRET_KEY');

        // Fail-closed guard: If real sandbox credentials are not set, report BLOCKED
        if (empty($realKey) || !str_starts_with($realKey, 'CHASECK_TEST-') || str_contains($realKey, 'xxxx')) {
            $this->markTestSkipped('BLOCKED: Real Chapa Sandbox secret key (CHASECK_TEST-...) is not configured in .env. Real HTTP network test safely skipped to avoid fake simulation.');
        }

        // NO Http::fake() here! Real network call to api.chapa.global/v2
        $gateway = new ChapaPaymentGateway();
        $this->app->instance(ChapaPaymentGateway::class, $gateway);

        /** @var PaymentManagerService $paymentManager */
        $paymentManager = $this->app->make(PaymentManagerService::class);

        $tx = $paymentManager->initiateCampaignPayment(
            $this->ad,
            $this->employerUser,
            'chapa',
            [
                'name' => 'Live Sandbox Advertiser',
                'email' => 'sandbox_test@chapa.co',
                'phone' => '+251911000000',
            ]
        );

        $this->assertNotNull($tx->checkout_url);
        $this->assertStringContainsString('checkout.chapa.co', $tx->checkout_url);
        $this->assertNotNull($tx->provider_reference);
    }
}
