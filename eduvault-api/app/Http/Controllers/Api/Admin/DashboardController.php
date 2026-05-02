<?php
// app/Http/Controllers/Api/Admin/DashboardController.php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Ebook;
use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    /**
     * Statistik ringkasan dashboard admin
     */
    public function stats()
    {
        $totalEbooks     = Ebook::count();
        $publishedEbooks = Ebook::where('status', 'published')->count();
        $draftEbooks     = Ebook::where('status', 'draft')->count();
        $archivedEbooks  = Ebook::where('status', 'archived')->count();

        $totalUsers  = User::where('role', 'user')->count();
        $totalAdmins = User::where('role', 'admin')->count();

        $totalOrders   = Order::count();
        $paidOrders    = Order::where('status', 'paid')->count();
        $pendingOrders = Order::where('status', 'pending')->count();

        $totalRevenue = Order::where('status', 'paid')->sum('total_amount');

        // Buku terlaris (berdasarkan order items)
        $topEbooks = Ebook::select('ebooks.*')
            ->selectRaw('COUNT(order_items.id) as sales_count')
            ->leftJoin('order_items', 'ebooks.id', '=', 'order_items.ebook_id')
            ->leftJoin('orders', function ($join) {
                $join->on('orders.id', '=', 'order_items.order_id')
                     ->where('orders.status', '=', 'paid');
            })
            ->groupBy('ebooks.id')
            ->orderByDesc('sales_count')
            ->limit(5)
            ->with('category')
            ->get();

        return response()->json([
            'ebooks' => [
                'total'     => $totalEbooks,
                'published' => $publishedEbooks,
                'draft'     => $draftEbooks,
                'archived'  => $archivedEbooks,
            ],
            'users' => [
                'total'  => $totalUsers,
                'admins' => $totalAdmins,
            ],
            'orders' => [
                'total'   => $totalOrders,
                'paid'    => $paidOrders,
                'pending' => $pendingOrders,
            ],
            'revenue' => [
                'total' => (float) $totalRevenue,
            ],
            'top_ebooks' => $topEbooks,
        ]);
    }
}
