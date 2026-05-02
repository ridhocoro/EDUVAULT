import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../models/review_model.dart';

// State
class ReviewState {
  final List<ReviewModel> reviews;
  final double? averageRating;
  final int totalReviews;
  final bool loading;
  final String? error;

  const ReviewState({
    this.reviews = const [],
    this.averageRating,
    this.totalReviews = 0,
    this.loading = false,
    this.error,
  });

  ReviewState copyWith({
    List<ReviewModel>? reviews,
    double? averageRating,
    int? totalReviews,
    bool? loading,
    String? error,
  }) {
    return ReviewState(
      reviews:       reviews ?? this.reviews,
      averageRating: averageRating ?? this.averageRating,
      totalReviews:  totalReviews ?? this.totalReviews,
      loading:       loading ?? this.loading,
      error:         error,
    );
  }
}

// Notifier
class ReviewNotifier extends StateNotifier<ReviewState> {
  final int ebookId;

  ReviewNotifier(this.ebookId) : super(const ReviewState());

  Future<void> loadReviews() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await ApiService.dio.get(ApiConstants.ebookReviews(ebookId));
      final data = res.data as Map<String, dynamic>;

      final rawReviews = (data['reviews'] as Map)['data'] as List? ?? [];
      final reviews = rawReviews
          .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        reviews:       reviews,
        averageRating: data['average_rating'] != null
            ? double.tryParse(data['average_rating'].toString())
            : null,
        totalReviews:  data['total_reviews'] ?? 0,
        loading:       false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<bool> submitReview({required int rating, String? comment}) async {
    try {
      await ApiService.dio.post(
        ApiConstants.ebookReviews(ebookId),
        data: {'rating': rating, 'comment': comment},
      );
      await loadReviews();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteReview() async {
    try {
      await ApiService.dio.delete(ApiConstants.ebookReviews(ebookId));
      await loadReviews();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// Provider factory — satu per ebookId
final reviewProvider = StateNotifierProvider.family<ReviewNotifier, ReviewState, int>(
  (ref, ebookId) => ReviewNotifier(ebookId),
);
