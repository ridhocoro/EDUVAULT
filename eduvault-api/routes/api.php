<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\EbookController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\LibraryController;
use App\Http\Controllers\Api\ReviewController;
use App\Http\Controllers\Api\WishlistController;
use App\Http\Controllers\Api\Admin\DashboardController;
use App\Http\Controllers\Api\Admin\EbookController as AdminEbookController;
use App\Http\Controllers\Api\Admin\CategoryController as AdminCategoryController;
use App\Http\Controllers\Api\Admin\UserController as AdminUserController;

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
    // auth.optional: $request->user() terisi jika ada token valid, null jika guest
    Route::middleware('auth.optional')->get('/ebooks/{slug}', [EbookController::class, 'show']);
    Route::get('/categories',            [EbookController::class, 'categories']);

    // Reviews (publik - siapa pun bisa baca)
    Route::get('/ebooks/{ebookId}/reviews', [ReviewController::class, 'index']);

    // ─── Protected routes (perlu login) ──────────────────────────
    Route::middleware('auth:sanctum')->group(function () {

        // Auth
        Route::post('/auth/logout',      [AuthController::class, 'logout']);
        Route::get('/auth/me',           [AuthController::class, 'me']);

        // Order & checkout
        Route::post('/orders',           [OrderController::class, 'store']);
        Route::get('/orders',            [OrderController::class, 'index']);
        Route::get('/orders/{code}',     [OrderController::class, 'show']);

        // Library user
        Route::get('/library',           [LibraryController::class, 'index']);
        Route::get('/library/{id}/read', [LibraryController::class, 'getReadUrl']);

        // Reviews (write - hanya pemilik buku)
        Route::post('/ebooks/{ebookId}/reviews',   [ReviewController::class, 'store']);
        Route::delete('/ebooks/{ebookId}/reviews', [ReviewController::class, 'destroy']);

        // Wishlist
        Route::get('/wishlist',                    [WishlistController::class, 'index']);
        Route::post('/wishlist/{ebookId}',         [WishlistController::class, 'store']);
        Route::delete('/wishlist/{ebookId}',       [WishlistController::class, 'destroy']);
        Route::get('/wishlist/{ebookId}/check',    [WishlistController::class, 'check']);

        // ─── Admin routes (perlu login + role admin) ──────────────
        Route::middleware('admin')->prefix('admin')->group(function () {

            // Dashboard stats
            Route::get('/dashboard',                     [DashboardController::class, 'stats']);

            // Ebook CRUD
            Route::get('/ebooks',                        [AdminEbookController::class, 'index']);
            Route::post('/ebooks',                       [AdminEbookController::class, 'store']);
            Route::get('/ebooks/{id}',                   [AdminEbookController::class, 'show']);
            Route::put('/ebooks/{id}',                   [AdminEbookController::class, 'update']);
            Route::patch('/ebooks/{id}',                 [AdminEbookController::class, 'update']);
            Route::delete('/ebooks/{id}',                [AdminEbookController::class, 'destroy']);
            Route::patch('/ebooks/{id}/deactivate',      [AdminEbookController::class, 'deactivate']);
            Route::patch('/ebooks/{id}/activate',        [AdminEbookController::class, 'activate']);

            // Category CRUD
            Route::get('/categories',                    [AdminCategoryController::class, 'index']);
            Route::post('/categories',                   [AdminCategoryController::class, 'store']);
            Route::put('/categories/{id}',               [AdminCategoryController::class, 'update']);
            Route::patch('/categories/{id}',             [AdminCategoryController::class, 'update']);
            Route::delete('/categories/{id}',            [AdminCategoryController::class, 'destroy']);

            // User management
            Route::get('/users',                         [AdminUserController::class, 'index']);
            Route::patch('/users/{id}/promote',          [AdminUserController::class, 'promoteToAdmin']);
            Route::patch('/users/{id}/demote',           [AdminUserController::class, 'demoteToUser']);
        });
    });
});

// Midtrans payment notification (webhook publik, tanpa auth)
// URL: POST /api/v1/payment/notification
Route::prefix('v1')->group(function () {
    Route::post('/payment/notification', [OrderController::class, 'paymentNotification']);
});
