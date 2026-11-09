<?php

namespace App\Http\Controllers\Api;

use App\Models\Advertisement;
use App\Models\PaymentTransaction;
use App\Models\User;
use App\Services\Payment\PaymentManagerService;
use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;

class PaymentController extends BaseApiController
{
    protected PaymentManagerService $paymentManager;

    public function __construct(PaymentManagerService $paymentManager)
    {
        $this->paymentManager = $paymentManager;
    }

    /**
     * Resolve the employer ID for the authenticated user.
     */
    protected function resolveEmployerId(User $user): ?int
    {
        $employerIds = $user->employers()->pluck('employers.id')->toArray();
        if (!empty($employerIds)) {
            return $employerIds[0];
        }
        return null;
    }

    /**
     * List supported payment methods and their current operational status.
     * GET /api/v1/payments/methods
     */
    public function methods(): JsonResponse
    {
        $methods = $this->paymentManager->getAvailablePaymentMethods();
        return $this->successResponse($methods, 'Supported payment providers retrieved successfully');
    }

    /**
     * Initiate a payment session for an advertising campaign.
     * POST /api/v1/advertiser/payments/initiate
     */
    public function initiate(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'advertisement_id' => 'required|integer|exists:advertisements,id',
            'payment_method' => 'required|string|in:chapa,telebirr,cbe_birr',
            'customer_name' => 'nullable|string|max:150',
            'customer_email' => 'nullable|email|max:150',
            'customer_phone' => 'nullable|string|max:30',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validation failed', 422, $validator->errors());
        }

        $user = $request->user();
        $advertisement = Advertisement::with(['package', 'employer'])->findOrFail($request->input('advertisement_id'));

        // Check ownership (IDOR check)
        $userEmployerIds = $user->employers()->pluck('employers.id')->toArray();
        if (!$user->isAdmin() && !in_array($advertisement->employer_id, $userEmployerIds)) {
            return $this->errorResponse('Unauthorized: You do not own this campaign.', 403);
        }

        // Check if campaign is already paid
        if ($advertisement->payment_status === 'paid') {
            return $this->errorResponse('This campaign is already marked as paid.', 422);
        }

        try {
            $transaction = $this->paymentManager->initiateCampaignPayment(
                $advertisement,
                $user,
                $request->input('payment_method'),
                [
                    'name' => $request->input('customer_name'),
                    'email' => $request->input('customer_email'),
                    'phone' => $request->input('customer_phone'),
                ]
            );

            return $this->successResponse([
                'transaction_reference' => $transaction->transaction_reference,
                'merchant_reference' => $transaction->merchant_reference,
                'checkout_url' => $transaction->checkout_url,
                'provider_reference' => $transaction->provider_reference,
                'expected_amount_etb' => (float) $transaction->expected_amount_etb,
                'currency' => $transaction->currency,
                'payment_method' => $transaction->payment_method,
                'payment_status' => $transaction->payment_status,
                'campaign_id' => $advertisement->id,
                'campaign_title' => $advertisement->title,
                'package_name' => $transaction->package->name ?? null,
            ], 'Payment checkout initialized successfully', 201);
        } catch (Exception $e) {
            Log::error('Payment initiation failed: ' . $e->getMessage());
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    /**
     * Direct server-to-server verification endpoint.
     * GET /api/v1/advertiser/payments/verify/{reference}
     */
    public function verify(Request $request, string $reference): JsonResponse
    {
        $user = $request->user();
        $transaction = PaymentTransaction::where('transaction_reference', $reference)
            ->with(['advertisement', 'package', 'employer'])
            ->first();

        if (!$transaction) {
            return $this->errorResponse('Transaction not found.', 404);
        }

        // Authorization check
        $userEmployerIds = $user->employers()->pluck('employers.id')->toArray();
        if (!$user->isAdmin() && !in_array($transaction->employer_id, $userEmployerIds)) {
            return $this->errorResponse('Unauthorized access to transaction.', 403);
        }

        try {
            $verified = $this->paymentManager->verifyPayment($reference, "user:{$user->id}");

            return $this->successResponse([
                'transaction_reference' => $verified->transaction_reference,
                'provider_reference' => $verified->provider_reference,
                'payment_status' => $verified->payment_status,
                'is_successful' => $verified->isSuccessful(),
                'expected_amount_etb' => (float) $verified->expected_amount_etb,
                'confirmed_amount_etb' => (float) $verified->confirmed_amount_etb,
                'currency' => $verified->currency,
                'receipt_number' => $verified->receipt_number,
                'verified_at' => $verified->verified_at ? $verified->verified_at->toIso8601String() : null,
                'campaign' => [
                    'id' => $verified->advertisement_id,
                    'title' => $verified->advertisement->title ?? '',
                    'status' => $verified->advertisement->status ?? '',
                    'approval_status' => $verified->advertisement->approval_status ?? '',
                    'payment_status' => $verified->advertisement->payment_status ?? '',
                ],
            ], 'Transaction verification processed');
        } catch (Exception $e) {
            Log::error('Payment verification error: ' . $e->getMessage());
            return $this->errorResponse($e->getMessage(), 400);
        }
    }

    /**
     * List payment transactions for the authenticated employer.
     * GET /api/v1/advertiser/payments/transactions
     */
    public function employerTransactions(Request $request): JsonResponse
    {
        $user = $request->user();
        $employerId = $this->resolveEmployerId($user);

        if (!$employerId && !$user->isAdmin()) {
            return $this->errorResponse('No employer profile associated with current account.', 404);
        }

        $query = PaymentTransaction::query()->with([
            'advertisement:id,title,approval_status,payment_status',
            'package:id,name,price_etb,duration_days',
        ]);

        if (!$user->isAdmin()) {
            $userEmployerIds = $user->employers()->pluck('employers.id')->toArray();
            $query->whereIn('employer_id', $userEmployerIds);
        }

        if ($request->filled('status')) {
            $query->where('payment_status', $request->input('status'));
        }

        if ($request->filled('payment_method')) {
            $query->where('payment_method', $request->input('payment_method'));
        }

        if ($request->filled('advertisement_id')) {
            $query->where('advertisement_id', $request->input('advertisement_id'));
        }

        $perPage = min(max((int) $request->input('per_page', 15), 1), 50);
        $transactions = $query->latest()->paginate($perPage);

        return $this->successResponse($transactions, 'Employer transactions retrieved successfully');
    }

    /**
     * Get single transaction details.
     * GET /api/v1/advertiser/payments/transactions/{reference}
     */
    public function employerTransactionDetail(Request $request, string $reference): JsonResponse
    {
        $user = $request->user();
        $transaction = PaymentTransaction::where('transaction_reference', $reference)
            ->with(['advertisement', 'package', 'employer', 'refunds'])
            ->first();

        if (!$transaction) {
            return $this->errorResponse('Transaction not found.', 404);
        }

        $userEmployerIds = $user->employers()->pluck('employers.id')->toArray();
        if (!$user->isAdmin() && !in_array($transaction->employer_id, $userEmployerIds)) {
            return $this->errorResponse('Unauthorized access.', 403);
        }

        return $this->successResponse($transaction, 'Transaction details retrieved successfully');
    }

    /**
     * Webhook receiver for Chapa notifications.
     * POST /api/v1/payments/chapa/webhook
     */
    public function chapaWebhook(Request $request): JsonResponse
    {
        try {
            $result = $this->paymentManager->processWebhook('chapa', $request);
            return response()->json($result, 200);
        } catch (Exception $e) {
            Log::error('Chapa webhook error: ' . $e->getMessage());
            return response()->json(['error' => $e->getMessage()], 400);
        }
    }

    /**
     * Webhook receiver for Telebirr notifications.
     * POST /api/v1/payments/telebirr/webhook
     */
    public function telebirrWebhook(Request $request): JsonResponse
    {
        try {
            $result = $this->paymentManager->processWebhook('telebirr', $request);
            return response()->json($result, 200);
        } catch (Exception $e) {
            Log::error('Telebirr webhook error: ' . $e->getMessage());
            return response()->json(['error' => $e->getMessage()], 400);
        }
    }

    /**
     * Webhook receiver for CBE Birr notifications.
     * POST /api/v1/payments/cbe/webhook
     */
    public function cbeWebhook(Request $request): JsonResponse
    {
        try {
            $result = $this->paymentManager->processWebhook('cbe_birr', $request);
            return response()->json($result, 200);
        } catch (Exception $e) {
            Log::error('CBE Birr webhook error: ' . $e->getMessage());
            return response()->json(['error' => $e->getMessage()], 400);
        }
    }

    /**
     * Admin: List all transactions with advanced filtering.
     * GET /api/v1/admin/payments/transactions
     */
    public function adminIndex(Request $request): JsonResponse
    {
        $user = $request->user();
        if (!$user->isAdmin()) {
            return $this->errorResponse('Admin privileges required.', 403);
        }

        $query = PaymentTransaction::query()->with([
            'employer:id,organization_name,email,phone',
            'user:id,name,email',
            'advertisement:id,title,status,approval_status,payment_status',
            'package:id,name,price_etb',
            'refunds',
        ]);

        if ($request->filled('status')) {
            $query->where('payment_status', $request->input('status'));
        }

        if ($request->filled('payment_method')) {
            $query->where('payment_method', $request->input('payment_method'));
        }

        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function ($q) use ($search) {
                $q->where('transaction_reference', 'like', "%{$search}%")
                  ->orWhere('merchant_reference', 'like', "%{$search}%")
                  ->orWhere('provider_reference', 'like', "%{$search}%")
                  ->orWhere('receipt_number', 'like', "%{$search}%");
            });
        }

        $perPage = min(max((int) $request->input('per_page', 20), 1), 100);
        $transactions = $query->latest()->paginate($perPage);

        return $this->successResponse($transactions, 'Admin transactions retrieved successfully');
    }

    /**
     * Admin: Process transaction refund.
     * POST /api/v1/admin/payments/transactions/{reference}/refund
     */
    public function adminRefund(Request $request, string $reference): JsonResponse
    {
        $user = $request->user();
        if (!$user->isAdmin()) {
            return $this->errorResponse('Admin privileges required.', 403);
        }

        $validator = Validator::make($request->all(), [
            'amount' => 'required|numeric|min:1',
            'reason' => 'required|string|min:5|max:500',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validation failed', 422, $validator->errors());
        }

        $transaction = PaymentTransaction::where('transaction_reference', $reference)->first();
        if (!$transaction) {
            return $this->errorResponse('Transaction not found.', 404);
        }

        try {
            $refund = $this->paymentManager->processRefund(
                $transaction,
                $user,
                (float) $request->input('amount'),
                $request->input('reason')
            );

            return $this->successResponse($refund, 'Refund initiated and recorded successfully');
        } catch (Exception $e) {
            Log::error('Refund processing error: ' . $e->getMessage());
            return $this->errorResponse($e->getMessage(), 400);
        }
    }
}
