<?php
// app/Models/QuizAttempt.php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class QuizAttempt extends Model
{
    protected $fillable = ['user_id', 'quiz_id', 'score', 'total', 'duration_seconds'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function quiz(): BelongsTo
    {
        return $this->belongsTo(Quiz::class);
    }

    public function getPercentageAttribute(): int
    {
        if ($this->total === 0) return 0;
        return (int) round(($this->score / $this->total) * 100);
    }
}
