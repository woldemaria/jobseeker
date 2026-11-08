<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Job extends Model
{
    use HasFactory;

    protected $fillable = [
        'employer_id',
        'category_id',
        'category',
        'job_title_id',
        'title',
        'description',
        'responsibilities',
        'requirements',
        'location',
        'employment_type',
        'experience_required',
        'salary_min',
        'salary_max',
        'currency',
        'deadline',
        'status',
        'fraud_score',
        'fraud_risk_level',
        'fraud_indicators',
        'is_flagged',
        'moderation_status',
        'moderated_by',
        'moderated_at',
        'moderation_notes',
        'published_at',
        'latitude',
        'longitude',
        'notice_code',
        'qr_payload',
    ];

    protected $casts = [
        'experience_required' => 'decimal:1',
        'salary_min' => 'decimal:2',
        'salary_max' => 'decimal:2',
        'latitude' => 'float',
        'longitude' => 'float',
        'deadline' => 'date',
        'published_at' => 'datetime',
        'fraud_score' => 'integer',
        'fraud_indicators' => 'array',
        'is_flagged' => 'boolean',
        'moderated_at' => 'datetime',
    ];

    public function moderator()
    {
        return $this->belongsTo(User::class, 'moderated_by');
    }

    public function reports()
    {
        return $this->hasMany(Report::class, 'job_id');
    }

    public function employer()
    {
        return $this->belongsTo(Employer::class);
    }

    public function category()
    {
        return $this->belongsTo(JobCategory::class, 'category_id');
    }

    public function jobTitle()
    {
        return $this->belongsTo(JobTitle::class, 'job_title_id');
    }

    public function skills()
    {
        return $this->belongsToMany(Skill::class, 'job_skills')
                    ->withPivot('id', 'importance', 'minimum_proficiency')
                    ->withTimestamps();
    }

    public function jobSkills()
    {
        return $this->hasMany(JobSkill::class);
    }

    public function applications()
    {
        return $this->hasMany(Application::class);
    }

    public function savedJobs()
    {
        return $this->hasMany(SavedJob::class);
    }

    public function screeningQuestions()
    {
        return $this->hasMany(JobScreeningQuestion::class);
    }

    public function isSavedBy(int $userId): bool
    {
        return $this->savedJobs()->where('user_id', $userId)->exists();
    }

    public function scopePublished($query)
    {
        return $query->where('status', 'published')
                     ->where('moderation_status', '!=', 'fraudulent')
                     ->where('deadline', '>=', now()->toDateString());
    }

    public function scopeFlagged($query)
    {
        return $query->where(function ($q) {
            $q->where('is_flagged', true)
              ->orWhere('fraud_score', '>=', 50)
              ->orWhereIn('moderation_status', ['flagged', 'under_review', 'fraudulent']);
        });
    }

    public function scopeHighRisk($query)
    {
        return $query->whereIn('fraud_risk_level', ['high', 'critical']);
    }
}