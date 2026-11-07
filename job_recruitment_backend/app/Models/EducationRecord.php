<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class EducationRecord extends Model
{
    use HasFactory;

    protected $fillable = [
        'profile_id',
        'institution_name',
        'qualification',
        'field_of_study',
        'start_date',
        'end_date',
        'grade',
        'description',
    ];

    protected $casts = [
        'start_date' => 'date',
        'end_date' => 'date',
    ];

    public function profile()
    {
        return $this->belongsTo(JobSeekerProfile::class, 'profile_id');
    }
}