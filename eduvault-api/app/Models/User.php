<?php
// app/Models/User.php
// REPLACE file lama dengan file ini

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'password',
        'google_id',   // ← baru (Google OAuth)
        'avatar',      // ← baru (foto profil Google)
        'role',
    ];

    protected $hidden = [
        'password',
        'remember_token',
        'google_id',   // jangan ekspos ke response
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password'          => 'hashed',
        ];
    }
}
