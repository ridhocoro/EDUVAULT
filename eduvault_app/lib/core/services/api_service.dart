import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../utils/token_storage.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    ),
  )..interceptors.add(_AuthInterceptor());

  static Dio get dio => _dio;

  // Method get agar OrderProvider bisa memanggil ApiService.get('/orders')
  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await _dio.get(endpoint);
      
      // Dio otomatis mengubah JSON menjadi Map<String, dynamic>
      // Jika response.data sudah berupa Map, kita langsung kembalikan
      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
      
      // Jika karena suatu hal data bukan Map, kita bungkus agar tidak error di provider
      return {'data': response.data};
    } on DioException catch (e) {
      // Menangkap error dari server atau koneksi
      return {
        'success': false,
        'message': e.response?.data['message'] ?? e.message,
      };
    }
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await TokenStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      TokenStorage.deleteToken();
    }
    handler.next(err);
  }
}