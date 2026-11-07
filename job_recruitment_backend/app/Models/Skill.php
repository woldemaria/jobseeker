<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Skill extends Model
{
    use HasFactory;

    protected $fillable = ['name', 'category', 'description'];

    public function profiles()
    {
        return $this->belongsToMany(JobSeekerProfile::class, 'job_seeker_skills', 'skill_id', 'profile_id')
                    ->withPivot('id', 'proficiency_level', 'years_experience')
                    ->withTimestamps();
    }

    public function jobs()
    {
        return $this->belongsToMany(Job::class, 'job_skills')
                    ->withPivot('id', 'importance', 'minimum_proficiency')
                    ->withTimestamps();
    }
}