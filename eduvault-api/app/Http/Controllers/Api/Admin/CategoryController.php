<?php
// app/Http/Controllers/Api/Admin/CategoryController.php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class CategoryController extends Controller
{
    public function index()
    {
        $categories = Category::withCount('ebooks')->orderBy('name')->get();
        return response()->json($categories);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:100|unique:categories,name',
            'icon' => 'nullable|string|max:50',
        ]);

        $data['slug'] = Str::slug($data['name']);

        if (Category::where('slug', $data['slug'])->exists()) {
            return response()->json(['message' => 'Slug kategori sudah ada.'], 422);
        }

        $category = Category::create($data);
        return response()->json($category, 201);
    }

    public function update(Request $request, int $id)
    {
        $category = Category::findOrFail($id);

        $data = $request->validate([
            'name' => "sometimes|required|string|max:100|unique:categories,name,{$id}",
            'icon' => 'nullable|string|max:50',
        ]);

        if (isset($data['name'])) {
            $data['slug'] = Str::slug($data['name']);
        }

        $category->update($data);
        return response()->json($category->fresh());
    }

    public function destroy(int $id)
    {
        $category = Category::withCount('ebooks')->findOrFail($id);

        if ($category->ebooks_count > 0) {
            return response()->json([
                'message' => "Kategori tidak bisa dihapus karena masih memiliki {$category->ebooks_count} buku.",
            ], 422);
        }

        $category->delete();
        return response()->json(['message' => 'Kategori berhasil dihapus.']);
    }
}
