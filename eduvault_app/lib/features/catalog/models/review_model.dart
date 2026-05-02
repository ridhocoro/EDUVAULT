class ReviewModel {
  final int id;
  final int userId;
  final int ebookId;
  final int rating;
  final String? comment;
  final String createdAt;
  final ReviewUserModel? user;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.ebookId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.user,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id:        json['id'],
      userId:    json['user_id'],
      ebookId:   json['ebook_id'],
      rating:    json['rating'],
      comment:   json['comment'],
      createdAt: json['created_at'] ?? '',
      user: json['user'] != null
          ? ReviewUserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ReviewUserModel {
  final int id;
  final String name;
  final String? avatar;

  ReviewUserModel({required this.id, required this.name, this.avatar});

  factory ReviewUserModel.fromJson(Map<String, dynamic> json) {
    return ReviewUserModel(
      id:     json['id'],
      name:   json['name'],
      avatar: json['avatar'],
    );
  }
}

class ReviewSummary {
  final List<ReviewModel> reviews;
  final double? averageRating;
  final int totalReviews;

  ReviewSummary({
    required this.reviews,
    this.averageRating,
    required this.totalReviews,
  });
}
