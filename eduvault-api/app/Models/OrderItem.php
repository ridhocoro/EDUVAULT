<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class OrderItem extends Model
{
    protected $fillable = ['order_id', 'ebook_id', 'price'];

    protected $casts = ['price' => 'decimal:2'];

    public function ebook()
    {
        return $this->belongsTo(Ebook::class);
    }
}