// lib/features/admin/providers/admin_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/admin_models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../catalog/models/ebook_model.dart';

// ──────────────────────────────────────────────────────────────────
// State
// ──────────────────────────────────────────────────────────────────
class AdminState {
  final AdminStats? stats;
  final List<EbookModel> ebooks;
  final int ebookCurrentPage;
  final int ebookLastPage;
  final int ebookTotal;
  final List<CategoryModel> categories;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final String statusFilter; // '' | 'draft' | 'published' | 'archived'
  final String searchQuery;

  const AdminState({
    this.stats,
    this.ebooks = const [],
    this.ebookCurrentPage = 1,
    this.ebookLastPage = 1,
    this.ebookTotal = 0,
    this.categories = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.statusFilter = '',
    this.searchQuery = '',
  });

  AdminState copyWith({
    AdminStats? stats,
    List<EbookModel>? ebooks,
    int? ebookCurrentPage,
    int? ebookLastPage,
    int? ebookTotal,
    List<CategoryModel>? categories,
    bool? isLoading,
    bool? isSaving,
    String? error,
    String? statusFilter,
    String? searchQuery,
    bool clearError = false,
  }) {
    return AdminState(
      stats: stats ?? this.stats,
      ebooks: ebooks ?? this.ebooks,
      ebookCurrentPage: ebookCurrentPage ?? this.ebookCurrentPage,
      ebookLastPage: ebookLastPage ?? this.ebookLastPage,
      ebookTotal: ebookTotal ?? this.ebookTotal,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Notifier
// ──────────────────────────────────────────────────────────────────
class AdminNotifier extends StateNotifier<AdminState> {
  AdminNotifier() : super(const AdminState());

  // ── Dashboard ──────────────────────────────────────────────────
  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await ApiService.dio.get(ApiConstants.adminDashboard);
      state = state.copyWith(
        isLoading: false,
        stats: AdminStats.fromJson(res.data),
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Gagal memuat dashboard',
      );
    }
  }

  // ── Ebooks ─────────────────────────────────────────────────────
  Future<void> loadEbooks({
    int page = 1,
    String? status,
    String? search,
  }) async {
    final st = status ?? state.statusFilter;
    final sq = search ?? state.searchQuery;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      statusFilter: st,
      searchQuery: sq,
      ebookCurrentPage: page,
    );

    try {
      final res = await ApiService.dio.get(
        ApiConstants.adminEbooks,
        queryParameters: {
          'page': page,
          'per_page': 15,
          if (st.isNotEmpty) 'status': st,
          if (sq.isNotEmpty) 'search': sq,
        },
      );
      final data = res.data;
      state = state.copyWith(
        isLoading: false,
        ebooks: (data['data'] as List)
            .map((e) => EbookModel.fromJson(e))
            .toList(),
        ebookCurrentPage: data['current_page'],
        ebookLastPage: data['last_page'],
        ebookTotal: data['total'],
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Gagal memuat buku',
      );
    }
  }

  Future<String?> createEbook(Map<String, dynamic> data) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ApiService.dio.post(ApiConstants.adminEbooks, data: data);
      state = state.copyWith(isSaving: false);
      await loadEbooks(page: 1);
      return null; // null = sukses
    } on DioException catch (e) {
      final msg = _parseError(e);
      state = state.copyWith(isSaving: false, error: msg);
      return msg;
    }
  }

  Future<String?> updateEbook(int id, Map<String, dynamic> data) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ApiService.dio.put('${ApiConstants.adminEbooks}/$id', data: data);
      state = state.copyWith(isSaving: false);
      await loadEbooks(page: state.ebookCurrentPage);
      return null;
    } on DioException catch (e) {
      final msg = _parseError(e);
      state = state.copyWith(isSaving: false, error: msg);
      return msg;
    }
  }

  Future<String?> deactivateEbook(int id) async {
    try {
      await ApiService.dio.patch('${ApiConstants.adminEbooks}/$id/deactivate');
      await loadEbooks(page: state.ebookCurrentPage);
      return null;
    } on DioException catch (e) {
      return _parseError(e);
    }
  }

  Future<String?> activateEbook(int id) async {
    try {
      await ApiService.dio.patch('${ApiConstants.adminEbooks}/$id/activate');
      await loadEbooks(page: state.ebookCurrentPage);
      return null;
    } on DioException catch (e) {
      return _parseError(e);
    }
  }

  Future<EbookModel?> getEbookDetail(int id) async {
    try {
      final res =
          await ApiService.dio.get('${ApiConstants.adminEbooks}/$id');
      return EbookModel.fromJsonAdmin(res.data);
    } catch (_) {
      return null;
    }
  }

  // ── Categories ─────────────────────────────────────────────────
  Future<void> loadCategories() async {
    try {
      final res =
          await ApiService.dio.get(ApiConstants.adminCategories);
      state = state.copyWith(
        categories: (res.data as List)
            .map((e) => CategoryModel.fromJson(e))
            .toList(),
      );
    } catch (_) {}
  }

  Future<String?> createCategory(String name, String? icon) async {
    state = state.copyWith(isSaving: true);
    try {
      await ApiService.dio.post(ApiConstants.adminCategories,
          data: {'name': name, 'icon': icon});
      state = state.copyWith(isSaving: false);
      await loadCategories();
      return null;
    } on DioException catch (e) {
      final msg = _parseError(e);
      state = state.copyWith(isSaving: false);
      return msg;
    }
  }

  Future<String?> updateCategory(int id, String name, String? icon) async {
    state = state.copyWith(isSaving: true);
    try {
      await ApiService.dio.put('${ApiConstants.adminCategories}/$id',
          data: {'name': name, 'icon': icon});
      state = state.copyWith(isSaving: false);
      await loadCategories();
      return null;
    } on DioException catch (e) {
      final msg = _parseError(e);
      state = state.copyWith(isSaving: false);
      return msg;
    }
  }

  Future<String?> deleteCategory(int id) async {
    try {
      await ApiService.dio.delete('${ApiConstants.adminCategories}/$id');
      await loadCategories();
      return null;
    } on DioException catch (e) {
      return _parseError(e);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────
  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return data['message']?.toString() ?? 'Terjadi kesalahan';
    }
    return 'Terjadi kesalahan';
  }
}

final adminProvider =
    StateNotifierProvider<AdminNotifier, AdminState>((ref) => AdminNotifier());
