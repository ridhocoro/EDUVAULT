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

    // Dapatkan URL baca untuk membuka PDF
    // Menggunakan public disk (local storage), bukan S3
    public function getReadUrl(Request $request, int $id)
    {
        $ebook = $request->user()->library()->findOrFail($id);

        if (empty($ebook->file_url)) {
            return response()->json(
                ['message' => 'File buku tidak tersedia.'],
                404
            );
        }

        // file_url sudah berupa path relatif di storage/app/public
        // misalnya: "ebooks/somefile.pdf"
        // Storage::disk('public')->url() akan menghasilkan URL publik yang benar
        $url = Storage::disk('public')->url($ebook->file_url);

        return response()->json(['read_url' => $url]);
    }
}