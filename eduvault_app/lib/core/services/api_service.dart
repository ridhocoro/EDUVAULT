import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../utils/token_storage.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30), // naik dari 10 → 30 untuk ngrok
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        // Wajib untuk bypass ngrok browser warning page
        // Tanpa ini, ngrok return HTML bukan JSON → parse gagal
        'ngrok-skip-browser-warning': 'true',
      },
    ),
  )..interceptors.add(_AuthInterceptor());

  static Dio get dio => _dio;
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