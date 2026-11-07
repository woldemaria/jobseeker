<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Application extends Model
{
    use HasFactory;

    protected $fillable = [
        'job_id',
        'profile_id',
        'cv_document_id',
        'cover_letter',
        'status',
        'applied_at',
        'interview_at',
        'interview_type',
        'interview_location',
        'interview_notes',
        'interview_status',
    ];

    protected $casts = [
        'applied_at' => 'datetime',
        'interview_at' => 'datetime',
    ];

    public function job()
    {
        return $this->belongsTo(Job::class);
    }

    public function profile()
    {
        return $this->belongsTo(JobSeekerProfile::class, 'profile_id');
    }

    public function cvDocument()
    {
        return $this->belongsTo(Document::class, 'cv_document_id');
    }

    public function statusHistories()
    {
        return $this->hasMany(ApplicationStatusHistory::class);
    }

    public function screeningAnswers()
    {
        return $this->hasMany(ApplicationScreeningAnswer::class);
    }
}