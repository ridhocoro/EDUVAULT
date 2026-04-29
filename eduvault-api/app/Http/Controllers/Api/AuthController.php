<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use Laravel\Socialite\Facades\Socialite;

class AuthController extends Controller
{
    /**
     * Register dengan email & password
     */
    public function register(Request $request)
    {
        $data = $request->validate([
            'name'     => 'required|string|max:255',
            'email'    => 'required|email|unique:users',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $user = User::create([
            'name'     => $data['name'],
            'email'    => $data['email'],
            'password' => Hash::make($data['password']),
        ]);

        $token = $user->createToken('eduvault-app')->plainTextToken;

        return response()->json([
            'user'  => $user,
            'token' => $token,
        ], 201);
    }

    /**
     * Login dengan email & password
     */
    public function login(Request $request)
    {
        $data = $request->validate([
            'email'    => 'required|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Email atau password salah.'],
            ]);
        }

        // Hapus token lama, buat yang baru
        $user->tokens()->delete();
        $token = $user->createToken('eduvault-app')->plainTextToken;

        return response()->json([
            'user'  => $user,
            'token' => $token,
        ]);
    }

    /**
     * Google OAuth redirect
     * Arahkan user ke Google login page
     */
    public function googleRedirect()
    {
        try {
            return Socialite::driver('google')->stateless()->redirect();
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Google OAuth not configured properly',
                'error'   => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Google OAuth callback
     * Dipanggil Google setelah user login
     */
    public function googleCallback()
    {
        try {
            // Ambil data user dari Google
            $googleUser = Socialite::driver('google')->stateless()->user();

            // Cari atau buat user di database
            $user = User::updateOrCreate(
                ['email' => $googleUser->getEmail()],
                [
                    'name'      => $googleUser->getName(),
                    'google_id' => $googleUser->getId(),
                    'avatar'    => $googleUser->getAvatar(),
                    'password'  => null,  // Google OAuth user tidak punya password
                ]
            );

            // Hapus token lama, buat yang baru
            $user->tokens()->delete();
            $token = $user->createToken('eduvault-app')->plainTextToken;

            // **OPSI 1: Redirect ke deeplink Flutter (recommended)**
            // Ini akan buka app Flutter dengan token sudah terisi
            return redirect("eduvault://auth?token={$token}");

            // **OPSI 2: Return JSON (jika pakai webview di app)**
            // return response()->json([
            //     'user'  => $user,
            //     'token' => $token,
            // ]);

        } catch (\Exception $e) {
            // Jika ada error, redirect ke app dengan error message
            return redirect("eduvault://auth?error=" . urlencode($e->getMessage()));
        }
    }

    /**
     * Ambil data user yang sedang login
     */
    public function me(Request $request)
    {
        return response()->json($request->user());
    }

    /**
     * Logout
     */
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();
        
        return response()->json([
            'message' => 'Logged out successfully.',
        ]);
    }

    /**
     * Verify token dari deeplink
     * Dipanggil dari Flutter setelah OAuth redirect
     */
    public function verifyToken(Request $request)
    {
        $request->validate([
            'token' => 'required|string',
        ]);

        try {
            // Coba autentikasi dengan token
            $user = $request->user();
            
            return response()->json([
                'user'  => $user,
                'token' => $request->bearerToken(),
                'message' => 'Token valid',
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Invalid token',
            ], 401);
        }
    }
}