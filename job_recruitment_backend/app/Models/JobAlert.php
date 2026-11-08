<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class JobAlert extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'title',
        'keyword',
        'category_id',
        'location',
        'min_salary',
        'frequency',
        'is_active',
        'last_notified_at',
    ];

    protected $casts = [
        'min_salary' => 'decimal:2',
        'is_active' => 'boolean',
        'last_notified_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function category()
    {
        return $this->belongsTo(JobCategory::class, 'category_id');
    }

    /**
     * Build query for matching published vacancies based on alert criteria.
     */
    public function matchingJobs()
    {
        $query = Job::published()->with(['employer', 'skills', 'category']);

        if (!empty($this->keyword)) {
            $kw = '%' . $this->keyword . '%';
            $query->where(function ($q) use ($kw) {
                $q->where('title', 'like', $kw)
                  ->orWhere('description', 'like', $kw)
                  ->orWhere('requirements', 'like', $kw);
            });
        }

        if ($this->category_id) {
            $query->where('category_id', $this->category_id);
        }

        if (!empty($this->location)) {
            $query->where('location', 'like', '%' . $this->location . '%');
        }

        if ($this->min_salary !== null && (float)$this->min_salary > 0) {
            $query->where('salary_max', '>=', $this->min_salary);
        }

        return $query;
    }
}
