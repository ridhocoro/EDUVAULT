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

  // Library
  static const String library = '/library';

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
}
