// lib/core/services/api_service.dart

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

  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await _dio.get(endpoint);
      if (response.data is Map<String, dynamic>) return response.data;
      return {'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? e.message,
      };
    }
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // PERBAIKAN: tambahkan Future<void> sebagai return type dan
    // gunakan "return handler.next()" agar Dio benar-benar menunggu
    // token terbaca dari secure storage sebelum request diteruskan.
    // Tanpa ini, header Authorization tidak terpasang → server 401.
    final token = await TokenStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      TokenStorage.deleteToken();
    }
    handler.next(err);
  }
}