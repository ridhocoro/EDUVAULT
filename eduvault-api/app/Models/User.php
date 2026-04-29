<?php

namespace App\Models;

use Laravel\Sanctum\HasApiTokens;
use Illuminate\Foundation\Auth\User as Authenticatable;

class User extends Authenticatable
{
    use HasApiTokens;

    protected $fillable = [
        'name', 'email', 'password', 'google_id', 'avatar', 'role',
    ];

    protected $hidden = ['password', 'remember_token'];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'password' => 'hashed',
    ];

    // Relasi: user punya banyak orders
    public function orders()
    {
        return $this->hasMany(Order::class);
    }

    // Relasi: buku-buku yang dimiliki user (via user_library)
    public function library()
    {
        return $this->belongsToMany(Ebook::class, 'user_library')
                    ->withPivot('license_type', 'expires_at')
                    ->withTimestamps();
    }

    // Cek apakah user sudah punya akses ke ebook tertentu
    public function ownsEbook(int $ebookId): bool
    {
        return $this->library()->where('ebook_id', $ebookId)->exists();
    }
}