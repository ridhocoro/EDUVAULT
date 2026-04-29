<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Ebook;
use App\Models\Order;
use App\Models\UserLibrary;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class OrderController extends Controller
{
    // Buat order baru
    public function store(Request $request)
    {
        $data = $request->validate([
            'ebook_ids'      => 'required|array|min:1',
            'ebook_ids.*'    => 'integer|exists:ebooks,id',
        ]);

        // Ambil data buku yang akan dibeli
        $ebooks = Ebook::published()->whereIn('id', $data['ebook_ids'])->get();

        if ($ebooks->count() !== count($data['ebook_ids'])) {
            return response()->json(['message' => 'Satu atau lebih buku tidak ditemukan.'], 422);
        }

        // Cek jika user sudah punya salah satu buku
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
            // Buat order
            $order = Order::create([
                'user_id'      => $request->user()->id,
                'order_code'   => Order::generateCode(),
                'total_amount' => $totalAmount,
                'status'       => 'pending',
            ]);

            // Buat order items
            foreach ($ebooks as $ebook) {
                $order->items()->create([
                    'ebook_id' => $ebook->id,
                    'price'    => $ebook->price,
                ]);
            }

            // TODO: Generate Midtrans Snap Token di sini
            // $snapToken = $this->getMidtransToken($order);
            // $order->update(['midtrans_token' => $snapToken]);

            DB::commit();

            return response()->json([
                'order'      => $order->load('items.ebook'),
                'snap_token' => null, // isi nanti setelah setup Midtrans
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => 'Gagal membuat order.'], 500);
        }
    }

    // Riwayat order user
    public function index(Request $request)
    {
        $orders = Order::where('user_id', $request->user()->id)
                    ->with('items.ebook')
                    ->latest()
                    ->paginate(10);

        return response()->json($orders);
    }

    // Detail satu order
    public function show(Request $request, string $code)
    {
        $order = Order::where('user_id', $request->user()->id)
                    ->where('order_code', $code)
                    ->with('items.ebook')
                    ->firstOrFail();

        return response()->json($order);
    }

    // Webhook Midtrans — dipanggil otomatis oleh server Midtrans
    public function paymentNotification(Request $request)
    {
        $data = $request->all();

        // Verifikasi signature key dari Midtrans
        $signatureKey = hash('sha512',
            $data['order_id'] .
            $data['status_code'] .
            $data['gross_amount'] .
            config('services.midtrans.server_key')
        );

        if ($signatureKey !== $data['signature_key']) {
            return response()->json(['message' => 'Invalid signature.'], 403);
        }

        $order = Order::where('midtrans_order_id', $data['order_id'])->first();

        if (! $order) {
            return response()->json(['message' => 'Order not found.'], 404);
        }

        // Update status berdasarkan notifikasi Midtrans
        if (in_array($data['transaction_status'], ['capture', 'settlement'])) {
            $order->update([
                'status'         => 'paid',
                'payment_method' => $data['payment_type'] ?? null,
                'paid_at'        => now(),
            ]);

            // Masukkan semua buku ke library user
            foreach ($order->items as $item) {
                \DB::table('user_library')->insertOrIgnore([
                    'user_id'      => $order->user_id,
                    'ebook_id'     => $item->ebook_id,
                    'order_id'     => $order->id,
                    'license_type' => 'individual',
                    'created_at'   => now(),
                    'updated_at'   => now(),
                ]);
            }
        } elseif (in_array($data['transaction_status'], ['cancel', 'deny', 'expire'])) {
            $order->update(['status' => 'failed']);
        }

        return response()->json(['message' => 'OK']);
    }
}