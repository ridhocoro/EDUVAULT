<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\EbookController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\LibraryController;

// ─── Public routes (guest bisa akses) ─────────────────────────────
Route::prefix('v1')->group(function () {

    // Auth
    Route::post('/auth/register',        [AuthController::class, 'register']);
    Route::post('/auth/login',           [AuthController::class, 'login']);
    Route::get('/auth/google',           [AuthController::class, 'googleRedirect']);
    Route::get('/auth/google/callback',  [AuthController::class, 'googleCallback']);
    Route::post('/auth/verify-token',    [AuthController::class, 'verifyToken']);

    // Katalog buku (publik)
    Route::get('/ebooks',                [EbookController::class, 'index']);
    Route::get('/ebooks/{slug}',         [EbookController::class, 'show']);
    Route::get('/categories',            [EbookController::class, 'categories']);

    // ─── Protected routes (perlu login) ──────────────────────────
    Route::middleware('auth:sanctum')->group(function () {

        // Auth
        Route::post('/auth/logout',      [AuthController::class, 'logout']);
        Route::get('/auth/me',           [AuthController::class, 'me']);

        // Order & checkout
        Route::post('/orders',           [OrderController::class, 'store']);
        Route::get('/orders',            [OrderController::class, 'index']);
        Route::get('/orders/{code}',     [OrderController::class, 'show']);

        // Midtrans webhook (tidak butuh auth tapi butuh signature check)
        // Library user
        Route::get('/library',           [LibraryController::class, 'index']);
        Route::get('/library/{id}/read', [LibraryController::class, 'getReadUrl']);
    });
});

// Midtrans payment notification (webhook publik, verifikasi via signature)
Route::post('/v1/payment/notification', [OrderController::class, 'paymentNotification']);