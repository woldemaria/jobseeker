<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class JobScreeningQuestion extends Model
{
    use HasFactory;

    protected $fillable = [
        'job_id',
        'question_text',
        'expected_boolean',
        'is_knockout',
    ];

    protected $casts = [
        'expected_boolean' => 'boolean',
        'is_knockout' => 'boolean',
    ];

    public function job()
    {
        return $this->belongsTo(Job::class);
    }
}
