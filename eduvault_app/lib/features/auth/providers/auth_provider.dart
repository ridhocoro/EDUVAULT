// lib/features/auth/providers/auth_provider.dart
// REPLACE file lama dengan file ini

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/token_storage.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;

  AuthState({this.user, this.isLoading = false, this.errorMessage});

  bool get isLoggedIn => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final hasToken = await TokenStorage.hasToken();
    if (!hasToken) return;

    try {
      final res = await ApiService.dio.get(ApiConstants.me);
      state = state.copyWith(user: UserModel.fromJson(res.data));
    } catch (_) {
      await TokenStorage.deleteToken();
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await ApiService.dio.post(ApiConstants.login, data: {
        'email': email,
        'password': password,
      });
      await TokenStorage.saveToken(res.data['token']);
      state = state.copyWith(
        isLoading: false,
        user: UserModel.fromJson(res.data['user']),
      );
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Login gagal. Coba lagi.';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  /// Dipanggil setelah deeplink OAuth berhasil membawa token
  Future<bool> loginWithGoogleToken(String token) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await TokenStorage.saveToken(token);
      // Ambil data user dari API pakai token ini
      final res = await ApiService.dio.get(ApiConstants.me);
      state = state.copyWith(
        isLoading: false,
        user: UserModel.fromJson(res.data),
      );
      return true;
    } on DioException catch (e) {
      await TokenStorage.deleteToken();
      final msg = e.response?.data?['message'] ?? 'Login Google gagal.';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await ApiService.dio.post(ApiConstants.logout);
    } catch (_) {}
    await TokenStorage.deleteToken();
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
