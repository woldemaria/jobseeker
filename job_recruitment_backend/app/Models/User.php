<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'phone',
        'profile_photo',
        'device_token',
        'device_platform',
        'password',
        'status',
        'email_verified_at',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function roles()
    {
        return $this->belongsToMany(Role::class, 'role_user')->withTimestamps();
    }

    public function hasRole(string $roleName): bool
    {
        return $this->roles->contains('name', $roleName);
    }

    public function isJobSeeker(): bool
    {
        return $this->hasRole('job_seeker');
    }

    public function isEmployer(): bool
    {
        return $this->hasRole('employer');
    }

    public function isAdmin(): bool
    {
        return $this->hasRole('administrator');
    }

    public function jobSeekerProfile()
    {
        return $this->hasOne(JobSeekerProfile::class);
    }

    public function employers()
    {
        return $this->belongsToMany(Employer::class, 'employer_members')->withPivot('member_role')->withTimestamps();
    }

    public function employerMembers()
    {
        return $this->hasMany(EmployerMember::class);
    }

    public function documents()
    {
        return $this->hasMany(Document::class);
    }

    public function notifications()
    {
        return $this->hasMany(Notification::class);
    }

    public function jobAlerts()
    {
        return $this->hasMany(JobAlert::class);
    }

    public function readNotifications()
    {
        return $this->notifications()->where('is_read', true);
    }

    public function unreadNotifications()
    {
        return $this->notifications()->where('is_read', false);
    }

    public function savedJobs()
    {
        return $this->hasMany(SavedJob::class);
    }

    public function reports()
    {
        return $this->hasMany(Report::class, 'reporter_id');
    }

    public function auditLogs()
    {
        return $this->hasMany(AuditLog::class);
    }

    public function adsConsent()
    {
        return $this->hasOne(AdsConsent::class);
    }

    public function adsConsentHistories()
    {
        return $this->hasMany(AdsConsentHistory::class);
    }
}
