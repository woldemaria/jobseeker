<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class UserSkillBadge extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'skill_id',
        'quiz_id',
        'score',
        'badge_type',
        'verified_at',
    ];

    protected $casts = [
        'score' => 'float',
        'verified_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function skill()
    {
        return $this->belongsTo(Skill::class);
    }

    public function quiz()
    {
        return $this->belongsTo(Quiz::class);
    }
}
