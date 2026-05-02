<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Review;
use App\Models\Ebook;
use Illuminate\Http\Request;

class ReviewController extends Controller
{
    /**
     * Ambil semua review untuk sebuah ebook (publik, tidak perlu login)
     */
    public function index(int $ebookId)
    {
        $reviews = Review::with('user:id,name,avatar')
            ->where('ebook_id', $ebookId)
            ->latest()
            ->paginate(20);

        $avg   = Review::where('ebook_id', $ebookId)->avg('rating');
        $total = Review::where('ebook_id', $ebookId)->count();

        return response()->json([
            'reviews'        => $reviews,
            'average_rating' => $avg ? round((float)$avg, 1) : null,
            'total_reviews'  => $total,
        ]);
    }

    /**
     * Simpan atau update review (hanya user yang sudah beli buku)
     */
    public function store(Request $request, int $ebookId)
    {
        $request->validate([
            'rating'  => 'required|integer|min:1|max:5',
            'comment' => 'nullable|string|max:1000',
        ]);

        $user  = $request->user();
        $ebook = Ebook::published()->findOrFail($ebookId);

        if (!$user->ownsEbook($ebookId)) {
            return response()->json([
                'message' => 'Kamu hanya bisa mengulas buku yang sudah dibeli.',
            ], 403);
        }

        $review = Review::updateOrCreate(
            ['user_id' => $user->id, 'ebook_id' => $ebookId],
            ['rating'  => $request->rating, 'comment' => $request->comment],
        );

        $review->load('user:id,name,avatar');

        return response()->json($review, 201);
    }

    /**
     * Hapus review milik user yang sedang login
     */
    public function destroy(Request $request, int $ebookId)
    {
        $deleted = Review::where('user_id', $request->user()->id)
            ->where('ebook_id', $ebookId)
            ->delete();

        if (!$deleted) {
            return response()->json(['message' => 'Review tidak ditemukan.'], 404);
        }

        return response()->json(['message' => 'Review berhasil dihapus.']);
    }
}
