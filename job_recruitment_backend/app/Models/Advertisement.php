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
        'created_by',
        'title',
        'title_am',
        'subtitle',
        'subtitle_am',
        'badge_text',
        'badge_text_am',
        'image_url',
        'category',
        'placement',
        'target_role',
        'target_skills',
        'target_category',
        'cta_type',
        'cta_text',
        'cta_text_am',
        'cta_target',
        'background_color',
        'status',
        'priority',
        'start_date',
        'end_date',
        'impressions_count',
        'clicks_count',
    ];

    protected $casts = [
        'target_skills' => 'array',
        'priority' => 'integer',
        'start_date' => 'datetime',
        'end_date' => 'datetime',
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

    public function employer()
    {
        return $this->belongsTo(Employer::class);
    }

    public function job()
    {
        return $this->belongsTo(Job::class);
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function events()
    {
        return $this->hasMany(AdvertisementEvent::class);
    }

    public function scopeActive($query)
    {
        $now = now();
        return $query->where('status', 'active')
            ->where('start_date', '<=', $now)
            ->where('end_date', '>=', $now);
    }

    public function scopePlacement($query, string $placement)
    {
        return $query->where('placement', $placement);
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
