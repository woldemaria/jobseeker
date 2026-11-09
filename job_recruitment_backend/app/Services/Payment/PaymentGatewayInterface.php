<?php

namespace App\Services\Payment;

use App\Models\PaymentTransaction;
use Illuminate\Http\Request;

interface PaymentGatewayInterface
{
    /**
     * Return provider system identifier (e.g., 'chapa', 'telebirr', 'cbe_birr').
     */
    public function getProviderName(): string;

    /**
     * Return human-readable display name.
     */
    public function getDisplayName(): string;

    /**
     * Check if provider credentials and configuration are fully configured and ready for live processing.
     */
    public function isConfigured(): bool;

    /**
     * Get provider availability and configuration metadata.
     */
    public function getConfigurationStatus(): array;

    /**
     * Initialize server-side checkout for a pending transaction.
     *
     * @param PaymentTransaction $transaction
     * @param array $customerData ['email' => string, 'name' => string, 'phone' => ?string]
     * @return array ['checkout_url' => string, 'provider_reference' => ?string, 'raw_response' => array]
     */
    public function initializeCheckout(PaymentTransaction $transaction, array $customerData): array;

    /**
     * Verify transaction status directly with payment provider.
     *
     * @param PaymentTransaction $transaction
     * @return array ['status' => string, 'amount' => float, 'currency' => string, 'raw_response' => array]
     */
    public function verifyTransaction(PaymentTransaction $transaction): array;

    /**
     * Verify authenticity of incoming webhook request.
     */
    public function verifyWebhookSignature(Request $request): bool;

    /**
     * Parse webhook payload and extract transaction reference and status.
     *
     * @param Request $request
     * @return array ['event_id' => string, 'transaction_reference' => string, 'status' => string, 'amount' => float, 'currency' => string, 'raw_payload' => array]
     */
    public function extractWebhookPayload(Request $request): array;

    /**
     * Issue refund where supported by provider API.
     *
     * @param PaymentTransaction $transaction
     * @param float $amount
     * @param string $reason
     * @return array ['success' => bool, 'provider_refund_id' => ?string, 'message' => string]
     */
    public function handleRefund(PaymentTransaction $transaction, float $amount, string $reason): array;
}
