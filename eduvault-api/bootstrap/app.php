<?php
// bootstrap/app.php
// REPLACE file lama dengan file ini

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        // Daftarkan alias middleware
        $middleware->alias([
            'admin'         => \App\Http\Middleware\EnsureAdmin::class,
            'auth.optional' => \App\Http\Middleware\OptionalSanctumAuth::class,
            'verify.book.ownership' => \App\Http\Middleware\VerifyBookOwnership::class, // ✅ TAMBAHKAN INI
        ]);

        // Izinkan webhook Midtrans melewati CSRF (API routes sudah stateless,
        // tapi eksplisit lebih aman)
        $middleware->validateCsrfTokens(except: [
            'api/v1/payment/notification',
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        //
    })->create();