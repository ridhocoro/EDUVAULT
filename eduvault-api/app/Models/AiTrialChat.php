<?php
// app/Models/AiTrialChat.php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AiTrialChat extends Model
{
    protected $fillable = ['user_id', 'ebook_id', 'message', 'response'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function ebook(): BelongsTo
    {
        return $this->belongsTo(Ebook::class);
    }

    /**
     * Hitung berapa kali user sudah trial chat untuk buku tertentu
     */
    public static function countTrials(int $userId, int $ebookId): int
    {
        return static::where('user_id', $userId)
            ->where('ebook_id', $ebookId)
            ->count();
    }
}
