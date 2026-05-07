<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class VerifyBookOwnership
{
    /**
     * Handle an incoming request.
     * Memverifikasi bahwa user sudah memiliki buku sebelum bisa chat dengan AI
     */
    public function handle(Request $request, Closure $next)
    {
        $user = $request->user();
        $bookId = $request->route('book_id');

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthenticated'
            ], 401);
        }

        // Cek apakah user memiliki buku ini
        if (!$user->ownsEbook($bookId)) {
            return response()->json([
                'success' => false,
                'message' => 'Anda belum membeli buku ini. Silakan beli terlebih dahulu untuk menggunakan fitur AI Chat.'
            ], 403);
        }

        return $next($request);
    }
}