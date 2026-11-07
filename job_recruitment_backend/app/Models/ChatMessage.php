<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ChatMessage extends Model
{
    use HasFactory;

    protected $fillable = [
        'group_id',
        'user_id',
        'message',
        'message_type',
        'shared_job_id',
    ];

    public function group()
    {
        return $this->belongsTo(ChatGroup::class, 'group_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function sharedJob()
    {
        return $this->belongsTo(Job::class, 'shared_job_id');
    }
}
