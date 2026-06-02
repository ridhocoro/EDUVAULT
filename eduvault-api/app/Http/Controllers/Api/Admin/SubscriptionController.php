<?php
// app/Http/Controllers/Api/Admin/SubscriptionController.php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\SubscriptionPlan;
use Illuminate\Http\Request;

class SubscriptionController extends Controller
{
    /** Daftar semua paket */
    public function index(Request $request)
    {
        $plans = SubscriptionPlan::with('ebooks:id,title,cover_url,price')
            ->withCount('userSubscriptions')
            ->latest()
            ->get();

        return response()->json(['success' => true, 'data' => $plans]);
    }

    /** Buat paket baru */
    public function store(Request $request)
    {
        $data = $request->validate([
            'name'          => 'required|string|max:255',
            'description'   => 'nullable|string',
            'price'         => 'required|numeric|min:0',
            'duration_days' => 'integer|min:1',
            'status'        => 'in:active,inactive',
            'ebook_ids'     => 'required|array|min:1',
            'ebook_ids.*'   => 'integer|exists:ebooks,id',
        ]);

        $plan = SubscriptionPlan::create([
            'name'          => $data['name'],
            'description'   => $data['description'] ?? null,
            'price'         => $data['price'],
            'duration_days' => $data['duration_days'] ?? 30,
            'status'        => $data['status'] ?? 'active',
        ]);

        $plan->ebooks()->sync($data['ebook_ids']);

        return response()->json([
            'success' => true,
            'message' => 'Paket subscription berhasil dibuat.',
            'data'    => $plan->load('ebooks:id,title,cover_url'),
        ], 201);
    }

    /** Detail paket */
    public function show(int $id)
    {
        $plan = SubscriptionPlan::with('ebooks:id,title,cover_url,price')
            ->withCount('userSubscriptions')
            ->findOrFail($id);

        return response()->json(['success' => true, 'data' => $plan]);
    }

    /** Update paket */
    public function update(Request $request, int $id)
    {
        $plan = SubscriptionPlan::findOrFail($id);

        $data = $request->validate([
            'name'          => 'sometimes|string|max:255',
            'description'   => 'nullable|string',
            'price'         => 'sometimes|numeric|min:0',
            'duration_days' => 'sometimes|integer|min:1',
            'status'        => 'sometimes|in:active,inactive',
            'ebook_ids'     => 'sometimes|array|min:1',
            'ebook_ids.*'   => 'integer|exists:ebooks,id',
        ]);

        $plan->update(array_filter($data, fn ($v, $k) => $k !== 'ebook_ids', ARRAY_FILTER_USE_BOTH));

        if (isset($data['ebook_ids'])) {
            $plan->ebooks()->sync($data['ebook_ids']);
        }

        return response()->json([
            'success' => true,
            'message' => 'Paket subscription berhasil diperbarui.',
            'data'    => $plan->load('ebooks:id,title,cover_url'),
        ]);
    }

    /** Hapus paket */
    public function destroy(int $id)
    {
        $plan = SubscriptionPlan::findOrFail($id);
        $plan->delete();

        return response()->json([
            'success' => true,
            'message' => 'Paket subscription berhasil dihapus.',
        ]);
    }

    /** Daftar subscriber aktif dari sebuah paket */
    public function subscribers(int $id)
    {
        $plan = SubscriptionPlan::findOrFail($id);

        $subs = $plan->userSubscriptions()
            ->with('user:id,name,email,avatar')
            ->latest()
            ->paginate(20);

        return response()->json(['success' => true, 'data' => $subs]);
    }
}
