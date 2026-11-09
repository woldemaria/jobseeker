<?php

namespace Tests\Feature;

use App\Models\Advertisement;
use App\Models\AdvertisingPackage;
use App\Models\Employer;
use App\Models\PaymentTransaction;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class PaymentGatewayIntegrationTest extends TestCase
{
    use RefreshDatabase;

    protected User $adminUser;
    protected User $employerUser;
    protected User $otherEmployerUser;
    protected Employer $employer;
    protected Employer $otherEmployer;
    protected AdvertisingPackage $package;
    protected Advertisement $ad;

    protected function setUp(): void
    {
        parent::setUp();

        $adminRole = Role::firstOrCreate(['name' => 'administrator'], ['description' => 'Administrator']);
        $employerRole = Role::firstOrCreate(['name' => 'employer'], ['description' => 'Employer']);

        $this->adminUser = User::factory()->create(['email' => 'admin@jobplatform.et']);
        $this->adminUser->roles()->attach($adminRole->id);

        $this->employerUser = User::factory()->create(['email' => 'tech@ethiojobs.et']);
        $this->employerUser->roles()->attach($employerRole->id);

        $this->otherEmployerUser = User::factory()->create(['email' => 'other@company.et']);
        $this->otherEmployerUser->roles()->attach($employerRole->id);

        $this->employer = Employer::create([
            'organization_name' => 'Ethio Tech Solutions',
            'email' => 'contact@ethiotech.et',
            'phone' => '+251911223344',
            'verification_status' => 'verified',
        ]);
        $this->employer->users()->attach($this->employerUser->id, ['member_role' => 'owner']);

        $this->otherEmployer = Employer::create([
            'organization_name' => 'Competitor Corp',
            'email' => 'info@competitor.et',
            'phone' => '+251922334455',
            'verification_status' => 'verified',
        ]);
        $this->otherEmployer->users()->attach($this->otherEmployerUser->id, ['member_role' => 'owner']);

        $this->package = AdvertisingPackage::create([
            'name' => 'Standard Package',
            'slug' => 'standard-package',
            'description' => '15 Days High-Visibility Featured Campaign',
            'duration_days' => 15,
            'price_etb' => 3500.00,
            'allowed_placements' => ['home_top_banner', 'job_feed_interstitial'],
            'allowed_categories' => ['technology', 'engineering'],
            'is_active' => true,
            'priority_level' => 2,
        ]);

        $this->ad = Advertisement::create([
            'employer_id' => $this->employer->id,
            'package_id' => $this->package->id,
            'created_by' => $this->employerUser->id,
            'title' => 'Senior Flutter Engineer Wanted',
            'image_url' => 'https://example.com/banner.png',
            'cta_type' => 'apply_now',
            'cta_text' => 'Apply Now',
            'cta_target' => '/jobs/1',
            'start_date' => now(),
            'end_date' => now()->addDays(15),
            'description' => 'Join our high performing mobile engineering team.',
            'category' => 'technology',
            'placement' => 'home_top_banner',
            'placements' => ['home_top_banner'],
            'target_locations' => ['Bole'],
            'target_audience' => ['Software Engineers'],
            'status' => 'pending_approval',
            'approval_status' => 'pending_approval',
            'payment_status' => 'unpaid',
            'price_paid' => 0.0,
        ]);

        config([
            'services.chapa.secret_key' => 'CHASECK_TEST-sandboxkeytest12345',
            'services.chapa.webhook_secret' => 'test_webhook_secret_key',
            'services.chapa.base_url' => 'https://api.chapa.global/v2',
        ]);
    }

    public function test_public_can_list_supported_payment_methods(): void
    {
        $response = $this->getJson('/api/v1/payments/methods');

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonStructure([
                'data' => [
                    'chapa' => ['provider', 'display_name', 'configured', 'currency'],
                    'telebirr' => ['provider', 'display_name', 'configured'],
                    'cbe_birr' => ['provider', 'display_name', 'configured'],
                ],
            ]);
    }

    public function test_employer_can_initiate_payment_checkout_via_chapa(): void
    {
        Http::fake([
            'https://api.chapa.global/v2/payments/hosted' => Http::response([
                'status' => 'success',
                'message' => 'Hosted checkout created',
                'data' => [
                    'checkout_url' => 'https://checkout.chapa.co/checkout/payment/mock123456789',
                    'reference' => 'chapa_ref_987654',
                ],
            ], 200),
        ]);

        $response = $this->actingAs($this->employerUser, 'sanctum')->postJson('/api/v1/advertiser/payments/initiate', [
            'advertisement_id' => $this->ad->id,
            'payment_method' => 'chapa',
            'customer_name' => 'Dawit Employer',
            'customer_email' => 'dawit@ethiotech.et',
            'customer_phone' => '+251911223344',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.payment_method', 'chapa')
            ->assertJsonPath('data.payment_status', 'pending')
            ->assertJsonPath('data.expected_amount_etb', 3500)
            ->assertJsonPath('data.checkout_url', 'https://checkout.chapa.co/checkout/payment/mock123456789');

        $this->assertDatabaseHas('payment_transactions', [
            'advertisement_id' => $this->ad->id,
            'payment_method' => 'chapa',
            'payment_status' => 'pending',
            'expected_amount_etb' => 3500.00,
        ]);
    }

    public function test_initiate_payment_rejects_unowned_campaign_idor(): void
    {
        $response = $this->actingAs($this->otherEmployerUser, 'sanctum')->postJson('/api/v1/advertiser/payments/initiate', [
            'advertisement_id' => $this->ad->id,
            'payment_method' => 'chapa',
        ]);

        $response->assertStatus(403);
    }

    public function test_initiate_payment_rejects_already_paid_campaign(): void
    {
        $this->ad->update(['payment_status' => 'paid']);

        $response = $this->actingAs($this->employerUser, 'sanctum')->postJson('/api/v1/advertiser/payments/initiate', [
            'advertisement_id' => $this->ad->id,
            'payment_method' => 'chapa',
        ]);

        $response->assertStatus(422)
            ->assertJsonPath('success', false);
    }

    public function test_server_side_payment_verification_success_and_receipt_generation(): void
    {
        $transaction = PaymentTransaction::create([
            'transaction_reference' => 'TXN-CHAPA-20261108-112233',
            'merchant_reference' => 'CMP-' . $this->ad->id . '-ABC123',
            'payment_method' => 'chapa',
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'advertisement_id' => $this->ad->id,
            'package_id' => $this->package->id,
            'expected_amount_etb' => 3500.00,
            'currency' => 'ETB',
            'payment_status' => 'pending',
        ]);

        Http::fake([
            'https://api.chapa.global/v1/transaction/verify/TXN-CHAPA-20261108-112233' => Http::response([
                'status' => 'success',
                'data' => [
                    'status' => 'success',
                    'amount' => 3500.00,
                    'currency' => 'ETB',
                    'reference' => 'chapa_ref_verified_001',
                ],
            ], 200),
        ]);

        $response = $this->actingAs($this->employerUser, 'sanctum')
            ->getJson('/api/v1/advertiser/payments/verify/' . $transaction->transaction_reference);

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.payment_status', 'successful')
            ->assertJsonPath('data.is_successful', true)
            ->assertJsonPath('data.confirmed_amount_etb', 3500);

        $transaction->refresh();
        $this->assertEquals('successful', $transaction->payment_status);
        $this->assertNotNull($transaction->receipt_number);
        $this->assertStringStartsWith('RCP-', $transaction->receipt_number);

        $this->ad->refresh();
        $this->assertEquals('paid', $this->ad->payment_status);
        $this->assertEquals(3500.00, $this->ad->price_paid);
    }

    public function test_unapproved_campaign_remains_pending_approval_when_paid(): void
    {
        $this->ad->update([
            'approval_status' => 'pending_approval',
            'status' => 'pending_approval',
            'payment_status' => 'unpaid',
        ]);

        $transaction = PaymentTransaction::create([
            'transaction_reference' => 'TXN-CHAPA-UNAPPROVED-001',
            'merchant_reference' => 'CMP-' . $this->ad->id . '-UNAPP',
            'payment_method' => 'chapa',
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'advertisement_id' => $this->ad->id,
            'package_id' => $this->package->id,
            'expected_amount_etb' => 3500.00,
            'currency' => 'ETB',
            'payment_status' => 'pending',
        ]);

        Http::fake([
            'https://api.chapa.global/v1/transaction/verify/*' => Http::response([
                'status' => 'success',
                'data' => [
                    'status' => 'success',
                    'amount' => 3500.00,
                    'currency' => 'ETB',
                ],
            ], 200),
        ]);

        $this->actingAs($this->employerUser, 'sanctum')
            ->getJson('/api/v1/advertiser/payments/verify/' . $transaction->transaction_reference);

        $this->ad->refresh();
        // Payment is paid, but status MUST NOT be active until an administrator approves it!
        $this->assertEquals('paid', $this->ad->payment_status);
        $this->assertEquals('pending_approval', $this->ad->approval_status);
        $this->assertNotEquals('active', $this->ad->status);
    }

    public function test_approved_campaign_activates_upon_payment_success(): void
    {
        $this->ad->update([
            'approval_status' => 'approved',
            'approved_by' => $this->adminUser->id,
            'approved_at' => now(),
            'status' => 'approved', // approved, awaiting payment
            'payment_status' => 'unpaid',
        ]);

        $transaction = PaymentTransaction::create([
            'transaction_reference' => 'TXN-CHAPA-APPROVED-002',
            'merchant_reference' => 'CMP-' . $this->ad->id . '-APP',
            'payment_method' => 'chapa',
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'advertisement_id' => $this->ad->id,
            'package_id' => $this->package->id,
            'expected_amount_etb' => 3500.00,
            'currency' => 'ETB',
            'payment_status' => 'pending',
        ]);

        Http::fake([
            'https://api.chapa.global/v1/transaction/verify/*' => Http::response([
                'status' => 'success',
                'data' => [
                    'status' => 'success',
                    'amount' => 3500.00,
                    'currency' => 'ETB',
                ],
            ], 200),
        ]);

        $this->actingAs($this->employerUser, 'sanctum')
            ->getJson('/api/v1/advertiser/payments/verify/' . $transaction->transaction_reference);

        $this->ad->refresh();
        $this->assertEquals('paid', $this->ad->payment_status);
        $this->assertEquals('active', $this->ad->status);
        $this->assertNotNull($this->ad->start_date);
        $this->assertNotNull($this->ad->end_date);
    }

    public function test_chapa_webhook_processes_valid_signature_idempotently(): void
    {
        $transaction = PaymentTransaction::create([
            'transaction_reference' => 'TXN-CHAPA-WEBHOOK-99',
            'merchant_reference' => 'CMP-' . $this->ad->id . '-WH99',
            'payment_method' => 'chapa',
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'advertisement_id' => $this->ad->id,
            'package_id' => $this->package->id,
            'expected_amount_etb' => 3500.00,
            'currency' => 'ETB',
            'payment_status' => 'pending',
        ]);

        $payload = [
            'event_id' => 'evt_chapa_unique_001',
            'tx_ref' => 'TXN-CHAPA-WEBHOOK-99',
            'status' => 'success',
            'amount' => 3500.00,
            'currency' => 'ETB',
        ];

        $rawBody = json_encode($payload);
        $signature = hash_hmac('sha256', $rawBody, 'test_webhook_secret_key');

        $response = $this->call(
            'POST',
            '/api/v1/payments/chapa/webhook',
            [],
            [],
            [],
            [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_X_CHAPA_SIGNATURE' => $signature,
            ],
            $rawBody
        );

        $response->assertStatus(200)
            ->assertJsonPath('status', 'success');

        $transaction->refresh();
        $this->assertEquals('successful', $transaction->payment_status);

        // Replay same webhook to test idempotency
        $replayResponse = $this->call(
            'POST',
            '/api/v1/payments/chapa/webhook',
            [],
            [],
            [],
            [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_X_CHAPA_SIGNATURE' => $signature,
            ],
            $rawBody
        );

        $replayResponse->assertStatus(200)
            ->assertJsonPath('status', 'duplicate');
    }

    public function test_chapa_webhook_rejects_tampered_or_invalid_signature(): void
    {
        $payload = [
            'event_id' => 'evt_fake_999',
            'tx_ref' => 'TXN-FAKE',
            'status' => 'success',
        ];

        $rawBody = json_encode($payload);

        $response = $this->call(
            'POST',
            '/api/v1/payments/chapa/webhook',
            [],
            [],
            [],
            [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_X_CHAPA_SIGNATURE' => 'invalid_tampered_signature_hex',
            ],
            $rawBody
        );

        $response->assertStatus(400);
    }

    public function test_unconfigured_telebirr_gateway_returns_clear_onboarding_notice(): void
    {
        $methodsResponse = $this->getJson('/api/v1/payments/methods');
        $methodsResponse->assertStatus(200);

        $telebirrData = $methodsResponse->json('data.telebirr');
        $this->assertFalse($telebirrData['configured']);
        $this->assertNotEmpty($telebirrData['onboarding_checklist']);

        // Attempting to initiate with unconfigured Telebirr throws clear descriptive exception
        $response = $this->actingAs($this->employerUser, 'sanctum')->postJson('/api/v1/advertiser/payments/initiate', [
            'advertisement_id' => $this->ad->id,
            'payment_method' => 'telebirr',
        ]);

        $response->assertStatus(400);
    }

    public function test_employer_can_retrieve_transaction_history_and_receipt(): void
    {
        PaymentTransaction::create([
            'transaction_reference' => 'TXN-HISTORY-01',
            'merchant_reference' => 'CMP-HIST-01',
            'payment_method' => 'chapa',
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'advertisement_id' => $this->ad->id,
            'package_id' => $this->package->id,
            'expected_amount_etb' => 3500.00,
            'confirmed_amount_etb' => 3500.00,
            'currency' => 'ETB',
            'payment_status' => 'successful',
            'receipt_number' => 'RCP-20261108-HIST01',
        ]);

        $response = $this->actingAs($this->employerUser, 'sanctum')
            ->getJson('/api/v1/advertiser/payments/transactions');

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonCount(1, 'data.data');

        $detailResponse = $this->actingAs($this->employerUser, 'sanctum')
            ->getJson('/api/v1/advertiser/payments/transactions/TXN-HISTORY-01');

        $detailResponse->assertStatus(200)
            ->assertJsonPath('data.receipt_number', 'RCP-20261108-HIST01');
    }

    public function test_admin_can_review_transactions_and_issue_authorized_refund(): void
    {
        $transaction = PaymentTransaction::create([
            'transaction_reference' => 'TXN-CHAPA-REFUND-01',
            'merchant_reference' => 'CMP-REFUND-01',
            'payment_method' => 'chapa',
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'advertisement_id' => $this->ad->id,
            'package_id' => $this->package->id,
            'expected_amount_etb' => 3500.00,
            'confirmed_amount_etb' => 3500.00,
            'currency' => 'ETB',
            'payment_status' => 'successful',
            'receipt_number' => 'RCP-REFUND-01',
        ]);

        $adminListResponse = $this->actingAs($this->adminUser, 'sanctum')
            ->getJson('/api/v1/admin/payments/transactions');

        $adminListResponse->assertStatus(200)
            ->assertJsonPath('success', true);

        Http::fake([
            'https://api.chapa.global/v1/refund' => Http::response([
                'status' => 'success',
                'message' => 'Refund processed',
                'data' => [
                    'refund_id' => 'chapa_rf_998877',
                ],
            ], 200),
        ]);

        $refundResponse = $this->actingAs($this->adminUser, 'sanctum')
            ->postJson('/api/v1/admin/payments/transactions/' . $transaction->transaction_reference . '/refund', [
                'amount' => 3500.00,
                'reason' => 'Customer requested campaign cancellation before start',
            ]);

        $refundResponse->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status', 'completed');

        $transaction->refresh();
        $this->assertEquals('refunded', $transaction->payment_status);
        $this->assertDatabaseHas('payment_refunds', [
            'transaction_id' => $transaction->id,
            'amount' => 3500.00,
            'status' => 'completed',
        ]);
    }

    /**
     * SEC-01: Financial record preservation when advertisement, employer, or user is deleted.
     */
    public function test_financial_records_preserved_when_advertisement_and_employer_deleted(): void
    {
        $transaction = PaymentTransaction::create([
            'transaction_reference' => 'TXN-AUDIT-IMMUTABLE-01',
            'merchant_reference' => 'CMP-AUDIT-01',
            'payment_method' => 'chapa',
            'employer_name_snapshot' => $this->employer->organization_name,
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'advertisement_id' => $this->ad->id,
            'campaign_title_snapshot' => $this->ad->title,
            'package_id' => $this->package->id,
            'package_name_snapshot' => $this->package->name,
            'expected_amount_etb' => 3500.00,
            'confirmed_amount_etb' => 3500.00,
            'currency' => 'ETB',
            'payment_status' => 'successful',
            'receipt_number' => 'RCP-IMMUTABLE-01',
        ]);

        // Delete the advertisement
        $this->ad->delete();

        // Transaction must NOT be cascade deleted!
        $transaction->refresh();
        $this->assertDatabaseHas('payment_transactions', [
            'id' => $transaction->id,
            'transaction_reference' => 'TXN-AUDIT-IMMUTABLE-01',
            'receipt_number' => 'RCP-IMMUTABLE-01',
            'campaign_title_snapshot' => 'Senior Flutter Engineer Wanted',
            'expected_amount_etb' => 3500.00,
        ]);
        $this->assertNull($transaction->advertisement_id);

        // Delete employer
        $this->employer->delete();

        $transaction->refresh();
        $this->assertDatabaseHas('payment_transactions', [
            'id' => $transaction->id,
            'employer_name_snapshot' => 'Ethio Tech Solutions',
            'receipt_number' => 'RCP-IMMUTABLE-01',
        ]);
        $this->assertNull($transaction->employer_id);
    }

    /**
     * SEC-02: Unconfigured gateway fails closed.
     */
    public function test_unconfigured_gateway_fails_closed(): void
    {
        // Unset secret key
        config(['services.chapa.secret_key' => null]);

        $response = $this->actingAs($this->employerUser, 'sanctum')->postJson('/api/v1/advertiser/payments/initiate', [
            'advertisement_id' => $this->ad->id,
            'payment_method' => 'chapa',
        ]);

        $response->assertStatus(400);

        // Mock string fails closed as well
        config(['services.chapa.secret_key' => 'CHASECK_TEST-mocksecret']);

        $response2 = $this->actingAs($this->employerUser, 'sanctum')->postJson('/api/v1/advertiser/payments/initiate', [
            'advertisement_id' => $this->ad->id,
            'payment_method' => 'chapa',
        ]);

        $response2->assertStatus(400);
    }

    /**
     * SEC-03: Webhook payment amount validation rejects underpayment and mismatch.
     */
    public function test_webhook_rejects_underpayment_and_amount_mismatch(): void
    {
        $transaction = PaymentTransaction::create([
            'transaction_reference' => 'TXN-CHAPA-UNDERPAY-01',
            'merchant_reference' => 'CMP-UNDERPAY-01',
            'payment_method' => 'chapa',
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'advertisement_id' => $this->ad->id,
            'package_id' => $this->package->id,
            'expected_amount_etb' => 3500.00,
            'currency' => 'ETB',
            'payment_status' => 'pending',
        ]);

        // Attacker attempts underpayment: 1.00 ETB instead of 3500.00 ETB
        $payload = [
            'event_id' => 'evt_underpay_1',
            'tx_ref' => 'TXN-CHAPA-UNDERPAY-01',
            'status' => 'success',
            'amount' => 1.00,
            'currency' => 'ETB',
        ];

        $rawBody = json_encode($payload);
        $signature = hash_hmac('sha256', $rawBody, 'test_webhook_secret_key');

        $response = $this->call(
            'POST',
            '/api/v1/payments/chapa/webhook',
            [],
            [],
            [],
            [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_X_CHAPA_SIGNATURE' => $signature,
            ],
            $rawBody
        );

        $response->assertStatus(400);

        $transaction->refresh();
        $this->assertEquals('failed', $transaction->payment_status);
        $this->assertStringContainsString('amount mismatch', strtolower($transaction->failure_reason));

        $this->ad->refresh();
        $this->assertNotEquals('paid', $this->ad->payment_status);
    }

    /**
     * SEC-03: Webhook rejects incorrect currency.
     */
    public function test_webhook_rejects_invalid_currency(): void
    {
        $transaction = PaymentTransaction::create([
            'transaction_reference' => 'TXN-CHAPA-CURR-01',
            'merchant_reference' => 'CMP-CURR-01',
            'payment_method' => 'chapa',
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'advertisement_id' => $this->ad->id,
            'package_id' => $this->package->id,
            'expected_amount_etb' => 3500.00,
            'currency' => 'ETB',
            'payment_status' => 'pending',
        ]);

        $payload = [
            'event_id' => 'evt_curr_1',
            'tx_ref' => 'TXN-CHAPA-CURR-01',
            'status' => 'success',
            'amount' => 3500.00,
            'currency' => 'USD', // Invalid currency
        ];

        $rawBody = json_encode($payload);
        $signature = hash_hmac('sha256', $rawBody, 'test_webhook_secret_key');

        $response = $this->call(
            'POST',
            '/api/v1/payments/chapa/webhook',
            [],
            [],
            [],
            [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_X_CHAPA_SIGNATURE' => $signature,
            ],
            $rawBody
        );

        $response->assertStatus(400);

        $transaction->refresh();
        $this->assertEquals('failed', $transaction->payment_status);
        $this->assertStringContainsString('currency mismatch', strtolower($transaction->failure_reason));
    }

    /**
     * SEC-04: Successful payment must never override administrative suspension.
     */
    public function test_payment_confirmation_never_unpauses_or_overrides_admin_suspended_campaign(): void
    {
        // Admin previously approved, but subsequently suspended/paused the campaign
        $this->ad->update([
            'approval_status' => 'approved',
            'approved_by' => $this->adminUser->id,
            'approved_at' => now(),
            'status' => 'paused', // Administratively suspended/paused!
            'payment_status' => 'unpaid',
        ]);

        $transaction = PaymentTransaction::create([
            'transaction_reference' => 'TXN-SUSPEND-OVERRIDE-GUARD',
            'merchant_reference' => 'CMP-SUSP-01',
            'payment_method' => 'chapa',
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'advertisement_id' => $this->ad->id,
            'package_id' => $this->package->id,
            'expected_amount_etb' => 3500.00,
            'currency' => 'ETB',
            'payment_status' => 'pending',
        ]);

        $payload = [
            'event_id' => 'evt_susp_guard_01',
            'tx_ref' => 'TXN-SUSPEND-OVERRIDE-GUARD',
            'status' => 'success',
            'amount' => 3500.00,
            'currency' => 'ETB',
        ];

        $rawBody = json_encode($payload);
        $signature = hash_hmac('sha256', $rawBody, 'test_webhook_secret_key');

        $response = $this->call(
            'POST',
            '/api/v1/payments/chapa/webhook',
            [],
            [],
            [],
            [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_X_CHAPA_SIGNATURE' => $signature,
            ],
            $rawBody
        );

        $response->assertStatus(200);

        $this->ad->refresh();
        // Payment status becomes paid, but status REMAINS paused!
        $this->assertEquals('paid', $this->ad->payment_status);
        $this->assertEquals('paused', $this->ad->status);
        $this->assertNotEquals('active', $this->ad->status);
    }

    /**
     * SEC-05: Refund exceeding balance is rejected atomically.
     */
    public function test_refund_exceeding_refundable_balance_is_rejected_atomically(): void
    {
        $transaction = PaymentTransaction::create([
            'transaction_reference' => 'TXN-REFUND-LIMIT-01',
            'merchant_reference' => 'CMP-REFLIM-01',
            'payment_method' => 'chapa',
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'advertisement_id' => $this->ad->id,
            'package_id' => $this->package->id,
            'expected_amount_etb' => 3500.00,
            'confirmed_amount_etb' => 3500.00,
            'currency' => 'ETB',
            'payment_status' => 'successful',
            'receipt_number' => 'RCP-REFLIM-01',
        ]);

        // Attempt to refund 5000 ETB when confirmed amount is 3500 ETB
        $response = $this->actingAs($this->adminUser, 'sanctum')
            ->postJson('/api/v1/admin/payments/transactions/' . $transaction->transaction_reference . '/refund', [
                'amount' => 5000.00,
                'reason' => 'Excessive refund requested',
            ]);

        $response->assertStatus(400);

        $transaction->refresh();
        $this->assertEquals('successful', $transaction->payment_status);
        $this->assertDatabaseMissing('payment_refunds', [
            'transaction_id' => $transaction->id,
        ]);
    }

    /**
     * SEC-05: Partial refunds are tracked and prevent overdraft.
     */
    public function test_partial_refunds_tracked_and_prevent_overdraft(): void
    {
        $transaction = PaymentTransaction::create([
            'transaction_reference' => 'TXN-PARTIAL-REFUND-01',
            'merchant_reference' => 'CMP-PARTIAL-01',
            'payment_method' => 'chapa',
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'advertisement_id' => $this->ad->id,
            'package_id' => $this->package->id,
            'expected_amount_etb' => 3500.00,
            'confirmed_amount_etb' => 3500.00,
            'currency' => 'ETB',
            'payment_status' => 'successful',
            'receipt_number' => 'RCP-PARTIAL-01',
        ]);

        Http::fake([
            'https://api.chapa.global/v1/refund' => Http::response([
                'status' => 'success',
                'data' => ['refund_id' => 'chapa_rf_partial'],
            ], 200),
        ]);

        // 1st Partial refund: 2000 ETB
        $resp1 = $this->actingAs($this->adminUser, 'sanctum')
            ->postJson('/api/v1/admin/payments/transactions/' . $transaction->transaction_reference . '/refund', [
                'amount' => 2000.00,
                'reason' => 'First partial refund',
            ]);
        $resp1->assertStatus(200);

        $transaction->refresh();
        $this->assertEquals('successful', $transaction->payment_status);
        $this->assertEquals(1500.00, $transaction->getRemainingRefundableAmount());

        // 2nd Partial refund attempt: 2000 ETB (exceeds remaining 1500 ETB)
        $resp2 = $this->actingAs($this->adminUser, 'sanctum')
            ->postJson('/api/v1/admin/payments/transactions/' . $transaction->transaction_reference . '/refund', [
                'amount' => 2000.00,
                'reason' => 'Second excessive refund',
            ]);
        $resp2->assertStatus(400);

        // 3rd Partial refund: exactly remaining 1500 ETB
        $resp3 = $this->actingAs($this->adminUser, 'sanctum')
            ->postJson('/api/v1/admin/payments/transactions/' . $transaction->transaction_reference . '/refund', [
                'amount' => 1500.00,
                'reason' => 'Final remaining refund',
            ]);
        $resp3->assertStatus(200);

        $transaction->refresh();
        $this->assertEquals('refunded', $transaction->payment_status);
        $this->assertEquals(0.0, $transaction->getRemainingRefundableAmount());
    }

    /**
     * SEC-06: Provider-scoped webhook compound uniqueness.
     */
    public function test_compound_webhook_uniqueness_allows_same_event_id_across_different_providers(): void
    {
        $tx1 = PaymentTransaction::create([
            'transaction_reference' => 'TXN-CHAPA-EVENT-01',
            'merchant_reference' => 'CMP-EVT-01',
            'payment_method' => 'chapa',
            'employer_id' => $this->employer->id,
            'user_id' => $this->employerUser->id,
            'advertisement_id' => $this->ad->id,
            'package_id' => $this->package->id,
            'expected_amount_etb' => 3500.00,
            'currency' => 'ETB',
            'payment_status' => 'pending',
        ]);

        $payload = [
            'event_id' => 'COMMON_EVENT_ID_999',
            'tx_ref' => 'TXN-CHAPA-EVENT-01',
            'status' => 'success',
            'amount' => 3500.00,
            'currency' => 'ETB',
        ];

        $rawBody = json_encode($payload);
        $signature = hash_hmac('sha256', $rawBody, 'test_webhook_secret_key');

        $respChapa = $this->call(
            'POST',
            '/api/v1/payments/chapa/webhook',
            [],
            [],
            [],
            [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_X_CHAPA_SIGNATURE' => $signature,
            ],
            $rawBody
        );

        $respChapa->assertStatus(200);

        // Second provider (telebirr) can record event with the SAME event_id without unique constraint collision!
        $eventTelebirr = \App\Models\PaymentWebhookEvent::create([
            'provider' => 'telebirr',
            'event_id' => 'COMMON_EVENT_ID_999',
            'transaction_reference' => 'TXN-OTHER',
            'payload' => ['sample' => 'data'],
            'processed' => true,
        ]);

        $this->assertNotNull($eventTelebirr->id);
        $this->assertEquals(2, \App\Models\PaymentWebhookEvent::where('event_id', 'COMMON_EVENT_ID_999')->count());
    }
}
