<?php
// app/Http/Controllers/Api/EbookController.php
// REPLACE file lama dengan file ini

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Ebook;
use Illuminate\Http\Request;

class EbookController extends Controller
{
    /**
     * Daftar ebook (publik)
     * Query params:
     *   - search    : string  → cari di title dan author
     *   - category  : string  → filter by category slug
     *   - min_price : number  → harga minimum
     *   - max_price : number  → harga maksimum
     *   - sort      : string  → price_asc | price_desc | newest (default: newest)
     *   - per_page  : int     → default 20
     */
    public function index(Request $request)
    {
        $query = Ebook::with('category')->published();

        // ── Search ─────────────────────────────────────────────
        if ($search = $request->query('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                  ->orWhere('author', 'like', "%{$search}%")
                  ->orWhere('description', 'like', "%{$search}%");
            });
        }

        // ── Filter kategori ───────────────────────────────────
        if ($categorySlug = $request->query('category')) {
            $query->whereHas('category', function ($q) use ($categorySlug) {
                $q->where('slug', $categorySlug);
            });
        }

        // ── Filter harga ──────────────────────────────────────
        if ($request->filled('min_price')) {
            $query->where('price', '>=', (float) $request->query('min_price'));
        }

        if ($request->filled('max_price')) {
            $query->where('price', '<=', (float) $request->query('max_price'));
        }

        // ── Sort ──────────────────────────────────────────────
        $sort = $request->query('sort', 'newest');
        match ($sort) {
            'price_asc'  => $query->orderBy('price', 'asc'),
            'price_desc' => $query->orderBy('price', 'desc'),
            default      => $query->latest('published_at'),
        };

        $perPage = min((int) $request->query('per_page', 20), 100);
        $ebooks = $query->paginate($perPage);

        return response()->json($ebooks);
    }

    /**
     * Detail ebook by slug
     * Mengembalikan { ebook, owned } agar Flutter tahu apakah user sudah beli.
     * Jika belum login (guest), owned selalu false.
     */
    public function show(Request $request, string $slug)
    {
        $ebook = Ebook::with('category')
            ->published()
            ->where('slug', $slug)
            ->firstOrFail();

        $owned = false;
        $user  = $request->user(); // null jika belum login (route publik)
        if ($user) {
            $owned = $user->ownsEbook($ebook->id);
        }

        return response()->json([
            'ebook' => $ebook,
            'owned' => $owned,
        ]);
    }

    /**
     * Daftar kategori
     */
    public function categories()
    {
        $categories = Category::orderBy('name')->get();
        return response()->json($categories);
    }
}
