<?php

namespace App\Services\Payment;

use App\Models\PaymentTransaction;
use Exception;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class CbeBirrPaymentGateway implements PaymentGatewayInterface
{
    protected ?string $tillNumber;
    protected ?string $appId;
    protected ?string $appSecret;
    protected ?string $publicKey;

    public function __construct()
    {
        $this->tillNumber = config('services.cbe_birr.till_number');
        $this->appId = config('services.cbe_birr.app_id');
        $this->appSecret = config('services.cbe_birr.app_secret');
        $this->publicKey = config('services.cbe_birr.public_key');
    }

    public function getProviderName(): string
    {
        return 'cbe_birr';
    }

    public function getDisplayName(): string
    {
        return 'CBE Birr (Commercial Bank of Ethiopia)';
    }

    public function isConfigured(): bool
    {
        return !empty($this->tillNumber) && !empty($this->appId) && !empty($this->appSecret);
    }

    public function getConfigurationStatus(): array
    {
        $configured = $this->isConfigured();

        return [
            'provider' => 'cbe_birr',
            'display_name' => $this->getDisplayName(),
            'configured' => $configured,
            'currency' => 'ETB',
            'channel' => 'cbe_birr_pgw',
            'status_message' => $configured
                ? 'Commercial Bank of Ethiopia CBE Birr Gateway configured and operational.'
                : 'Pending Commercial Bank of Ethiopia Corporate Merchant Integration',
            'required_credentials' => [
                'CBE_BIRR_TILL_NUMBER' => !empty($this->tillNumber) ? 'Set' : 'Missing',
                'CBE_BIRR_APP_ID' => !empty($this->appId) ? 'Set' : 'Missing',
                'CBE_BIRR_APP_SECRET' => !empty($this->appSecret) ? 'Set' : 'Missing',
                'CBE_BIRR_PUBLIC_KEY' => !empty($this->publicKey) ? 'Set' : 'Missing',
            ],
            'onboarding_checklist' => [
                '1. Open CBE Corporate Merchant Account and execute CBE Birr Payment Gateway Agreement',
                '2. Receive Enterprise Till Number, Application ID and Merchant Secret from CBE FinTech Division',
                '3. Set CBE_BIRR_TILL_NUMBER, CBE_BIRR_APP_ID, and CBE_BIRR_APP_SECRET in backend .env',
                '4. Execute CBE Birr sandbox test transactions and obtain live production certificate',
            ],
        ];
    }

    public function initializeCheckout(PaymentTransaction $transaction, array $customerData): array
    {
        if (!$this->isConfigured()) {
            throw new Exception(
                'CBE Birr payment gateway is currently awaiting commercial merchant agreement configuration. ' .
                'Please use Chapa (which accepts CBE Birr and CBE account transfers) or configure CBE enterprise till credentials.'
            );
        }

        $notifyUrl = route('api.payments.cbe.webhook');

        $cbePayload = [
            'tillNumber' => $this->tillNumber,
            'appId' => $this->appId,
            'billReference' => $transaction->transaction_reference,
            'amount' => number_format((float) $transaction->expected_amount_etb, 2, '.', ''),
            'currency' => 'ETB',
            'customerPhone' => $customerData['phone'] ?? null,
            'notifyUrl' => $notifyUrl,
        ];

        try {
            $response = Http::withHeaders([
                'X-CBE-App-Secret' => $this->appSecret,
                'Content-Type' => 'application/json',
            ])->timeout(20)->post('https://api.cbebirr.cbe.com.et/pgw/v1/checkout/initialize', $cbePayload);

            $result = $response->json();

            if ($response->successful() && isset($result['status']) && strtolower($result['status']) === 'success') {
                return [
                    'checkout_url' => $result['checkoutUrl'] ?? null,
                    'provider_reference' => $result['cbeReference'] ?? $transaction->transaction_reference,
                    'raw_response' => $result,
                ];
            }

            throw new Exception($result['message'] ?? 'Failed to initialize CBE Birr payment.');
        } catch (Exception $e) {
            Log::error('CBE Birr initialization error: ' . $e->getMessage());
            throw $e;
        }
    }

    public function verifyTransaction(PaymentTransaction $transaction): array
    {
        if (!$this->isConfigured()) {
            return [
                'status' => 'unconfigured',
                'message' => 'CBE Birr credentials not configured.',
                'raw_response' => [],
            ];
        }

        try {
            $response = Http::withHeaders([
                'X-CBE-App-Secret' => $this->appSecret,
            ])->timeout(20)->get('https://api.cbebirr.cbe.com.et/pgw/v1/checkout/status/' . $transaction->transaction_reference);

            $result = $response->json();

            if ($response->successful() && isset($result['status']) && strtolower($result['status']) === 'paid') {
                return [
                    'status' => 'successful',
                    'amount' => (float) ($result['amount'] ?? $transaction->expected_amount_etb),
                    'currency' => 'ETB',
                    'provider_reference' => $result['cbeReference'] ?? null,
                    'raw_response' => $result,
                ];
            }

            return [
                'status' => 'pending',
                'amount' => 0.0,
                'currency' => 'ETB',
                'provider_reference' => null,
                'raw_response' => $result ?? [],
            ];
        } catch (Exception $e) {
            Log::error('CBE Birr verification error: ' . $e->getMessage());
            return [
                'status' => 'error',
                'message' => $e->getMessage(),
                'raw_response' => ['error' => $e->getMessage()],
            ];
        }
    }

    public function verifyWebhookSignature(Request $request): bool
    {
        if (!$this->isConfigured()) {
            return false;
        }

        $signature = $request->header('X-CBE-Signature');
        if (empty($signature)) {
            return false;
        }

        $expected = hash_hmac('sha256', $request->getContent(), (string) $this->appSecret);
        return hash_equals($expected, $signature);
    }

    public function extractWebhookPayload(Request $request): array
    {
        $payload = $request->all();

        $txRef = $payload['billReference'] ?? $payload['transactionReference'] ?? null;
        $status = strtolower($payload['paymentStatus'] ?? $payload['status'] ?? 'pending');
        $amount = (float) ($payload['amount'] ?? 0.0);

        return [
            'event_id' => 'cbe_' . ($payload['cbeReference'] ?? $txRef ?? time()),
            'transaction_reference' => $txRef,
            'status' => in_array($status, ['paid', 'success', 'successful']) ? 'successful' : 'pending',
            'amount' => $amount,
            'currency' => 'ETB',
            'raw_payload' => $payload,
        ];
    }

    public function handleRefund(PaymentTransaction $transaction, float $amount, string $reason): array
    {
        return [
            'success' => false,
            'provider_refund_id' => null,
            'message' => 'CBE Birr API does not support automated merchant reversals; contact CBE Corporate Support with the transaction reference.',
        ];
    }
}
