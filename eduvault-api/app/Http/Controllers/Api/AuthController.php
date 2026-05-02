<?php
// app/Http/Controllers/Api/AuthController.php
// REPLACE file lama dengan file ini

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

        return response()->json(['user' => $user, 'token' => $token], 201);
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

        $user->tokens()->delete();
        $token = $user->createToken('eduvault-app')->plainTextToken;

        return response()->json(['user' => $user, 'token' => $token]);
    }

    /**
     * Google OAuth — redirect ke halaman login Google
     */
    public function googleRedirect()
    {
        try {
            return Socialite::driver('google')->stateless()->redirect();
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Google OAuth belum dikonfigurasi.',
                'error'   => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Google OAuth callback — dipanggil Google setelah user login
     * Lalu redirect ke deeplink Flutter: eduvault://auth?token=xxx
     */
    public function googleCallback()
    {
        try {
            $googleUser = Socialite::driver('google')->stateless()->user();

            $user = User::updateOrCreate(
                ['email' => $googleUser->getEmail()],
                [
                    'name'      => $googleUser->getName(),
                    'google_id' => $googleUser->getId(),
                    'avatar'    => $googleUser->getAvatar(),
                    // Google user tidak punya password lokal
                    'password'  => null,
                ]
            );

            // Buat token Sanctum baru
            $user->tokens()->delete();
            $token = $user->createToken('eduvault-app')->plainTextToken;

            // Redirect ke deeplink Flutter — app_links akan menangkap ini
            return redirect("eduvault://auth?token={$token}");

        } catch (\Exception $e) {
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
        return response()->json(['message' => 'Logged out successfully.']);
    }
}
