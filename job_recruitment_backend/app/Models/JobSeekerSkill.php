<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class JobSeekerSkill extends Model
{
    use HasFactory;

    protected $fillable = [
        'profile_id',
        'skill_id',
        'proficiency_level',
        'years_experience',
    ];

    protected $casts = [
        'years_experience' => 'decimal:1',
    ];

    public function profile()
    {
        return $this->belongsTo(JobSeekerProfile::class, 'profile_id');
    }

    public function skill()
    {
        return $this->belongsTo(Skill::class);
    }
}