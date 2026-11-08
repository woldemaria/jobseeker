<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class AdsConsent extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'consent_uuid',
        'status',
        'personalized_ads',
        'non_personalized_ads',
        'analytics',
        'advertising_cookies',
        'policy_version',
        'ip_address',
        'user_agent',
        'consented_at',
        'withdrawn_at',
    ];

    protected $casts = [
        'personalized_ads' => 'boolean',
        'non_personalized_ads' => 'boolean',
        'analytics' => 'boolean',
        'advertising_cookies' => 'boolean',
        'consented_at' => 'datetime',
        'withdrawn_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function histories(): HasMany
    {
        return $this->hasMany(AdsConsentHistory::class);
    }

    public function isAccepted(): bool
    {
        return $this->status === 'accepted';
    }

    public function isRejected(): bool
    {
        return $this->status === 'rejected';
    }

    public function isWithdrawn(): bool
    {
        return $this->status === 'withdrawn';
    }

    public function allowsPersonalizedAds(): bool
    {
        return !$this->isWithdrawn() && $this->personalized_ads;
    }

    public function allowsNonPersonalizedAds(): bool
    {
        return !$this->isWithdrawn() && $this->non_personalized_ads;
    }

    public function allowsAnalytics(): bool
    {
        return !$this->isWithdrawn() && $this->analytics;
    }

    public function allowsCookies(): bool
    {
        return !$this->isWithdrawn() && $this->advertising_cookies;
    }
}
