<?php
// app/Http/Controllers/Api/SubscriptionController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\SubscriptionPlan;
use App\Models\UserSubscription;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Midtrans\Config as MidtransConfig;
use Midtrans\Snap;

class SubscriptionController extends Controller
{
    public function __construct()
    {
        MidtransConfig::$serverKey    = config('services.midtrans.server_key');
        MidtransConfig::$isProduction = config('services.midtrans.is_production');
        MidtransConfig::$isSanitized  = config('services.midtrans.is_sanitized', true);
        MidtransConfig::$is3ds        = config('services.midtrans.is_3ds', true);
    }

    /** Daftar paket subscription aktif (untuk halaman publik) */
    public function index()
    {
        $plans = SubscriptionPlan::active()
            ->with('ebooks:id,title,cover_url,author,price')
            ->withCount('ebooks')
            ->get();

        return response()->json(['success' => true, 'data' => $plans]);
    }

    /** Detail satu paket */
    public function show(int $id)
    {
        $plan = SubscriptionPlan::active()
            ->with('ebooks:id,title,cover_url,author,price,category_id', 'ebooks.category:id,name')
            ->findOrFail($id);

        return response()->json(['success' => true, 'data' => $plan]);
    }

    /** Beli subscription — buat order + Midtrans snap token */
    public function subscribe(Request $request, int $planId)
    {
        $plan = SubscriptionPlan::active()->findOrFail($planId);
        $user = $request->user();

        // Cek jika user sudah punya subscription aktif dari paket yang sama
        $existing = UserSubscription::where('user_id', $user->id)
            ->where('subscription_plan_id', $planId)
            ->where('status', 'active')
            ->where('expires_at', '>', now())
            ->first();

        if ($existing) {
            return response()->json([
                'message' => 'Kamu sudah memiliki langganan aktif untuk paket ini.',
                'expires_at' => $existing->expires_at,
            ], 422);
        }

        DB::beginTransaction();
        try {
            $order = Order::create([
                'user_id'              => $user->id,
                'order_code'           => Order::generateCode(),
                'midtrans_order_id'    => 'SUB-' . strtoupper(uniqid()),
                'total_amount'         => $plan->price,
                'status'               => 'pending',
                'order_type'           => 'subscription',
                'subscription_plan_id' => $plan->id,
            ]);

            $params = [
                'transaction_details' => [
                    'order_id'     => $order->midtrans_order_id,
                    'gross_amount' => (int) $plan->price,
                ],
                'item_details' => [[
                    'id'       => 'SUB-' . $plan->id,
                    'price'    => (int) $plan->price,
                    'quantity' => 1,
                    'name'     => mb_substr('Langganan: ' . $plan->name, 0, 50),
                ]],
                'customer_details' => [
                    'first_name' => $user->name,
                    'email'      => $user->email,
                ],
            ];

            $snapToken = Snap::getSnapToken($params);
            $order->update(['midtrans_token' => $snapToken]);

            DB::commit();

            return response()->json([
                'success'    => true,
                'order'      => $order,
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

    /** Status & detail subscription aktif user */
    public function mySubscription(Request $request)
    {
        $sub = $request->user()->activeSubscription();

        if (! $sub) {
            return response()->json([
                'success'      => true,
                'active'       => false,
                'subscription' => null,
            ]);
        }

        return response()->json([
            'success'      => true,
            'active'       => true,
            'subscription' => $sub,
        ]);
    }

    /** Riwayat semua subscription user */
    public function history(Request $request)
    {
        $subs = UserSubscription::where('user_id', $request->user()->id)
            ->with('plan:id,name,price,duration_days')
            ->latest()
            ->get();

        return response()->json(['success' => true, 'data' => $subs]);
    }
}
