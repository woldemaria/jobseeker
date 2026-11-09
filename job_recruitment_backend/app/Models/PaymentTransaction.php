<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PaymentTransaction extends Model
{
    use HasFactory;

    protected $table = 'payment_transactions';

    protected $fillable = [
        'transaction_reference',
        'merchant_reference',
        'idempotency_key',
        'provider_reference',
        'checkout_url',
        'payment_method',
        'employer_name_snapshot',
        'employer_id',
        'user_id',
        'advertisement_id',
        'campaign_title_snapshot',
        'package_id',
        'package_name_snapshot',
        'expected_amount_etb',
        'confirmed_amount_etb',
        'currency',
        'payment_status',
        'verified_at',
        'verified_by',
        'failure_reason',
        'receipt_number',
        'payment_metadata',
    ];

    protected $casts = [
        'expected_amount_etb' => 'decimal:2',
        'confirmed_amount_etb' => 'decimal:2',
        'verified_at' => 'datetime',
        'payment_metadata' => 'array',
    ];

    public function employer(): BelongsTo
    {
        return $this->belongsTo(Employer::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function advertisement(): BelongsTo
    {
        return $this->belongsTo(Advertisement::class);
    }

    public function package(): BelongsTo
    {
        return $this->belongsTo(AdvertisingPackage::class, 'package_id');
    }

    public function refunds(): HasMany
    {
        return $this->hasMany(PaymentRefund::class, 'transaction_id');
    }

    public function webhookEvents(): HasMany
    {
        return $this->hasMany(PaymentWebhookEvent::class, 'transaction_reference', 'transaction_reference');
    }

    public function isPending(): bool
    {
        return $this->payment_status === 'pending';
    }

    public function isSuccessful(): bool
    {
        return $this->payment_status === 'successful';
    }

    public function isFailed(): bool
    {
        return in_array($this->payment_status, ['failed', 'cancelled', 'expired']);
    }

    public function canBeRefunded(): bool
    {
        if (!$this->isSuccessful() || (float)$this->confirmed_amount_etb <= 0) {
            return false;
        }
        $alreadyRefunded = (float) $this->refunds()->where('status', 'completed')->sum('amount');
        return $alreadyRefunded < (float) $this->confirmed_amount_etb;
    }

    public function getRemainingRefundableAmount(): float
    {
        $alreadyRefunded = (float) $this->refunds()->where('status', 'completed')->sum('amount');
        return max(0.0, (float) $this->confirmed_amount_etb - $alreadyRefunded);
    }
}
