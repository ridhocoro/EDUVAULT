<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpFoundation\Response;

/**
 * Middleware auth opsional:
 * - Jika ada Bearer token yang valid → autentikasi user seperti biasa
 * - Jika tidak ada token / token tidak valid → lanjutkan sebagai guest (tidak error 401)
 */
class OptionalSanctumAuth
{
    public function handle(Request $request, Closure $next): Response
    {
        $bearerToken = $request->bearerToken();

        if ($bearerToken) {
            $token = PersonalAccessToken::findToken($bearerToken);
            if ($token && $token->tokenable) {
                // Autentikasi user secara manual ke dalam request
                $request->setUserResolver(fn () => $token->tokenable);
                auth()->setUser($token->tokenable);
            }
        }

        return $next($request);
    }
}
