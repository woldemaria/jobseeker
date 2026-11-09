<?php

namespace App\Services\Payment;

use App\Models\Advertisement;
use App\Models\AuditLog;
use App\Models\PaymentRefund;
use App\Models\PaymentTransaction;
use App\Models\PaymentWebhookEvent;
use App\Models\User;
use Exception;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class PaymentManagerService
{
    /** @var array<string, PaymentGatewayInterface> */
    protected array $gateways = [];

    public function __construct(
        ChapaPaymentGateway $chapa,
        TelebirrPaymentGateway $telebirr,
        CbeBirrPaymentGateway $cbe
    ) {
        $this->gateways['chapa'] = $chapa;
        $this->gateways['telebirr'] = $telebirr;
        $this->gateways['cbe_birr'] = $cbe;
    }

    /**
     * Get all registered gateway adapters.
     *
     * @return array<string, PaymentGatewayInterface>
     */
    public function getGateways(): array
    {
        return $this->gateways;
    }

    /**
     * Get a specific gateway by its key.
     */
    public function getGateway(string $provider): PaymentGatewayInterface
    {
        $provider = strtolower($provider);
        if (!isset($this->gateways[$provider])) {
            throw new Exception("Unsupported payment provider: {$provider}");
        }
        return $this->gateways[$provider];
    }

    /**
     * Return information and configuration status for all providers.
     */
    public function getAvailablePaymentMethods(): array
    {
        $methods = [];
        foreach ($this->gateways as $key => $gateway) {
            $methods[$key] = $gateway->getConfigurationStatus();
        }
        return $methods;
    }

    /**
     * Initiate payment for an advertisement campaign.
     */
    public function initiateCampaignPayment(
        Advertisement $advertisement,
        User $user,
        string $paymentMethod,
        array $customerData = []
    ): PaymentTransaction {
        $gateway = $this->getGateway($paymentMethod);

        if (!$gateway->isConfigured()) {
            $status = $gateway->getConfigurationStatus();
            throw new Exception($status['status_message'] ?? "Payment provider {$paymentMethod} is not currently configured.");
        }

        $package = $advertisement->package;
        if (!$package) {
            throw new Exception('Cannot initiate payment: Campaign does not have an associated advertising package.');
        }

        $priceEtb = (float) $package->price_etb;
        if ($priceEtb <= 0) {
            throw new Exception('This campaign package is free and does not require payment processing.');
        }

        // Generate unique references
        $timestamp = date('YmdHis');
        $random = strtoupper(Str::random(6));
        $txRef = "TXN-" . strtoupper($paymentMethod) . "-{$timestamp}-{$random}";
        // Chapa v2 strictly requires merchant_reference to be <= 20 characters
        $adId = (string) $advertisement->id;
        $maxRandLen = max(2, min(6, 20 - strlen("CMP-{$adId}-")));
        $merchantRef = substr("CMP-{$adId}-" . strtoupper(Str::random($maxRandLen)), 0, 20);
        $idempotencyKey = "IDEM-" . substr(hash('sha256', "{$txRef}-{$merchantRef}"), 0, 32);

        // Use customer data or fallback to authenticated user
        $customerInfo = [
            'name' => $customerData['name'] ?? ($user->full_name ?? $user->name ?? 'Advertiser'),
            'email' => $customerData['email'] ?? $user->email,
            'phone' => $customerData['phone'] ?? $advertisement->employer->phone ?? null,
        ];

        return DB::transaction(function () use ($advertisement, $user, $package, $paymentMethod, $txRef, $merchantRef, $idempotencyKey, $priceEtb, $customerInfo, $gateway) {
            $transaction = PaymentTransaction::create([
                'transaction_reference' => $txRef,
                'merchant_reference' => $merchantRef,
                'idempotency_key' => $idempotencyKey,
                'payment_method' => $paymentMethod,
                'employer_name_snapshot' => $advertisement->employer->organization_name ?? 'Unknown Employer',
                'employer_id' => $advertisement->employer_id,
                'user_id' => $user->id,
                'advertisement_id' => $advertisement->id,
                'campaign_title_snapshot' => $advertisement->title,
                'package_id' => $package->id,
                'package_name_snapshot' => $package->name,
                'expected_amount_etb' => $priceEtb,
                'currency' => 'ETB',
                'payment_status' => 'pending',
                'payment_metadata' => [
                    'idempotency_key' => $idempotencyKey,
                    'campaign_title' => $advertisement->title,
                    'package_name' => $package->name,
                    'customer_email' => $customerInfo['email'],
                ],
            ]);

            try {
                $checkoutResult = $gateway->initializeCheckout($transaction, $customerInfo);

                $transaction->update([
                    'checkout_url' => $checkoutResult['checkout_url'] ?? null,
                    'provider_reference' => $checkoutResult['provider_reference'] ?? null,
                    'payment_metadata' => array_merge(
                        $transaction->payment_metadata ?? [],
                        ['init_response' => $checkoutResult['raw_response'] ?? []]
                    ),
                ]);

                // Create audit log entry
                AuditLog::create([
                    'user_id' => $user->id,
                    'action' => 'PAYMENT_INITIATED',
                    'entity_type' => 'PaymentTransaction',
                    'entity_id' => $transaction->id,
                    'old_values' => null,
                    'new_values' => [
                        'tx_ref' => $txRef,
                        'amount' => $priceEtb,
                        'provider' => $paymentMethod,
                        'advertisement_id' => $advertisement->id,
                    ],
                    'ip_address' => request()->ip(),
                    'user_agent' => request()->userAgent(),
                ]);

                return $transaction;
            } catch (Exception $e) {
                $transaction->update([
                    'payment_status' => 'failed',
                    'failure_reason' => 'Initialization failed: ' . $e->getMessage(),
                ]);
                throw $e;
            }
        });
    }

    /**
     * Compare two financial amounts in ETB using integer minor units (cents)
     * to guarantee strict decimal safety without requiring the bcmath extension.
     *
     * @return int 0 if equal, 1 if A > B, -1 if A < B
     */
    public function compareEtbAmounts(float|string $amountA, float|string $amountB): int
    {
        $centsA = (int) round(((float) $amountA) * 100);
        $centsB = (int) round(((float) $amountB) * 100);

        if ($centsA > $centsB) {
            return 1;
        } elseif ($centsA < $centsB) {
            return -1;
        }
        return 0;
    }

    /**
     * Server-side verify payment status directly with the provider.
     */
    public function verifyPayment(string $transactionReference, ?string $verifiedBy = null): PaymentTransaction
    {
        $transaction = PaymentTransaction::where('transaction_reference', $transactionReference)
            ->with(['advertisement', 'package', 'employer'])
            ->firstOrFail();

        // If already successful, return idempotent response
        if ($transaction->isSuccessful()) {
            return $transaction;
        }

        $gateway = $this->getGateway($transaction->payment_method);
        $result = $gateway->verifyTransaction($transaction);

        if (($result['status'] ?? '') === 'successful') {
            $verifiedAmount = (float) ($result['amount'] ?? 0);
            $verifiedCurrency = strtoupper($result['currency'] ?? 'ETB');

            if ($verifiedCurrency !== strtoupper($transaction->currency)) {
                $msg = "Currency mismatch on transaction {$transactionReference}: expected {$transaction->currency}, got {$verifiedCurrency}.";
                $transaction->update(['payment_status' => 'failed', 'failure_reason' => $msg]);
                throw new Exception($msg);
            }

            $expectedStr = number_format((float) $transaction->expected_amount_etb, 2, '.', '');
            $verifiedStr = number_format($verifiedAmount, 2, '.', '');

            if ($this->compareEtbAmounts($verifiedStr, $expectedStr) !== 0) {
                $msg = "Payment verification amount mismatch on transaction {$transactionReference}: expected {$expectedStr} ETB, verified {$verifiedStr} ETB.";
                $transaction->update(['payment_status' => 'failed', 'failure_reason' => $msg]);
                throw new Exception($msg);
            }

            return $this->markTransactionSuccessful(
                $transaction,
                $verifiedAmount,
                $verifiedBy ?? 'server_verification',
                $result['provider_reference'] ?? null,
                $result['raw_response'] ?? []
            );
        }

        if (($result['status'] ?? '') === 'failed') {
            $transaction->update([
                'payment_status' => 'failed',
                'failure_reason' => $result['raw_response']['message'] ?? 'Provider reported transaction failure.',
            ]);
        }

        return $transaction;
    }

    /**
     * Process an incoming webhook notification idempotently.
     */
    public function processWebhook(string $provider, Request $request): array
    {
        $gateway = $this->getGateway($provider);

        // Verify cryptographic signature
        if (!$gateway->verifyWebhookSignature($request)) {
            Log::warning("Unauthorized webhook received for provider: {$provider}", [
                'headers' => $request->headers->all(),
                'ip' => $request->ip(),
            ]);
            throw new Exception("Invalid or missing webhook signature for {$provider}.");
        }

        $parsed = $gateway->extractWebhookPayload($request);
        $eventId = $parsed['event_id'];
        $txRef = $parsed['transaction_reference'];

        // SEC-06: Provider-scoped idempotency check.
        // Wrapped in a DB transaction with a pessimistic row lock so two concurrent
        // deliveries of the same event are serialized: only one may process, the
        // other sees the committed 'processed' flag and short-circuits as duplicate.
        $pendingException = null;

        $result = DB::transaction(function () use ($provider, $request, $parsed, &$pendingException) {
            $eventId = $parsed['event_id'];
            $txRef = $parsed['transaction_reference'];

            $existingEvent = PaymentWebhookEvent::where('provider', $provider)
                ->where('event_id', $eventId)
                ->lockForUpdate()
                ->first();

            if ($existingEvent && $existingEvent->processed) {
                return [
                    'status' => 'duplicate',
                    'message' => 'Event already processed idempotently.',
                    'event_id' => $eventId,
                    'provider' => $provider,
                ];
            }

            try {
                $webhookRecord = $existingEvent ?? PaymentWebhookEvent::create([
                    'provider' => $provider,
                    'event_id' => $eventId,
                    'transaction_reference' => $txRef,
                    'payload' => $parsed['raw_payload'],
                    'signature' => $request->header('x-chapa-signature') ?? $request->header('X-CBE-Signature') ?? 'verified',
                    'processed' => false,
                ]);
            } catch (\Illuminate\Database\UniqueConstraintViolationException $e) {
                // A concurrent delivery inserted the same (provider, event_id) row
                // while we waited for the lock. Re-read it under lock and join it.
                $webhookRecord = PaymentWebhookEvent::where('provider', $provider)
                    ->where('event_id', $eventId)
                    ->lockForUpdate()
                    ->first();

                if (!$webhookRecord) {
                    throw $e;
                }

                if ($webhookRecord->processed) {
                    return [
                        'status' => 'duplicate',
                        'message' => 'Event already processed idempotently.',
                        'event_id' => $eventId,
                        'provider' => $provider,
                    ];
                }
            }

            if (!$txRef) {
                $webhookRecord->update(['processing_notes' => 'No transaction reference in payload.']);
                return ['status' => 'ignored', 'message' => 'Missing transaction reference'];
            }

            $transaction = PaymentTransaction::where('transaction_reference', $txRef)->lockForUpdate()->first();
            if (!$transaction) {
                $webhookRecord->update(['processing_notes' => "Transaction reference {$txRef} not found in database."]);
                return ['status' => 'not_found', 'message' => "Transaction {$txRef} not found."];
            }

            if ($parsed['status'] === 'successful') {
                // SEC-03: Currency and decimal-safe amount validation
                $receivedCurrency = strtoupper($parsed['currency'] ?? 'ETB');
                if ($receivedCurrency !== strtoupper($transaction->currency)) {
                    $msg = "Currency mismatch on transaction {$txRef}: expected {$transaction->currency}, received {$receivedCurrency}.";
                    Log::warning($msg);
                    $webhookRecord->update(['processing_notes' => $msg]);
                    $transaction->update(['payment_status' => 'failed', 'failure_reason' => $msg]);
                    // Deferred so the failure bookkeeping above commits instead of rolling back.
                    $pendingException = new Exception($msg);
                    return ['status' => 'failed_validation', 'transaction_reference' => $txRef];
                }

                $expectedAmountStr = number_format((float) $transaction->expected_amount_etb, 2, '.', '');
                $receivedAmountStr = number_format((float) $parsed['amount'], 2, '.', '');

                if ($this->compareEtbAmounts($receivedAmountStr, $expectedAmountStr) !== 0) {
                    $msg = "Payment amount mismatch on transaction {$txRef}: expected {$expectedAmountStr} ETB, received {$receivedAmountStr} ETB.";
                    Log::warning($msg, [
                        'transaction' => $txRef,
                        'expected' => $expectedAmountStr,
                        'received' => $receivedAmountStr,
                    ]);
                    $webhookRecord->update(['processing_notes' => $msg]);
                    $transaction->update(['payment_status' => 'failed', 'failure_reason' => $msg]);
                    $pendingException = new Exception($msg);
                    return ['status' => 'failed_validation', 'transaction_reference' => $txRef];
                }

                $this->markTransactionSuccessful(
                    $transaction,
                    (float) $expectedAmountStr,
                    "webhook:{$provider}",
                    $parsed['raw_payload']['reference'] ?? null,
                    $parsed['raw_payload']
                );
                $webhookRecord->update([
                    'processed' => true,
                    'processing_notes' => 'Transaction marked successful via signed webhook after amount verification.',
                ]);
            } elseif (in_array($parsed['status'], ['failed', 'cancelled'])) {
                $transaction->update([
                    'payment_status' => 'failed',
                    'failure_reason' => 'Failed via webhook notification: ' . json_encode($parsed['raw_payload']),
                ]);
                $webhookRecord->update([
                    'processed' => true,
                    'processing_notes' => 'Transaction marked failed via webhook.',
                ]);
            }

            return [
                'status' => 'success',
                'message' => 'Webhook processed successfully.',
                'transaction_reference' => $txRef,
            ];
        });

        if ($pendingException !== null) {
            throw $pendingException;
        }

        return $result;
    }

    /**
     * Mark a transaction as successfully paid and bind to advertisement.
     */
    public function markTransactionSuccessful(
        PaymentTransaction $transaction,
        float $confirmedAmount,
        string $verifiedBy,
        ?string $providerReference = null,
        array $metadata = []
    ): PaymentTransaction {
        return DB::transaction(function () use ($transaction, $confirmedAmount, $verifiedBy, $providerReference, $metadata) {
            $receiptNumber = 'RCP-' . date('Ymd') . '-' . strtoupper(Str::random(8));

            $transaction->update([
                'payment_status' => 'successful',
                'confirmed_amount_etb' => $confirmedAmount,
                'verified_at' => now(),
                'verified_by' => $verifiedBy,
                'receipt_number' => $receiptNumber,
                'provider_reference' => $providerReference ?? $transaction->provider_reference,
                'payment_metadata' => array_merge(
                    $transaction->payment_metadata ?? [],
                    ['verification_meta' => $metadata]
                ),
            ]);

            // Update Advertisement campaign payment status
            $advertisement = $transaction->advertisement;
            if ($advertisement) {
                $advertisement->payment_status = 'paid';
                $advertisement->price_paid = $confirmedAmount;

                // ACTIVATION GUARD (SEC-04):
                // Campaign activates ONLY if approved by admin AND not currently suspended/paused/rejected/expired
                if ($advertisement->approval_status === 'approved' && !in_array($advertisement->status, ['paused', 'suspended', 'rejected', 'expired'])) {
                    $durationDays = $transaction->package->duration_days ?? 30;
                    $advertisement->status = 'active';
                    $advertisement->start_date = now();
                    $advertisement->end_date = now()->addDays($durationDays);
                }

                $advertisement->save();
            }

            // Create Audit Log
            AuditLog::create([
                'user_id' => $transaction->user_id,
                'action' => 'PAYMENT_CONFIRMED',
                'entity_type' => 'PaymentTransaction',
                'entity_id' => $transaction->id,
                'old_values' => ['payment_status' => 'pending'],
                'new_values' => [
                    'payment_status' => 'successful',
                    'amount' => $confirmedAmount,
                    'receipt_number' => $receiptNumber,
                    'verified_by' => $verifiedBy,
                ],
                'ip_address' => request()->ip(),
                'user_agent' => request()->userAgent(),
            ]);

            return $transaction;
        });
    }

    /**
     * Issue an admin-authorized refund.
     */
    public function processRefund(
        PaymentTransaction $transaction,
        User $adminUser,
        float $amount,
        string $reason
    ): PaymentRefund {
        return DB::transaction(function () use ($transaction, $adminUser, $amount, $reason) {
            // SEC-05: Atomic row lock to calculate and reserve refund balance
            $lockedTransaction = PaymentTransaction::where('id', $transaction->id)->lockForUpdate()->firstOrFail();

            if (!$lockedTransaction->canBeRefunded()) {
                throw new Exception('Transaction is not eligible for refund.');
            }

            $remainingRefundable = $lockedTransaction->getRemainingRefundableAmount();
            $amountStr = number_format($amount, 2, '.', '');
            $remainingStr = number_format($remainingRefundable, 2, '.', '');

            if ($amount <= 0 || $this->compareEtbAmounts($amountStr, $remainingStr) > 0) {
                throw new Exception("Refund amount of {$amountStr} ETB exceeds remaining refundable balance of {$remainingStr} ETB.");
            }

            $gateway = $this->getGateway($lockedTransaction->payment_method);
            $refundResult = $gateway->handleRefund($lockedTransaction, $amount, $reason);

            $refundRef = 'REF-' . date('Ymd') . '-' . strtoupper(Str::random(6));

            $refund = PaymentRefund::create([
                'transaction_id' => $lockedTransaction->id,
                'refund_reference' => $refundRef,
                'amount' => $amount,
                'reason' => $reason,
                'status' => $refundResult['success'] ? 'completed' : 'failed',
                'initiated_by' => $adminUser->id,
                'provider_refund_id' => $refundResult['provider_refund_id'] ?? null,
                'metadata' => $refundResult,
            ]);

            if ($refundResult['success']) {
                $newTotalRefunded = (float) $lockedTransaction->refunds()->where('status', 'completed')->sum('amount');
                if ($this->compareEtbAmounts($newTotalRefunded, (float) $lockedTransaction->confirmed_amount_etb) >= 0) {
                    $lockedTransaction->update(['payment_status' => 'refunded']);

                    // Also pause or update campaign
                    if ($lockedTransaction->advertisement) {
                        $lockedTransaction->advertisement->update([
                            'status' => 'paused',
                            'payment_status' => 'unpaid',
                        ]);
                    }
                }

                AuditLog::create([
                    'user_id' => $adminUser->id,
                    'action' => 'PAYMENT_REFUNDED',
                    'entity_type' => 'PaymentRefund',
                    'entity_id' => $refund->id,
                    'old_values' => null,
                    'new_values' => [
                        'transaction_reference' => $lockedTransaction->transaction_reference,
                        'amount' => $amount,
                        'reason' => $reason,
                    ],
                    'ip_address' => request()->ip(),
                    'user_agent' => request()->userAgent(),
                ]);
            } else {
                throw new Exception($refundResult['message'] ?? 'Refund failed via payment provider.');
            }

            return $refund;
        });
    }
}
