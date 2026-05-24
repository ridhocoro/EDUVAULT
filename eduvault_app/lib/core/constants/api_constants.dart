class ApiConstants {
  static const String baseUrl =
      'https://suk-unenlarging-overtediously.ngrok-free.dev/api/v1';

  // Auth
  static const String register   = '/auth/register';
  static const String login      = '/auth/login';
  static const String logout     = '/auth/logout';
  static const String me         = '/auth/me';
  static const String googleAuth = '/auth/google';

  // Katalog (publik)
  static const String ebooks     = '/ebooks';
  static const String categories = '/categories';

  // Order
  static const String orders = '/orders';
  static String orderDetail(String code) => '/orders/$code';

  // Library
  static const String library = '/library';
  static String libraryFinish(int id) => '/library/$id/finish';

  // Reviews — gunakan ebookReviews(id) untuk dapat URL dinamis
  static String ebookReviews(int ebookId) => '/ebooks/$ebookId/reviews';

  // Wishlist
  static const String wishlist = '/wishlist';
  static String wishlistItem(int ebookId) => '/wishlist/$ebookId';
  static String wishlistCheck(int ebookId) => '/wishlist/$ebookId/check';

  // ─── Admin ────────────────────────────────────────────────────
  static const String adminDashboard  = '/admin/dashboard';
  static const String adminEbooks     = '/admin/ebooks';
  static const String adminCategories = '/admin/categories';
  static const String adminUsers      = '/admin/users';
  static String adminEbookUpload(int id) => '/admin/ebooks/$id/upload-file';
  static String adminEbookDetail(int id) => '/admin/ebooks/$id';

  static String chat(int bookId) => '/books/$bookId/chat';
  static String chatStream(int bookId) => '/books/$bookId/chat/stream';
  static String chatHistory(int bookId) => '/books/$bookId/chat/history';

  static String trialChat(int ebookId)        => '/ebooks/$ebookId/trial-chat';
  static String trialChatStatus(int ebookId)  => '/ebooks/$ebookId/trial-chat/status';
  static String trialChatHistory(int ebookId) => '/ebooks/$ebookId/trial-chat/history';

  // Quiz (untuk buku yang sudah dibeli — via library)
  static String quiz(int ebookId)             => '/library/$ebookId/quiz';
  static String quizSubmit(int ebookId)       => '/library/$ebookId/quiz/submit';

  // Admin Quiz
  static String adminQuiz(int ebookId)        => '/admin/ebooks/$ebookId/quiz';
  static String adminQuizGenerate(int ebookId)=> '/admin/ebooks/$ebookId/quiz/generate';
  static String adminQuizQuestion(int qId)    => '/admin/quiz-questions/$qId';
  static String adminQuizPublish(int quizId)  => '/admin/quizzes/$quizId/publish';
  static String adminQuizDelete(int quizId)   => '/admin/quizzes/$quizId';
}
