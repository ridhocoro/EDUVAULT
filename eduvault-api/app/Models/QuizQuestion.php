<?php
// app/Models/QuizQuestion.php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class QuizQuestion extends Model
{
    protected $fillable = [
        'quiz_id', 'order', 'question',
        'option_a', 'option_b', 'option_c', 'option_d',
        'correct_answer', 'explanation',
    ];

    public function quiz(): BelongsTo
    {
        return $this->belongsTo(Quiz::class);
    }
}
