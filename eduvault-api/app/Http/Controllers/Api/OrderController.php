<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Ebook;
use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Midtrans\Config as MidtransConfig;
use Midtrans\Snap;

class OrderController extends Controller
{
    public function __construct()
    {
        // Konfigurasi Midtrans dari services.php / .env
        MidtransConfig::$serverKey    = config('services.midtrans.server_key');
        MidtransConfig::$isProduction = config('services.midtrans.is_production');
        MidtransConfig::$isSanitized  = config('services.midtrans.is_sanitized');
        MidtransConfig::$is3ds        = config('services.midtrans.is_3ds');
    }

    // ── Buat order + dapatkan Snap Token Midtrans ─────────────────
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
            ]);

            foreach ($ebooks as $ebook) {
                $order->items()->create([
                    'ebook_id' => $ebook->id,
                    'price'    => $ebook->price,
                ]);
            }

            // ── Generate Snap Token Midtrans ──────────────────────
            $user = $request->user();

            $itemDetails = $ebooks->map(fn ($e) => [
                'id'       => (string) $e->id,
                'price'    => (int) $e->price,
                'quantity' => 1,
                'name'     => mb_substr($e->title, 0, 50), // Midtrans max 50 char
            ])->values()->toArray();

            $params = [
                'transaction_details' => [
                    'order_id'     => $order->midtrans_order_id,
                    'gross_amount' => (int) $totalAmount,
                ],
                'item_details'    => $itemDetails,
                'customer_details' => [
                    'first_name' => $user->name,
                    'email'      => $user->email,
                ],
            ];

            $snapToken = Snap::getSnapToken($params);

            $order->update(['midtrans_token' => $snapToken]);

            DB::commit();

            return response()->json([
                'order'       => $order->load('items.ebook'),
                'snap_token'  => $snapToken,
                'client_key'  => config('services.midtrans.client_key'),
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
                    ->with('items.ebook')
                    ->latest()
                    ->paginate(10);

        return response()->json($orders);
    }

    // ── Detail satu order ─────────────────────────────────────────
    public function show(Request $request, string $code)
    {
        $order = Order::where('user_id', $request->user()->id)
                    ->where('order_code', $code)
                    ->with('items.ebook')
                    ->firstOrFail();

        return response()->json($order);
    }

    // ── Webhook Midtrans (dipanggil otomatis oleh server Midtrans) ─
    public function paymentNotification(Request $request)
    {
        $data = $request->all();

        // Verifikasi signature key
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
            // Hindari double-processing jika sudah paid
            if ($order->status === 'paid') {
                return response()->json(['message' => 'Already processed.']);
            }

            $order->update([
                'status'         => 'paid',
                'payment_method' => $data['payment_type'] ?? null,
                'paid_at'        => now(),
            ]);

            // Masukkan semua buku ke library user
            foreach ($order->items as $item) {
                DB::table('user_library')->insertOrIgnore([
                    'user_id'      => $order->user_id,
                    'ebook_id'     => $item->ebook_id,
                    'order_id'     => $order->id,
                    'license_type' => 'individual',
                    'created_at'   => now(),
                    'updated_at'   => now(),
                ]);
            }
        } elseif (in_array($status, ['cancel', 'deny', 'expire'])) {
            $order->update(['status' => 'failed']);
        }

        return response()->json(['message' => 'OK']);
    }
}
