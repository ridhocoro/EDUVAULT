<?php
// app/Models/Ebook.php
// REPLACE file lama dengan file ini

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Ebook extends Model
{
    protected $fillable = [
        'title', 'slug', 'description', 'author', 'price',
        'cover_url', 'file_url', 'djki_cert_no',
        'total_pages', 'category_id', 'status', 'published_at',
    ];

    protected $casts = [
        'price'        => 'decimal:2',
        'published_at' => 'datetime',
        'total_pages'  => 'integer',
    ];

    // Sembunyikan file_url dari response publik
    // Admin controller akan expose secara manual via getRawOriginal()
    protected $hidden = ['file_url'];

    // ── Scopes ──────────────────────────────────────────────────

    public function scopePublished($query)
    {
        return $query->where('status', 'published');
    }

    public function scopeActive($query)
    {
        return $query->where('status', 'published');
    }

    // ── Relationships ────────────────────────────────────────────

    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    public function orderItems()
    {
        return $this->hasMany(OrderItem::class);
    }
}
