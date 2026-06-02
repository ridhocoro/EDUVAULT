<?php
// app/Models/SubscriptionPlan.php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SubscriptionPlan extends Model
{
    protected $fillable = [
        'name', 'description', 'price', 'duration_days', 'status',
    ];

    protected $casts = [
        'price'         => 'decimal:2',
        'duration_days' => 'integer',
    ];

    // ── Scopes ────────────────────────────────────────────────────

    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }

    // ── Relationships ─────────────────────────────────────────────

    /** Ebook yang termasuk dalam paket ini */
    public function ebooks(): BelongsToMany
    {
        return $this->belongsToMany(Ebook::class, 'subscription_plan_ebooks')
                    ->withTimestamps();
    }

    /** Riwayat subscription user yang menggunakan paket ini */
    public function userSubscriptions(): HasMany
    {
        return $this->hasMany(UserSubscription::class);
    }
}
