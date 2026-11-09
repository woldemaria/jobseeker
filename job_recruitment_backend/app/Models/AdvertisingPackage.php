<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AdvertisingPackage extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'slug',
        'description',
        'duration_days',
        'price_etb',
        'allowed_placements',
        'allowed_categories',
        'benefits',
        'badge_label',
        'is_active',
        'priority_level',
    ];

    protected $casts = [
        'duration_days' => 'integer',
        'price_etb' => 'float',
        'allowed_placements' => 'array',
        'allowed_categories' => 'array',
        'benefits' => 'array',
        'is_active' => 'boolean',
        'priority_level' => 'integer',
    ];

    protected $appends = [
        'price_formatted',
    ];

    public function getPriceFormattedAttribute(): string
    {
        return number_format($this->price_etb, 2) . ' ETB';
    }

    public function advertisements()
    {
        return $this->hasMany(Advertisement::class, 'package_id');
    }

    public function paymentTransactions()
    {
        return $this->hasMany(PaymentTransaction::class, 'package_id');
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    public function scopeOrdered($query)
    {
        return $query->orderByDesc('priority_level')->orderBy('price_etb', 'asc');
    }
}
