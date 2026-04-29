<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Ebook;
use Illuminate\Http\Request;

class EbookController extends Controller
{
    // Daftar buku — publik, dengan filter & search
    public function index(Request $request)
    {
        $query = Ebook::published()->with('category');

        // Filter by kategori
        if ($request->category) {
            $query->whereHas('category', fn($q) =>
                $q->where('slug', $request->category)
            );
        }

        // Search by judul
        if ($request->search) {
            $query->where('title', 'like', "%{$request->search}%");
        }

        // Sort
        $sort = $request->sort ?? 'latest';
        match ($sort) {
            'price_asc'  => $query->orderBy('price', 'asc'),
            'price_desc' => $query->orderBy('price', 'desc'),
            default      => $query->latest('published_at'),
        };

        $ebooks = $query->paginate(12);

        return response()->json($ebooks);
    }

    // Detail buku — publik
    public function show(Request $request, string $slug)
    {
        $ebook = Ebook::published()
                    ->with('category')
                    ->where('slug', $slug)
                    ->firstOrFail();

        // Cek apakah user (jika login) sudah punya buku ini
        $owned = false;
        if ($request->user()) {
            $owned = $request->user()->ownsEbook($ebook->id);
        }

        return response()->json([
            'ebook' => $ebook,
            'owned' => $owned,
        ]);
    }

    // Daftar kategori
    public function categories()
    {
        return response()->json(Category::all());
    }
}