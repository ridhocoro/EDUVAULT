<?php
// app/Http/Controllers/Api/OrderController.php — REPLACE file lama
// Perubahan: paymentNotification sekarang handle order_type = subscription

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Ebook;
use App\Models\Order;
use App\Models\UserSubscription;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Midtrans\Config as MidtransConfig;
use Midtrans\Snap;

class OrderController extends Controller
{
    public function __construct()
    {
        MidtransConfig::$serverKey    = config('services.midtrans.server_key');
        MidtransConfig::$isProduction = config('services.midtrans.is_production');
        MidtransConfig::$isSanitized  = config('services.midtrans.is_sanitized', true);
        MidtransConfig::$is3ds        = config('services.midtrans.is_3ds', true);
    }

    // ── Buat order beli satuan ─────────────────────────────────────
    public function store(Request $request)
    {
        $data = $request->validate([
            'ebook_ids'   => 'required|array|min:1',
            'ebook_ids.*' => 'integer|exists:ebooks,id',
        ]);

        $ebooks = Ebook::published()->whereIn('id', $data['ebook_ids'])->get();

        if ($ebooks->count() !== count($data['ebook_ids'])) {
            return response()->json(['message' => 'Satu atau lebih buku tidak ditemukan.'], 422);
        }

        foreach ($ebooks as $ebook) {
            if ($request->user()->ownsEbook($ebook->id)) {
                return response()->json([
                    'message' => "Kamu sudah memiliki buku \"{$ebook->title}\".",
                ], 422);
            }
        }

        $totalAmount = $ebooks->sum('price');

        DB::beginTransaction();
        try {
            $order = Order::create([
                'user_id'           => $request->user()->id,
                'order_code'        => Order::generateCode(),
                'midtrans_order_id' => 'EDU-' . strtoupper(uniqid()),
                'total_amount'      => $totalAmount,
                'status'            => 'pending',
                'order_type'        => 'ebook',
            ]);

            foreach ($ebooks as $ebook) {
                $order->items()->create([
                    'ebook_id' => $ebook->id,
                    'price'    => $ebook->price,
                ]);
            }

            $user = $request->user();

            $itemDetails = $ebooks->map(fn ($e) => [
                'id'       => (string) $e->id,
                'price'    => (int) $e->price,
                'quantity' => 1,
                'name'     => mb_substr($e->title, 0, 50),
            ])->values()->toArray();

            $params = [
                'transaction_details' => [
                    'order_id'     => $order->midtrans_order_id,
                    'gross_amount' => (int) $totalAmount,
                ],
                'item_details'     => $itemDetails,
                'customer_details' => [
                    'first_name' => $user->name,
                    'email'      => $user->email,
                ],
            ];

            $snapToken = Snap::getSnapToken($params);
            $order->update(['midtrans_token' => $snapToken]);

            DB::commit();

            return response()->json([
                'order'      => $order->load('items.ebook.category'),
                'snap_token' => $snapToken,
                'client_key' => config('services.midtrans.client_key'),
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'message' => 'Gagal membuat order: ' . $e->getMessage(),
            ], 500);
        }
    }

    // ── Riwayat order user ────────────────────────────────────────
    public function index(Request $request)
    {
        $orders = Order::where('user_id', $request->user()->id)
            ->with([
                'items' => fn ($q) => $q->select('id', 'order_id', 'ebook_id', 'price'),
                'items.ebook' => fn ($q) => $q->select(
                    'id', 'title', 'author', 'cover_url', 'price', 'total_pages', 'category_id'
                ),
                'items.ebook.category' => fn ($q) => $q->select('id', 'name'),
            ])
            ->latest()
            ->paginate(10);

        return response()->json([
            'success' => true,
            'message' => 'Riwayat transaksi berhasil diambil',
            'data'    => $orders->items(),
            'meta'    => [
                'current_page' => $orders->currentPage(),
                'last_page'    => $orders->lastPage(),
                'total'        => $orders->total(),
            ],
        ]);
    }

    // ── Detail satu order ─────────────────────────────────────────
    public function show(Request $request, string $code)
    {
        $order = Order::where('user_id', $request->user()->id)
            ->where('order_code', $code)
            ->with([
                'items.ebook.category',
            ])
            ->firstOrFail();

        return response()->json(['success' => true, 'data' => $order]);
    }

    // ── Webhook Midtrans — menangani ebook DAN subscription ───────
    public function paymentNotification(Request $request)
    {
        $data = $request->all();

        $signatureKey = hash('sha512',
            $data['order_id'] .
            $data['status_code'] .
            $data['gross_amount'] .
            config('services.midtrans.server_key')
        );

        if ($signatureKey !== ($data['signature_key'] ?? '')) {
            return response()->json(['message' => 'Invalid signature.'], 403);
        }

        $order = Order::where('midtrans_order_id', $data['order_id'])
                      ->with('items')
                      ->first();

        if (! $order) {
            return response()->json(['message' => 'Order not found.'], 404);
        }

        $status = $data['transaction_status'] ?? '';

        if (in_array($status, ['capture', 'settlement'])) {
            if ($order->status === 'paid') {
                return response()->json(['message' => 'Already processed.']);
            }

            $order->update([
                'status'         => 'paid',
                'payment_method' => $data['payment_type'] ?? null,
                'paid_at'        => now(),
            ]);

            // ── Beli satuan ebook ────────────────────────────────
            if ($order->order_type === 'ebook') {
                foreach ($order->items as $item) {
                    DB::table('user_library')->insertOrIgnore([
                        'user_id'     => $order->user_id,
                        'ebook_id'    => $item->ebook_id,
                        'order_id'    => $order->id,
                        'license_type'=> 'individual',
                        'source_type' => 'purchase',
                        'created_at'  => now(),
                        'updated_at'  => now(),
                    ]);
                }

            // ── Beli subscription ────────────────────────────────
            } elseif ($order->order_type === 'subscription' && $order->subscription_plan_id) {
                $plan = \App\Models\SubscriptionPlan::with('ebooks')
                    ->find($order->subscription_plan_id);

                if ($plan) {
                    $startsAt  = now();
                    $expiresAt = now()->addDays($plan->duration_days);

                    // Buat record UserSubscription
                    $sub = UserSubscription::create([
                        'user_id'              => $order->user_id,
                        'subscription_plan_id' => $plan->id,
                        'order_id'             => $order->id,
                        'starts_at'            => $startsAt,
                        'expires_at'           => $expiresAt,
                        'status'               => 'active',
                    ]);

                    // Tambahkan tiap buku dalam paket ke library user
                    foreach ($plan->ebooks as $ebook) {
                        DB::table('user_library')->insertOrIgnore([
                            'user_id'         => $order->user_id,
                            'ebook_id'        => $ebook->id,
                            'order_id'        => $order->id,
                            'license_type'    => 'individual',
                            'source_type'     => 'subscription',
                            'subscription_id' => $sub->id,
                            'expires_at'      => $expiresAt,
                            'created_at'      => now(),
                            'updated_at'      => now(),
                        ]);
                    }
                }
            }

        } elseif (in_array($status, ['cancel', 'deny', 'expire'])) {
            $order->update(['status' => 'failed']);
        }

        return response()->json(['message' => 'OK']);
    }
}
