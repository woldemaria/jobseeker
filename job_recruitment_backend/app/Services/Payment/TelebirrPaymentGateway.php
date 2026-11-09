<?php

namespace App\Services\Payment;

use App\Models\PaymentTransaction;
use Exception;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class TelebirrPaymentGateway implements PaymentGatewayInterface
{
    protected ?string $appId;
    protected ?string $appKey;
    protected ?string $shortCode;
    protected ?string $publicKey;
    protected ?string $privateKey;

    public function __construct()
    {
        $this->appId = config('services.telebirr.app_id');
        $this->appKey = config('services.telebirr.app_key');
        $this->shortCode = config('services.telebirr.short_code');
        $this->publicKey = config('services.telebirr.public_key');
        $this->privateKey = config('services.telebirr.private_key');
    }

    public function getProviderName(): string
    {
        return 'telebirr';
    }

    public function getDisplayName(): string
    {
        return 'Telebirr (Ethio Telecom Mobile Money)';
    }

    public function isConfigured(): bool
    {
        return !empty($this->appId) && !empty($this->appKey) && !empty($this->shortCode);
    }

    public function getConfigurationStatus(): array
    {
        $configured = $this->isConfigured();

        return [
            'provider' => 'telebirr',
            'display_name' => $this->getDisplayName(),
            'configured' => $configured,
            'currency' => 'ETB',
            'channel' => 'telebirr_c2b_h5',
            'status_message' => $configured
                ? 'Telebirr H5 Gateway configured and operational.'
                : 'Pending Telebirr Merchant Agreement & API Key Configuration',
            'required_credentials' => [
                'TELEBIRR_APP_ID' => !empty($this->appId) ? 'Set' : 'Missing',
                'TELEBIRR_APP_KEY' => !empty($this->appKey) ? 'Set' : 'Missing',
                'TELEBIRR_SHORT_CODE' => !empty($this->shortCode) ? 'Set' : 'Missing',
                'TELEBIRR_PUBLIC_KEY' => !empty($this->publicKey) ? 'Set' : 'Missing',
                'TELEBIRR_PRIVATE_KEY' => !empty($this->privateKey) ? 'Set' : 'Missing',
            ],
            'onboarding_checklist' => [
                '1. Sign Enterprise Merchant Agreement with Ethio Telecom Commercial Division',
                '2. Receive Telebirr Enterprise Short Code and Developer Portal Access',
                '3. Upload Merchant RSA Public Key and retrieve Ethio Telecom Telebirr Platform Public Key',
                '4. Set TELEBIRR_APP_ID, TELEBIRR_APP_KEY, TELEBIRR_SHORT_CODE, and RSA keys in backend .env',
                '5. Complete Ethio Telecom UAT staging transaction verification',
            ],
        ];
    }

    public function initializeCheckout(PaymentTransaction $transaction, array $customerData): array
    {
        if (!$this->isConfigured()) {
            throw new Exception(
                'Telebirr payment gateway is currently awaiting merchant credential configuration. ' .
                'Please use Chapa (which supports Telebirr payments) or configure Telebirr enterprise merchant keys.'
            );
        }

        $notifyUrl = route('api.payments.telebirr.webhook');
        $returnUrl = url('/payments/verify?tx_ref=' . urlencode($transaction->transaction_reference));

        $telebirrPayload = [
            'appId' => $this->appId,
            'notifyUrl' => $notifyUrl,
            'outTradeNo' => $transaction->transaction_reference,
            'receiveCode' => $this->shortCode,
            'returnUrl' => $returnUrl,
            'subject' => 'Campaign: ' . ($transaction->advertisement->title ?? 'Job Advertising'),
            'timeoutExpress' => '120m',
            'totalAmount' => number_format((float) $transaction->expected_amount_etb, 2, '.', ''),
            'timestamp' => (string) (time() * 1000),
        ];

        try {
            // Real Telebirr H5 C2B API endpoint
            $response = Http::timeout(20)->post('https://app.ethiomobilemoney.et:2121/ammapi/payment/service-open/createOrder', [
                'appid' => $this->appId,
                'sign' => $this->signPayload($telebirrPayload),
                'ussd' => $telebirrPayload,
            ]);

            $result = $response->json();

            if ($response->successful() && isset($result['code']) && $result['code'] == 0) {
                return [
                    'checkout_url' => $result['data']['toPayUrl'] ?? null,
                    'provider_reference' => $result['data']['tradeNo'] ?? $transaction->transaction_reference,
                    'raw_response' => $result,
                ];
            }

            throw new Exception($result['msg'] ?? 'Failed to initialize Telebirr payment order.');
        } catch (Exception $e) {
            Log::error('Telebirr initialization error: ' . $e->getMessage());
            throw $e;
        }
    }

    public function verifyTransaction(PaymentTransaction $transaction): array
    {
        if (!$this->isConfigured()) {
            return [
                'status' => 'unconfigured',
                'message' => 'Telebirr credentials not configured.',
                'raw_response' => [],
            ];
        }

        try {
            $response = Http::timeout(20)->post('https://app.ethiomobilemoney.et:2121/ammapi/payment/service-open/queryOrder', [
                'appid' => $this->appId,
                'outTradeNo' => $transaction->transaction_reference,
            ]);

            $result = $response->json();

            if ($response->successful() && isset($result['data']['orderStatus']) && $result['data']['orderStatus'] === 'SUCCESS') {
                return [
                    'status' => 'successful',
                    'amount' => (float) ($result['data']['totalAmount'] ?? $transaction->expected_amount_etb),
                    'currency' => 'ETB',
                    'provider_reference' => $result['data']['tradeNo'] ?? null,
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
            Log::error('Telebirr verification error: ' . $e->getMessage());
            return [
                'status' => 'error',
                'message' => $e->getMessage(),
                'raw_response' => ['error' => $e->getMessage()],
            ];
        }
    }

    public function verifyWebhookSignature(Request $request): bool
    {
        if (!$this->isConfigured() || empty($this->publicKey)) {
            return false;
        }

        $sign = $request->input('sign');
        $content = $request->input('ussd') ?? $request->all();

        if (empty($sign)) {
            return false;
        }

        // When public key is configured, verify with openssl_verify
        if (str_contains($this->publicKey, 'BEGIN PUBLIC KEY')) {
            $formattedPublic = $this->publicKey;
        } else {
            $formattedPublic = "-----BEGIN PUBLIC KEY-----\n" . wordwrap($this->publicKey, 64, "\n", true) . "\n-----END PUBLIC KEY-----";
        }

        $publicKeyResource = openssl_pkey_get_public($formattedPublic);
        if (!$publicKeyResource) {
            return false;
        }

        $stringToSign = is_array($content) ? json_encode($content, JSON_UNESCAPED_SLASHES) : (string) $content;
        $decodedSign = base64_decode($sign);

        return openssl_verify($stringToSign, $decodedSign, $publicKeyResource, OPENSSL_ALGO_SHA256) === 1;
    }

    public function extractWebhookPayload(Request $request): array
    {
        $payload = $request->all();
        $ussd = $payload['ussd'] ?? $payload;

        $txRef = $ussd['outTradeNo'] ?? $payload['outTradeNo'] ?? null;
        $orderStatus = strtoupper($ussd['orderStatus'] ?? $payload['tradeStatus'] ?? 'PENDING');
        $amount = (float) ($ussd['totalAmount'] ?? $payload['totalAmount'] ?? 0.0);

        return [
            'event_id' => 'telebirr_' . ($ussd['tradeNo'] ?? $txRef ?? time()),
            'transaction_reference' => $txRef,
            'status' => ($orderStatus === 'SUCCESS' || $orderStatus === 'COMPLETED') ? 'successful' : 'pending',
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
            'message' => 'Telebirr direct API refunds require enterprise portal batch submission or manual merchant reversal per Ethio Telecom policies.',
        ];
    }

    protected function signPayload(array $payload): string
    {
        if (empty($this->privateKey)) {
            return '';
        }

        ksort($payload);
        $dataStr = '';
        foreach ($payload as $key => $val) {
            if ($val !== '' && $val !== null) {
                $dataStr .= ($dataStr ? '&' : '') . "{$key}={$val}";
            }
        }

        $formattedPrivate = str_contains($this->privateKey, 'BEGIN RSA PRIVATE KEY')
            ? $this->privateKey
            : "-----BEGIN RSA PRIVATE KEY-----\n" . wordwrap($this->privateKey, 64, "\n", true) . "\n-----END RSA PRIVATE KEY-----";

        $privateKeyResource = openssl_pkey_get_private($formattedPrivate);
        if (!$privateKeyResource) {
            return '';
        }

        $signature = '';
        openssl_sign($dataStr, $signature, $privateKeyResource, OPENSSL_ALGO_SHA256);

        return base64_encode($signature);
    }
}
