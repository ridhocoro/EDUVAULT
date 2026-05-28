<?php
// app/Models/Quiz.php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Quiz extends Model
{
    protected $fillable = [
        'ebook_id',
        'user_id',        // user yang membuat quiz
        'title',
        'status',
        'quiz_type',      // 'full' | 'chapter'
        'chapter_number', // null jika full
        'chapter_title',  // label bab opsional
    ];

    protected $casts = [
        'chapter_number' => 'integer',
    ];

    public function ebook(): BelongsTo
    {
        return $this->belongsTo(Ebook::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function questions(): HasMany
    {
        return $this->hasMany(QuizQuestion::class)->orderBy('order');
    }

    public function attempts(): HasMany
    {
        return $this->hasMany(QuizAttempt::class);
    }
}
