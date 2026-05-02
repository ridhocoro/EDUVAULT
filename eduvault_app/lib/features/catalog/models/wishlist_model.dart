import 'ebook_model.dart';

class WishlistModel {
  final int id;
  final int userId;
  final int ebookId;
  final EbookModel? ebook;

  WishlistModel({
    required this.id,
    required this.userId,
    required this.ebookId,
    this.ebook,
  });

  factory WishlistModel.fromJson(Map<String, dynamic> json) {
    return WishlistModel(
      id:      json['id'],
      userId:  json['user_id'],
      ebookId: json['ebook_id'],
      ebook: json['ebook'] != null
          ? EbookModel.fromJson(json['ebook'] as Map<String, dynamic>)
          : null,
    );
  }
}
