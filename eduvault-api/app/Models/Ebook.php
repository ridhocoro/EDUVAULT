<?php

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
        'price' => 'decimal:2',
        'published_at' => 'datetime',
    ];

    // Hanya tampilkan buku yang published ke publik
    public function scopePublished($query)
    {
        return $query->where('status', 'published');
    }

    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    // Jangan ekspos file_url ke response publik
    protected $hidden = ['file_url'];
}