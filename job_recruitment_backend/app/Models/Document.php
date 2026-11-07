<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Document extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'original_name',
        'storage_path',
        'mime_type',
        'file_size',
        'document_type',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}