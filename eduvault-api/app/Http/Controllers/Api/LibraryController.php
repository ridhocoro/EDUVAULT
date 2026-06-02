<?php
// app/Http/Controllers/Api/LibraryController.php — REPLACE file lama
// Perubahan: support filter source_type (all/purchase/subscription) + search

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class LibraryController extends Controller
{
    /**
     * Daftar buku milik user.
     * Query params:
     *   - source: all (default) | purchase | subscription | free
     *   - search: string (cari judul / author)
     */
    public function index(Request $request)
    {
        $query = $request->user()
            ->library()
            ->with('category');

        // ── Filter source_type ──────────────────────────────────
        $source = $request->query('source', 'all');
        if (in_array($source, ['purchase', 'subscription', 'free'])) {
            $query->wherePivot('source_type', $source);
        }

        // ── Search ──────────────────────────────────────────────
        if ($search = $request->query('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                  ->orWhere('author', 'like', "%{$search}%");
            });
        }

        $library = $query->paginate(12);

        // Enrichment pivot fields ke tiap item
        $library->getCollection()->transform(function ($ebook) {
            $ebook->is_finished     = (bool) $ebook->pivot->is_finished;
            $ebook->finished_at     = $ebook->pivot->finished_at;
            $ebook->source_type     = $ebook->pivot->source_type ?? 'purchase';
            $ebook->library_expires = $ebook->pivot->expires_at;

            // Cek apakah akses subscription sudah expired
            $ebook->subscription_expired = (
                $ebook->source_type === 'subscription'
                && $ebook->library_expires !== null
                && now()->gt($ebook->library_expires)
            );

            return $ebook;
        });

        return response()->json($library);
    }

    /** Tandai buku sebagai selesai */
    public function finish(Request $request, int $id)
    {
        $ebook = $request->user()->library()->findOrFail($id);

        if ($ebook->pivot->is_finished) {
            return response()->json([
                'message'     => 'Buku sudah ditandai selesai.',
                'is_finished' => true,
                'finished_at' => $ebook->pivot->finished_at,
            ]);
        }

        $request->user()->library()->updateExistingPivot($id, [
            'is_finished' => true,
            'finished_at' => now(),
        ]);

        return response()->json([
            'message'     => 'Buku berhasil ditandai selesai.',
            'is_finished' => true,
            'finished_at' => now()->toDateTimeString(),
        ]);
    }

    /** Dapatkan URL baca PDF — hanya jika akses masih valid */
    public function getReadUrl(Request $request, int $id)
    {
        $ebook = $request->user()->library()->findOrFail($id);

        // Blok akses jika subscription expired
        $sourceType = $ebook->pivot->source_type ?? 'purchase';
        $expiresAt  = $ebook->pivot->expires_at;

        if ($sourceType === 'subscription' && $expiresAt && now()->gt($expiresAt)) {
            return response()->json([
                'message' => 'Langganan kamu telah berakhir. Perbarui langganan untuk mengakses buku ini.',
                'subscription_expired' => true,
            ], 403);
        }

        if (empty($ebook->getRawOriginal('file_url'))) {
            return response()->json(['message' => 'File buku tidak tersedia.'], 404);
        }

        $url = Storage::disk('public')->url($ebook->getRawOriginal('file_url'));

        return response()->json(['read_url' => $url]);
    }
}
