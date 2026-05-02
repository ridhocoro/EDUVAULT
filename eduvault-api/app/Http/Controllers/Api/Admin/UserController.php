<?php
// app/Http/Controllers/Api/Admin/UserController.php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;

class UserController extends Controller
{
    /**
     * Daftar semua user
     */
    public function index(Request $request)
    {
        $query = User::query()->latest();

        if ($search = $request->query('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%");
            });
        }

        if ($role = $request->query('role')) {
            $query->where('role', $role);
        }

        $perPage = min((int) $request->query('per_page', 20), 100);

        return response()->json($query->paginate($perPage));
    }

    /**
     * Promote user menjadi admin
     */
    public function promoteToAdmin(int $id, Request $request)
    {
        $user = User::findOrFail($id);

        // Cegah admin cabut hak dirinya sendiri
        if ($user->id === $request->user()->id) {
            return response()->json(['message' => 'Tidak bisa mengubah role diri sendiri.'], 422);
        }

        $user->update(['role' => 'admin']);

        return response()->json([
            'message' => "{$user->name} berhasil dijadikan admin.",
            'user'    => $user->fresh(),
        ]);
    }

    /**
     * Demote admin menjadi user biasa
     */
    public function demoteToUser(int $id, Request $request)
    {
        $user = User::findOrFail($id);

        if ($user->id === $request->user()->id) {
            return response()->json(['message' => 'Tidak bisa mengubah role diri sendiri.'], 422);
        }

        $user->update(['role' => 'user']);

        return response()->json([
            'message' => "{$user->name} berhasil diturunkan menjadi user biasa.",
            'user'    => $user->fresh(),
        ]);
    }
}
