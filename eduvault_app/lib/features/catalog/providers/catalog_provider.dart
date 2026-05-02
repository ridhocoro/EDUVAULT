// lib/features/catalog/providers/catalog_provider.dart
// REPLACE file lama dengan file ini

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ebook_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';

enum PriceSort { none, asc, desc, free }

class CatalogState {
  final List<EbookModel> ebooks;
  final List<CategoryModel> categories;
  final bool isLoading;
  final String? errorMessage;
  final String? selectedCategory;
  final String? searchQuery;
  final PriceSort priceSort;
  final double? minPrice;
  final double? maxPrice;

  CatalogState({
    this.ebooks = const [],
    this.categories = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedCategory,
    this.searchQuery,
    this.priceSort = PriceSort.none,
    this.minPrice,
    this.maxPrice,
  });

  CatalogState copyWith({
    List<EbookModel>? ebooks,
    List<CategoryModel>? categories,
    bool? isLoading,
    String? errorMessage,
    String? selectedCategory,
    String? searchQuery,
    PriceSort? priceSort,
    double? minPrice,
    double? maxPrice,
    bool clearCategory = false,
    bool clearSearch = false,
    bool clearMinMax = false,
  }) {
    return CatalogState(
      ebooks: ebooks ?? this.ebooks,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      priceSort: priceSort ?? this.priceSort,
      minPrice: clearMinMax ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMinMax ? null : (maxPrice ?? this.maxPrice),
    );
  }

  /// Filter & sort dilakukan client-side
  List<EbookModel> get filteredEbooks {
    List<EbookModel> result = List.from(ebooks);

    if (priceSort == PriceSort.free) {
      result = result.where((e) => e.price == 0).toList();
    }
    if (minPrice != null) {
      result = result.where((e) => e.price >= minPrice!).toList();
    }
    if (maxPrice != null) {
      result = result.where((e) => e.price <= maxPrice!).toList();
    }
    if (priceSort == PriceSort.asc) {
      result.sort((a, b) => a.price.compareTo(b.price));
    } else if (priceSort == PriceSort.desc) {
      result.sort((a, b) => b.price.compareTo(a.price));
    }

    return result;
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
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearCategory: category == null,
      clearSearch: search == null,
    );
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

  void setPriceSort(PriceSort sort) {
    state = state.copyWith(priceSort: sort);
  }

  void setPriceRange({double? min, double? max}) {
    state = state.copyWith(minPrice: min, maxPrice: max);
  }

  void resetFilters() {
    state = state.copyWith(
      priceSort: PriceSort.none,
      clearMinMax: true,
    );
  }
}

final catalogProvider = StateNotifierProvider<CatalogNotifier, CatalogState>(
  (ref) => CatalogNotifier(),
);