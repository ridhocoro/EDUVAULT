<?php
// app/Http/Controllers/Api/Admin/EbookController.php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Ebook;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class EbookController extends Controller
{
    /**
     * Daftar semua ebook (termasuk draft & archived) — khusus admin
     */
    public function index(Request $request)
    {
        $query = Ebook::with('category')->latest();

        if ($search = $request->query('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                  ->orWhere('author', 'like', "%{$search}%");
            });
        }

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($categorySlug = $request->query('category')) {
            $query->whereHas('category', fn ($q) => $q->where('slug', $categorySlug));
        }

        $perPage = min((int) $request->query('per_page', 20), 100);

        return response()->json($query->paginate($perPage));
    }

    /**
     * Detail satu ebook (admin bisa lihat file_url)
     */
    public function show(int $id)
    {
        $ebook = Ebook::with('category')->findOrFail($id);

        return response()->json(array_merge($ebook->toArray(), [
            'file_url' => $ebook->getRawOriginal('file_url'),
        ]));
    }

    /**
     * Tambah buku baru
     */
    public function store(Request $request)
    {
        $data = $request->validate([
            'title'        => 'required|string|max:255',
            'description'  => 'nullable|string',
            'author'       => 'nullable|string|max:255',
            'price'        => 'required|numeric|min:0',
            'cover_url'    => 'nullable|url|max:2048',
            'file_url'     => 'nullable|url|max:2048',
            'djki_cert_no' => 'nullable|string|max:100',
            'total_pages'  => 'nullable|integer|min:0',
            'category_id'  => 'required|exists:categories,id',
            'status'       => 'nullable|in:draft,published,archived',
        ]);

        $slug = Str::slug($data['title']);
        $originalSlug = $slug;
        $counter = 1;
        while (Ebook::where('slug', $slug)->exists()) {
            $slug = "{$originalSlug}-{$counter}";
            $counter++;
        }

        $ebook = Ebook::create([
            ...$data,
            'slug'         => $slug,
            'status'       => $data['status'] ?? 'draft',
            'total_pages'  => $data['total_pages'] ?? 0,
            'published_at' => ($data['status'] ?? 'draft') === 'published' ? now() : null,
        ]);

        return response()->json($ebook->load('category'), 201);
    }

    /**
     * Update data buku (partial update support)
     */
    public function update(Request $request, int $id)
    {
        $ebook = Ebook::findOrFail($id);

        $data = $request->validate([
            'title'        => 'sometimes|required|string|max:255',
            'description'  => 'nullable|string',
            'author'       => 'nullable|string|max:255',
            'price'        => 'sometimes|required|numeric|min:0',
            'cover_url'    => 'nullable|url|max:2048',
            'file_url'     => 'nullable|url|max:2048',
            'djki_cert_no' => 'nullable|string|max:100',
            'total_pages'  => 'nullable|integer|min:0',
            'category_id'  => 'sometimes|required|exists:categories,id',
            'status'       => 'sometimes|required|in:draft,published,archived',
        ]);

        if (isset($data['title']) && $data['title'] !== $ebook->title) {
            $slug = Str::slug($data['title']);
            $originalSlug = $slug;
            $counter = 1;
            while (Ebook::where('slug', $slug)->where('id', '!=', $ebook->id)->exists()) {
                $slug = "{$originalSlug}-{$counter}";
                $counter++;
            }
            $data['slug'] = $slug;
        }

        if (isset($data['status']) && $data['status'] === 'published' && ! $ebook->published_at) {
            $data['published_at'] = now();
        }

        $ebook->update($data);

        return response()->json($ebook->fresh('category'));
    }

    /**
     * Upload file PDF atau EPUB untuk sebuah buku.
     * Menyimpan ke storage/app/public/ebooks/{id}/
     * dan meng-update kolom file_url di tabel ebooks.
     */
    public function uploadFile(Request $request, int $id)
    {
        $ebook = Ebook::findOrFail($id);

        $request->validate([
            'file' => 'required|file|mimes:pdf,epub|max:102400', // max 100 MB
        ]);

        // Hapus file lama jika ada
        $oldPath = $ebook->getRawOriginal('file_url');
        if ($oldPath && Storage::disk('public')->exists($oldPath)) {
            Storage::disk('public')->delete($oldPath);
        }

        // Simpan file baru ke storage/app/public/ebooks/{id}/
        $file = $request->file('file');
        $filename = Str::slug(pathinfo($file->getClientOriginalName(), PATHINFO_FILENAME))
                  . '_' . time()
                  . '.' . $file->getClientOriginalExtension();

        $path = $file->storeAs("ebooks/{$id}", $filename, 'public');

        // Simpan path relatif ke DB (bukan full URL, biar fleksibel)
        $ebook->update(['file_url' => $path]);

        return response()->json([
            'message'  => 'File berhasil diupload.',
            'file_url' => Storage::disk('public')->url($path),
        ]);
    }

    /**
     * Hapus file PDF/EPUB dari storage dan kosongkan file_url di DB.
     */
    public function deleteFile(int $id)
    {
        $ebook = Ebook::findOrFail($id);

        $path = $ebook->getRawOriginal('file_url');

        if (empty($path)) {
            return response()->json(['message' => 'Tidak ada file untuk dihapus.'], 404);
        }

        if (Storage::disk('public')->exists($path)) {
            Storage::disk('public')->delete($path);
        }

        $ebook->update(['file_url' => null]);

        return response()->json(['message' => 'File berhasil dihapus.']);
    }

    /**
     * Nonaktifkan buku (set status → archived)
     */
    public function deactivate(int $id)
    {
        $ebook = Ebook::findOrFail($id);

        if ($ebook->status === 'archived') {
            return response()->json(['message' => 'Buku sudah dinonaktifkan.'], 422);
        }

        $ebook->update(['status' => 'archived']);

        return response()->json([
            'message' => 'Buku berhasil dinonaktifkan.',
            'ebook'   => $ebook->fresh('category'),
        ]);
    }

    /**
     * Aktifkan kembali buku yang ter-archive (→ published)
     */
    public function activate(int $id)
    {
        $ebook = Ebook::findOrFail($id);

        $ebook->update([
            'status'       => 'published',
            'published_at' => $ebook->published_at ?? now(),
        ]);

        return response()->json([
            'message' => 'Buku berhasil diaktifkan.',
            'ebook'   => $ebook->fresh('category'),
        ]);
    }

    /**
     * Upload gambar cover untuk sebuah buku.
     * Menerima file image (jpg/jpeg/png/webp), simpan ke storage/app/public/covers/{id}/
     * dan update kolom cover_url di tabel ebooks dengan full public URL.
     */
    public function uploadCover(Request $request, int $id)
    {
        $ebook = Ebook::findOrFail($id);

        $request->validate([
            'cover' => 'required|file|mimes:jpg,jpeg,png,webp|max:5120', // max 5 MB
        ]);

        // Hapus cover lama dari storage jika disimpan lokal (bukan URL eksternal)
        $oldCover = $ebook->getRawOriginal('cover_url');
        if ($oldCover && !str_starts_with($oldCover, 'http')) {
            if (Storage::disk('public')->exists($oldCover)) {
                Storage::disk('public')->delete($oldCover);
            }
        }

        $file = $request->file('cover');
        $filename = 'cover_' . time() . '.' . $file->getClientOriginalExtension();
        $path = $file->storeAs("covers/{$id}", $filename, 'public');

        // Simpan full public URL ke DB agar langsung bisa dipakai di frontend
        $fullUrl = Storage::disk('public')->url($path);
        $ebook->update(['cover_url' => $fullUrl]);

        return response()->json([
            'message'   => 'Cover berhasil diupload.',
            'cover_url' => $fullUrl,
        ]);
    }

    /**
     * Hapus cover dari storage dan kosongkan cover_url di DB.
     */
    public function deleteCover(int $id)
    {
        $ebook = Ebook::findOrFail($id);

        $coverUrl = $ebook->getRawOriginal('cover_url');

        if (empty($coverUrl)) {
            return response()->json(['message' => 'Tidak ada cover untuk dihapus.'], 404);
        }

        // Hanya hapus file fisik jika disimpan lokal
        if (!str_starts_with($coverUrl, 'http')) {
            if (Storage::disk('public')->exists($coverUrl)) {
                Storage::disk('public')->delete($coverUrl);
            }
        } else {
            // Cover dari URL eksternal — coba parse path relatifnya
            $parsed = parse_url($coverUrl, PHP_URL_PATH);
            $storagePath = ltrim(str_replace('/storage/', '', $parsed), '/');
            if ($storagePath && Storage::disk('public')->exists($storagePath)) {
                Storage::disk('public')->delete($storagePath);
            }
        }

        $ebook->update(['cover_url' => null]);

        return response()->json(['message' => 'Cover berhasil dihapus.']);
    }

    /**
     * Hapus permanen buku — hard delete
     */
    public function destroy(int $id)
    {
        $ebook = Ebook::findOrFail($id);

        // Hapus file fisik juga jika ada
        $path = $ebook->getRawOriginal('file_url');
        if ($path && Storage::disk('public')->exists($path)) {
            Storage::disk('public')->delete($path);
        }

        $ebook->delete();

        return response()->json(['message' => 'Buku berhasil dihapus.'], 200);
    }
}