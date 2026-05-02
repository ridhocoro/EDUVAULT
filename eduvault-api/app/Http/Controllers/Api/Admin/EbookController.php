<?php
// app/Http/Controllers/Api/Admin/EbookController.php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Ebook;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class EbookController extends Controller
{
    /**
     * Daftar semua ebook (termasuk draft & archived) — khusus admin
     * Query params:
     *   - search   : string
     *   - status   : draft | published | archived
     *   - category : category slug
     *   - per_page : int (default 20, max 100)
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

        // Admin dapat melihat file_url, expose manual karena model menyembunyikannya
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

        // Auto-generate slug dari title, pastikan unik
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

        // Update slug jika title berubah
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

        // Jika status berubah ke published dan belum ada published_at
        if (isset($data['status']) && $data['status'] === 'published' && ! $ebook->published_at) {
            $data['published_at'] = now();
        }

        $ebook->update($data);

        return response()->json($ebook->fresh('category'));
    }

    /**
     * Nonaktifkan buku (set status → archived) tanpa hapus data
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
     * Hapus permanen buku — hati-hati, ini hard delete
     */
    public function destroy(int $id)
    {
        $ebook = Ebook::findOrFail($id);
        $ebook->delete();

        return response()->json(['message' => 'Buku berhasil dihapus.'], 200);
    }
}
