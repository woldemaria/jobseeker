<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class JobSeekerProfile extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'date_of_birth',
        'gender',
        'education_level',
        'field_of_study',
        'preferred_job_title',
        'preferred_category_id',
        'experience_years',
        'location',
        'biography',
    ];

    protected $casts = [
        'experience_years' => 'decimal:1',
        'date_of_birth' => 'date',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function preferredCategory()
    {
        return $this->belongsTo(JobCategory::class, 'preferred_category_id');
    }

    public function skills()
    {
        return $this->belongsToMany(Skill::class, 'job_seeker_skills', 'profile_id', 'skill_id')
                    ->withPivot('id', 'proficiency_level', 'years_experience')
                    ->withTimestamps();
    }

    public function jobSeekerSkills()
    {
        return $this->hasMany(JobSeekerSkill::class, 'profile_id');
    }

    public function educationRecords()
    {
        return $this->hasMany(EducationRecord::class, 'profile_id');
    }

    public function workExperiences()
    {
        return $this->hasMany(WorkExperience::class, 'profile_id');
    }

    public function applications()
    {
        return $this->hasMany(Application::class, 'profile_id');
    }
}