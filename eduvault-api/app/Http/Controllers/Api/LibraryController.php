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

        return response()->json($library);
    }

    // Dapatkan URL baca sementara (signed URL, berlaku 2 jam)
    public function getReadUrl(Request $request, int $id)
    {
        $ebook = $request->user()->library()->findOrFail($id);

        // Buat signed URL yang expired setelah 2 jam
        // Mencegah user menyebarkan link PDF secara bebas
        $url = Storage::disk('s3')->temporaryUrl(
            $ebook->file_url,
            now()->addHours(2)
        );

        return response()->json(['read_url' => $url]);
    }
}