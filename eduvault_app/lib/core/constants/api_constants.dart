class ApiConstants {
  // Ganti dengan IP komputer kamu saat testing di device fisik
  // Pakai localhost jika pakai emulator Android/iOS simulator
  static const String baseUrl = 'https://suk-unenlarging-overtediously.ngrok-free.dev/api/v1';

  // Auth
  static const String register    = '/auth/register';
  static const String login       = '/auth/login';
  static const String logout      = '/auth/logout';
  static const String me          = '/auth/me';
  static const String googleAuth  = '/auth/google';

  // Katalog
  static const String ebooks      = '/ebooks';
  static const String categories  = '/categories';

  // Order
  static const String orders      = '/orders';

  // Library
  static const String library     = '/library';
}