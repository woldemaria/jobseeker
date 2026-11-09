<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PaymentWebhookEvent extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $table = 'payment_webhook_events';

    protected $fillable = [
        'provider',
        'event_id',
        'transaction_reference',
        'payload',
        'signature',
        'processed',
        'processing_notes',
        'created_at',
    ];

    protected $casts = [
        'payload' => 'array',
        'processed' => 'boolean',
        'created_at' => 'datetime',
    ];

    public function transaction(): BelongsTo
    {
        return $this->belongsTo(PaymentTransaction::class, 'transaction_reference', 'transaction_reference');
    }
}
