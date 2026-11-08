<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdsConsentHistory extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = [
        'ads_consent_id',
        'user_id',
        'action',
        'policy_version',
        'status',
        'preferences',
        'ip_address',
        'user_agent',
        'created_at',
    ];

    protected $casts = [
        'preferences' => 'array',
        'created_at' => 'datetime',
    ];

    public function adsConsent(): BelongsTo
    {
        return $this->belongsTo(AdsConsent::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
