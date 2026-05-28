// lib/core/constants/api_constants.dart

class ApiConstants {
  static const String baseUrl =
      'https://suk-unenlarging-overtediously.ngrok-free.dev/api/v1';

  // Auth
  static const String register   = '/auth/register';
  static const String login      = '/auth/login';
  static const String logout     = '/auth/logout';
  static const String me         = '/auth/me';
  static const String googleAuth = '/auth/google';

  // Katalog
  static const String ebooks     = '/ebooks';
  static const String categories = '/categories';

  // Order
  static const String orders = '/orders';
  static String orderDetail(String code) => '/orders/$code';

  // Library
  static const String library = '/library';
  static String libraryFinish(int id) => '/library/$id/finish';

  // Reviews
  static String ebookReviews(int ebookId) => '/ebooks/$ebookId/reviews';

  // Wishlist
  static const String wishlist = '/wishlist';
  static String wishlistItem(int ebookId)  => '/wishlist/$ebookId';
  static String wishlistCheck(int ebookId) => '/wishlist/$ebookId/check';

  // Admin
  static const String adminDashboard  = '/admin/dashboard';
  static const String adminEbooks     = '/admin/ebooks';
  static const String adminCategories = '/admin/categories';
  static const String adminUsers      = '/admin/users';
  static String adminEbookUpload(int id)      => '/admin/ebooks/$id/upload-file';
  static String adminEbookUploadCover(int id) => '/admin/ebooks/$id/upload-cover';
  static String adminEbookDetail(int id)      => '/admin/ebooks/$id';

  // AI Chat
  static String chat(int bookId)       => '/books/$bookId/chat';
  static String chatStream(int bookId) => '/books/$bookId/chat/stream';
  static String chatHistory(int bookId)=> '/books/$bookId/chat/history';

  // Trial Chat
  static String trialChat(int ebookId)        => '/ebooks/$ebookId/trial-chat';
  static String trialChatStatus(int ebookId)  => '/ebooks/$ebookId/trial-chat/status';
  static String trialChatHistory(int ebookId) => '/ebooks/$ebookId/trial-chat/history';

  // ── QUIZ (user-generated, via library) ──────────────────────────
  // Semua endpoint quiz di bawah /library/{ebookId}/
  static String quizList(int ebookId)                 => '/library/$ebookId/quiz';
  static String quizGenerate(int ebookId)             => '/library/$ebookId/quiz/generate';
  static String quizSubmit(int ebookId)               => '/library/$ebookId/quiz/submit';
  static String quizDelete(int ebookId, int quizId)   => '/library/$ebookId/quiz/$quizId';

  // Legacy alias (agar tidak ada error jika masih ada yang pakai quiz())
  static String quiz(int ebookId) => quizList(ebookId);
}
