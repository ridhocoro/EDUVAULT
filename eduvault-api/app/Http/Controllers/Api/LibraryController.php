<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class LibraryController extends Controller
{
    // Daftar buku yang dimiliki user
    public function index(Request $request)
    {
        $library = $request->user()
                        ->library()
                        ->with('category')
                        ->paginate(12);

        // Tambahkan is_finished dari pivot ke tiap item
        $library->getCollection()->transform(function ($ebook) {
            $ebook->is_finished  = (bool) $ebook->pivot->is_finished;
            $ebook->finished_at  = $ebook->pivot->finished_at;
            return $ebook;
        });

        return response()->json($library);
    }

    // Tandai buku sebagai selesai (tidak bisa di-undo)
    public function finish(Request $request, int $id)
    {
        $ebook = $request->user()->library()->findOrFail($id);

        // Jika sudah selesai, kembalikan response tanpa mengubah apapun
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

    // Dapatkan URL baca untuk membuka PDF
    public function getReadUrl(Request $request, int $id)
    {
        $ebook = $request->user()->library()->findOrFail($id);

        if (empty($ebook->file_url)) {
            return response()->json(
                ['message' => 'File buku tidak tersedia.'],
                404
            );
        }

        $url = Storage::disk('public')->url($ebook->file_url);

        return response()->json(['read_url' => $url]);
    }
}
