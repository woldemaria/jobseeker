<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ApplicationScreeningAnswer extends Model
{
    use HasFactory;

    protected $fillable = [
        'application_id',
        'question_id',
        'answer_boolean',
        'passed',
    ];

    protected $casts = [
        'answer_boolean' => 'boolean',
        'passed' => 'boolean',
    ];

    public function application()
    {
        return $this->belongsTo(Application::class);
    }

    public function question()
    {
        return $this->belongsTo(JobScreeningQuestion::class, 'question_id');
    }
}
