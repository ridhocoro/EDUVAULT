import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../catalog/models/wishlist_model.dart';

class WishlistState {
  final List<WishlistModel> items;
  final bool loading;
  final String? error;

  const WishlistState({
    this.items = const [],
    this.loading = false,
    this.error,
  });

  WishlistState copyWith({
    List<WishlistModel>? items,
    bool? loading,
    String? error,
  }) {
    return WishlistState(
      items:   items ?? this.items,
      loading: loading ?? this.loading,
      error:   error,
    );
  }

  bool isInWishlist(int ebookId) => items.any((w) => w.ebookId == ebookId);
}

class WishlistNotifier extends StateNotifier<WishlistState> {
  WishlistNotifier() : super(const WishlistState());

  Future<void> loadWishlist() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await ApiService.dio.get(ApiConstants.wishlist);
      final list = res.data as List;
      state = state.copyWith(
        items: list
            .map((e) => WishlistModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<bool> toggleWishlist(int ebookId) async {
    final inWishlist = state.isInWishlist(ebookId);
    try {
      if (inWishlist) {
        await ApiService.dio.delete(ApiConstants.wishlistItem(ebookId));
        state = state.copyWith(
          items: state.items.where((w) => w.ebookId != ebookId).toList(),
        );
      } else {
        final res =
            await ApiService.dio.post(ApiConstants.wishlistItem(ebookId));
        final newItem = WishlistModel.fromJson({
          'id':       res.data['wishlist_id'],
          'user_id':  0,
          'ebook_id': ebookId,
        });
        state = state.copyWith(items: [...state.items, newItem]);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> removeFromWishlist(int ebookId) async {
    try {
      await ApiService.dio.delete(ApiConstants.wishlistItem(ebookId));
      state = state.copyWith(
        items: state.items.where((w) => w.ebookId != ebookId).toList(),
      );
    } catch (_) {}
  }
}

final wishlistProvider =
    StateNotifierProvider<WishlistNotifier, WishlistState>(
  (ref) => WishlistNotifier(),
);
