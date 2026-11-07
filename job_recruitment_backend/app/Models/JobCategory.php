<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class JobCategory extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'slug',
        'icon',
        'description',
        'display_order',
    ];

    public function titles()
    {
        return $this->hasMany(JobTitle::class, 'category_id')->orderBy('title');
    }

    public function jobs()
    {
        return $this->hasMany(Job::class, 'category_id');
    }
}
