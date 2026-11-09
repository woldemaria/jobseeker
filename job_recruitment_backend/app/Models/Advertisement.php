<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Advertisement extends Model
{
    use HasFactory;

    protected $fillable = [
        'employer_id',
        'job_id',
        'package_id',
        'created_by',
        'title',
        'title_am',
        'subtitle',
        'subtitle_am',
        'description',
        'badge_text',
        'badge_text_am',
        'image_url',
        'category',
        'placement',
        'placements',
        'target_role',
        'target_skills',
        'target_category',
        'target_locations',
        'target_audience',
        'cta_type',
        'cta_text',
        'cta_text_am',
        'cta_target',
        'background_color',
        'status',
        'approval_status',
        'approved_by',
        'approved_at',
        'rejection_reason',
        'payment_status',
        'price_paid',
        'priority',
        'start_date',
        'end_date',
        'impressions_count',
        'clicks_count',
    ];

    protected $casts = [
        'target_skills' => 'array',
        'placements' => 'array',
        'target_locations' => 'array',
        'target_audience' => 'array',
        'priority' => 'integer',
        'start_date' => 'datetime',
        'end_date' => 'datetime',
        'approved_at' => 'datetime',
        'price_paid' => 'float',
        'impressions_count' => 'integer',
        'clicks_count' => 'integer',
    ];

    protected $appends = ['ctr'];

    public function getCtrAttribute(): float
    {
        if ($this->impressions_count <= 0) {
            return 0.0;
        }
        return round(($this->clicks_count / $this->impressions_count) * 100, 2);
    }

    public function isDraft(): bool
    {
        return $this->approval_status === 'draft' || $this->status === 'draft';
    }

    public function isPendingApproval(): bool
    {
        return $this->approval_status === 'pending_approval' || $this->status === 'pending_approval';
    }

    public function isApproved(): bool
    {
        return $this->approval_status === 'approved';
    }

    public function isRejected(): bool
    {
        return $this->approval_status === 'rejected' || $this->status === 'rejected';
    }

    public function isPaid(): bool
    {
        return in_array($this->payment_status, ['paid', 'free_trial']) || $this->price_paid <= 0;
    }

    public function canBeEdited(): bool
    {
        return in_array($this->approval_status, ['draft', 'rejected']) ||
               in_array($this->status, ['draft', 'rejected']);
    }

    public function employer()
    {
        return $this->belongsTo(Employer::class);
    }

    public function job()
    {
        return $this->belongsTo(Job::class);
    }

    public function package()
    {
        return $this->belongsTo(AdvertisingPackage::class, 'package_id');
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function approvedBy()
    {
        return $this->belongsTo(User::class, 'approved_by');
    }

    public function events()
    {
        return $this->hasMany(AdvertisementEvent::class);
    }

    public function paymentTransactions()
    {
        return $this->hasMany(PaymentTransaction::class);
    }

    public function scopeActive($query)
    {
        $now = now();
        return $query->where('status', 'active')
            ->where(function ($q) {
                $q->where('approval_status', 'approved')
                  ->orWhereNull('approval_status');
            })
            ->where(function ($q) {
                $q->whereIn('payment_status', ['paid', 'free_trial'])
                  ->orWhere('price_paid', '<=', 0);
            })
            ->where('start_date', '<=', $now)
            ->where('end_date', '>=', $now);
    }

    public function scopePlacement($query, string $placement)
    {
        return $query->where(function ($q) use ($placement) {
            $q->where('placement', $placement)
              ->orWhereJsonContains('placements', $placement);
        });
    }

    public function scopeForRole($query, ?string $role)
    {
        if (!$role || $role === 'all') {
            return $query;
        }
        return $query->where(function ($q) use ($role) {
            $q->where('target_role', 'all')
              ->orWhere('target_role', $role);
        });
    }
}
