<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Wishlist;
use App\Models\Ebook;
use Illuminate\Http\Request;

class WishlistController extends Controller
{
    /**
     * Ambil semua wishlist milik user yang sedang login
     */
    public function index(Request $request)
    {
        $wishlists = Wishlist::with('ebook.category')
            ->where('user_id', $request->user()->id)
            ->latest()
            ->get();

        return response()->json($wishlists);
    }

    /**
     * Tambah buku ke wishlist
     */
    public function store(Request $request, int $ebookId)
    {
        $ebook = Ebook::published()->findOrFail($ebookId);

        $wishlist = Wishlist::firstOrCreate([
            'user_id'  => $request->user()->id,
            'ebook_id' => $ebookId,
        ]);

        return response()->json([
            'message'     => 'Buku ditambahkan ke wishlist.',
            'wishlist_id' => $wishlist->id,
            'in_wishlist' => true,
        ], 201);
    }

    /**
     * Hapus buku dari wishlist
     */
    public function destroy(Request $request, int $ebookId)
    {
        $deleted = Wishlist::where('user_id', $request->user()->id)
            ->where('ebook_id', $ebookId)
            ->delete();

        if (!$deleted) {
            return response()->json(['message' => 'Item tidak ada di wishlist.'], 404);
        }

        return response()->json([
            'message'     => 'Buku dihapus dari wishlist.',
            'in_wishlist' => false,
        ]);
    }

    /**
     * Cek apakah sebuah buku ada di wishlist user
     */
    public function check(Request $request, int $ebookId)
    {
        $inWishlist = Wishlist::where('user_id', $request->user()->id)
            ->where('ebook_id', $ebookId)
            ->exists();

        return response()->json(['in_wishlist' => $inWishlist]);
    }
}
