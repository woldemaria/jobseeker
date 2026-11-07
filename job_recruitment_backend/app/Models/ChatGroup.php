<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ChatGroup extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'description',
        'icon_url',
        'created_by',
        'is_private',
    ];

    protected $casts = [
        'is_private' => 'boolean',
    ];

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function members()
    {
        return $this->hasMany(ChatGroupMember::class, 'group_id');
    }

    public function users()
    {
        return $this->belongsToMany(User::class, 'chat_group_members', 'group_id', 'user_id')
                    ->withPivot('role', 'joined_at')
                    ->withTimestamps();
    }

    public function messages()
    {
        return $this->hasMany(ChatMessage::class, 'group_id');
    }

    public function latestMessage()
    {
        return $this->hasOne(ChatMessage::class, 'group_id')->latestOfMany();
    }
}
