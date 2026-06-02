<?php
// app/Models/User.php — REPLACE file lama

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name', 'email', 'password', 'google_id', 'avatar', 'role',
    ];

    protected $hidden = [
        'password', 'remember_token', 'google_id',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password'          => 'hashed',
        ];
    }

    // ── Relationships ────────────────────────────────────────────

    /** Ebook yang dimiliki user (beli satuan maupun subscription) */
    public function library(): BelongsToMany
    {
        return $this->belongsToMany(Ebook::class, 'user_library')
                    ->withPivot('is_finished', 'finished_at', 'source_type', 'subscription_id', 'expires_at')
                    ->withTimestamps();
    }

    public function reviews(): HasMany
    {
        return $this->hasMany(Review::class);
    }

    public function wishlists(): HasMany
    {
        return $this->hasMany(Wishlist::class);
    }

    /** Semua subscription user */
    public function subscriptions(): HasMany
    {
        return $this->hasMany(UserSubscription::class);
    }

    // ── Helpers ───────────────────────────────────────────────────

    /** Cek apakah user sudah memiliki sebuah ebook (beli satuan atau via aktif subscription) */
    public function ownsEbook(int $ebookId): bool
    {
        // Cek via purchase / free / record library langsung
        if ($this->library()->where('ebook_id', $ebookId)->exists()) {
            return true;
        }

        // Cek via subscription aktif
        return $this->hasActiveSubscriptionForEbook($ebookId);
    }

    /** Cek apakah ada subscription aktif yang mencakup ebook ini */
    public function hasActiveSubscriptionForEbook(int $ebookId): bool
    {
        return $this->subscriptions()
            ->where('status', 'active')
            ->where('expires_at', '>', now())
            ->whereHas('plan.ebooks', fn ($q) => $q->where('ebooks.id', $ebookId))
            ->exists();
    }

    /** Ambil subscription aktif user (yang paling baru expires) */
    public function activeSubscription(): ?UserSubscription
    {
        return $this->subscriptions()
            ->with('plan.ebooks')
            ->where('status', 'active')
            ->where('expires_at', '>', now())
            ->orderByDesc('expires_at')
            ->first();
    }

    /**
     * Cek apakah AI chat bebas untuk ebook ini.
     * Bebas jika: sudah beli satuan, ATAU ada subscription aktif yang cover buku ini.
     */
    public function hasUnlimitedAiFor(int $ebookId): bool
    {
        // Sudah beli satuan / free → bebas
        if ($this->library()->where('ebook_id', $ebookId)
                ->whereIn('source_type', ['purchase', 'free'])->exists()) {
            return true;
        }

        // Ada subscription aktif yang cover buku ini → bebas
        return $this->hasActiveSubscriptionForEbook($ebookId);
    }
}
