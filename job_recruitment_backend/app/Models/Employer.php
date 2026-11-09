<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Employer extends Model
{
    use HasFactory;

    protected $fillable = [
        'organization_name',
        'organization_type',
        'registration_number',
        'email',
        'phone',
        'website',
        'address',
        'verification_status',
    ];

    public function getOrganizationNameAttribute(): ?string
    {
        return $this->attributes['organization_name'] ?? null;
    }

    public function members()
    {
        return $this->hasMany(EmployerMember::class);
    }

    public function users()
    {
        return $this->belongsToMany(User::class, 'employer_members')->withPivot('member_role')->withTimestamps();
    }

    public function jobs()
    {
        return $this->hasMany(Job::class);
    }

    public function verifications()
    {
        return $this->hasMany(EmployerVerification::class);
    }

    public function advertisements()
    {
        return $this->hasMany(Advertisement::class);
    }

    public function paymentTransactions()
    {
        return $this->hasMany(PaymentTransaction::class);
    }
}