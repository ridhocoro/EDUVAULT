import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ebook_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';

class CatalogState {
  final List<EbookModel> ebooks;
  final List<CategoryModel> categories;
  final bool isLoading;
  final String? errorMessage;
  final String? selectedCategory;
  final String? searchQuery;

  CatalogState({
    this.ebooks = const [],
    this.categories = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedCategory,
    this.searchQuery,
  });

  CatalogState copyWith({
    List<EbookModel>? ebooks,
    List<CategoryModel>? categories,
    bool? isLoading,
    String? errorMessage,
    String? selectedCategory,
    String? searchQuery,
  }) {
    return CatalogState(
      ebooks:           ebooks           ?? this.ebooks,
      categories:       categories       ?? this.categories,
      isLoading:        isLoading        ?? this.isLoading,
      errorMessage:     errorMessage,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery:      searchQuery      ?? this.searchQuery,
    );
  }
}

class CatalogNotifier extends StateNotifier<CatalogState> {
  CatalogNotifier() : super(CatalogState()) {
    fetchCategories();
    fetchEbooks();
  }

  Future<void> fetchCategories() async {
    try {
      final res = await ApiService.dio.get(ApiConstants.categories);
      final list = (res.data as List)
          .map((e) => CategoryModel.fromJson(e))
          .toList();
      state = state.copyWith(categories: list);
    } catch (_) {}
  }

  Future<void> fetchEbooks({String? category, String? search}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await ApiService.dio.get(
        ApiConstants.ebooks,
        queryParameters: {
          if (category != null) 'category': category,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      final list = (res.data['data'] as List)
          .map((e) => EbookModel.fromJson(e))
          .toList();
      state = state.copyWith(
        ebooks: list,
        isLoading: false,
        selectedCategory: category,
        searchQuery: search,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat katalog.',
      );
    }
  }
}

final catalogProvider = StateNotifierProvider<CatalogNotifier, CatalogState>(
  (ref) => CatalogNotifier(),
);