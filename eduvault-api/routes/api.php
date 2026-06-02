<?php
// routes/api.php — REPLACE file lama
// Perubahan: tambah route subscription (user & admin)

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\EbookController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\LibraryController;
use App\Http\Controllers\Api\ReviewController;
use App\Http\Controllers\Api\WishlistController;
use App\Http\Controllers\Api\ChatController;
use App\Http\Controllers\Api\TrialChatController;
use App\Http\Controllers\Api\QuizController;
use App\Http\Controllers\Api\SubscriptionController;
use App\Http\Controllers\Api\Admin\DashboardController;
use App\Http\Controllers\Api\Admin\EbookController as AdminEbookController;
use App\Http\Controllers\Api\Admin\CategoryController as AdminCategoryController;
use App\Http\Controllers\Api\Admin\UserController as AdminUserController;
use App\Http\Controllers\Api\Admin\SubscriptionController as AdminSubscriptionController;

Route::prefix('v1')->group(function () {

    // ── Public routes ─────────────────────────────────────────────
    Route::post('/auth/register',       [AuthController::class, 'register']);
    Route::post('/auth/login',          [AuthController::class, 'login']);
    Route::get('/auth/google',          [AuthController::class, 'googleRedirect']);
    Route::get('/auth/google/callback', [AuthController::class, 'googleCallback']);
    Route::post('/auth/verify-token',   [AuthController::class, 'verifyToken']);

    Route::get('/ebooks',               [EbookController::class, 'index']);
    Route::middleware('auth.optional')->get('/ebooks/{slug}', [EbookController::class, 'show']);
    Route::get('/categories',           [EbookController::class, 'categories']);
    Route::get('/ebooks/{ebookId}/reviews', [ReviewController::class, 'index']);

    // Subscription plans — publik (user lihat daftar paket)
    Route::get('/subscriptions',        [SubscriptionController::class, 'index']);
    Route::get('/subscriptions/{id}',   [SubscriptionController::class, 'show']);

    // ── Protected routes (login required) ────────────────────────
    Route::middleware('auth:sanctum')->group(function () {

        // Auth
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/auth/me',      [AuthController::class, 'me']);

        // Orders (beli satuan)
        Route::post('/orders',       [OrderController::class, 'store']);
        Route::get('/orders',        [OrderController::class, 'index']);
        Route::get('/orders/{code}', [OrderController::class, 'show']);

        // Subscription user
        Route::post('/subscriptions/{planId}/subscribe', [SubscriptionController::class, 'subscribe']);
        Route::get('/my-subscription',                   [SubscriptionController::class, 'mySubscription']);
        Route::get('/my-subscription/history',           [SubscriptionController::class, 'history']);

        // Library — support ?source=all|purchase|subscription & ?search=
        Route::get('/library',              [LibraryController::class, 'index']);
        Route::get('/library/{id}/read',    [LibraryController::class, 'getReadUrl']);
        Route::post('/library/{id}/finish', [LibraryController::class, 'finish']);

        // Reviews
        Route::post('/ebooks/{ebookId}/reviews',   [ReviewController::class, 'store']);
        Route::delete('/ebooks/{ebookId}/reviews', [ReviewController::class, 'destroy']);

        // Wishlist
        Route::get('/wishlist',                 [WishlistController::class, 'index']);
        Route::post('/wishlist/{ebookId}',      [WishlistController::class, 'store']);
        Route::delete('/wishlist/{ebookId}',    [WishlistController::class, 'destroy']);
        Route::get('/wishlist/{ebookId}/check', [WishlistController::class, 'check']);

        // Trial AI Chat
        Route::prefix('ebooks/{ebookId}')->group(function () {
            Route::get('/trial-chat/status',  [TrialChatController::class, 'status']);
            Route::post('/trial-chat',        [TrialChatController::class, 'send']);
            Route::get('/trial-chat/history', [TrialChatController::class, 'history']);
        });

        // AI Chat — user yang punya buku (beli satuan ATAU subscription aktif)
        Route::middleware('verify.book.ownership')->prefix('books/{book_id}')->group(function () {
            Route::post('/chat',        [ChatController::class, 'send']);
            Route::post('/chat/stream', [ChatController::class, 'sendStream']);
            Route::get('/chat/history', [ChatController::class, 'history']);
        });

        // Quiz
        Route::middleware('verify.book.ownership')->prefix('library/{book_id}')->group(function () {
            Route::get('/quiz',           [QuizController::class, 'index']);
            Route::post('/quiz/generate', [QuizController::class, 'generate']);
            Route::post('/quiz/submit',   [QuizController::class, 'submit']);
            Route::delete('/quiz/{quizId}', [QuizController::class, 'destroy']);
        });

        // ── Admin routes ─────────────────────────────────────────
        Route::middleware('admin')->prefix('admin')->group(function () {

            Route::get('/dashboard', [DashboardController::class, 'stats']);

            // Ebook CRUD
            Route::get('/ebooks',                     [AdminEbookController::class, 'index']);
            Route::post('/ebooks',                    [AdminEbookController::class, 'store']);
            Route::get('/ebooks/{id}',                [AdminEbookController::class, 'show']);
            Route::put('/ebooks/{id}',                [AdminEbookController::class, 'update']);
            Route::patch('/ebooks/{id}',              [AdminEbookController::class, 'update']);
            Route::delete('/ebooks/{id}',             [AdminEbookController::class, 'destroy']);
            Route::patch('/ebooks/{id}/deactivate',   [AdminEbookController::class, 'deactivate']);
            Route::patch('/ebooks/{id}/activate',     [AdminEbookController::class, 'activate']);
            Route::post('/ebooks/{id}/upload-file',   [AdminEbookController::class, 'uploadFile']);
            Route::delete('/ebooks/{id}/upload-file', [AdminEbookController::class, 'deleteFile']);
            Route::post('/ebooks/{id}/upload-cover',  [AdminEbookController::class, 'uploadCover']);
            Route::delete('/ebooks/{id}/upload-cover',[AdminEbookController::class, 'deleteCover']);

            // Categories
            Route::get('/categories',        [AdminCategoryController::class, 'index']);
            Route::post('/categories',       [AdminCategoryController::class, 'store']);
            Route::put('/categories/{id}',   [AdminCategoryController::class, 'update']);
            Route::patch('/categories/{id}', [AdminCategoryController::class, 'update']);
            Route::delete('/categories/{id}',[AdminCategoryController::class, 'destroy']);

            // Users
            Route::get('/users',                [AdminUserController::class, 'index']);
            Route::patch('/users/{id}/promote', [AdminUserController::class, 'promoteToAdmin']);
            Route::patch('/users/{id}/demote',  [AdminUserController::class, 'demoteToUser']);

            // Subscription Plans (admin CRUD)
            Route::get('/subscriptions',                        [AdminSubscriptionController::class, 'index']);
            Route::post('/subscriptions',                       [AdminSubscriptionController::class, 'store']);
            Route::get('/subscriptions/{id}',                   [AdminSubscriptionController::class, 'show']);
            Route::put('/subscriptions/{id}',                   [AdminSubscriptionController::class, 'update']);
            Route::patch('/subscriptions/{id}',                 [AdminSubscriptionController::class, 'update']);
            Route::delete('/subscriptions/{id}',                [AdminSubscriptionController::class, 'destroy']);
            Route::get('/subscriptions/{id}/subscribers',       [AdminSubscriptionController::class, 'subscribers']);
        });
    });
});

// Midtrans webhook — tanpa auth (dipanggil oleh server Midtrans)
Route::prefix('v1')->group(function () {
    Route::post('/payment/notification', [OrderController::class, 'paymentNotification']);
});
