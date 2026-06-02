// lib/features/catalog/models/ebook_model.dart

class CategoryModel {
  final int id;
  final String name;
  final String? slug;       // nullable — fix error #1 & #2
  final String? icon;       // tambah — fix error #3
  final int? ebooksCount;   // tambah — fix error #2

  CategoryModel({
    required this.id,
    required this.name,
    this.slug,
    this.icon,
    this.ebooksCount,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id:           json['id'],
      name:         json['name'] ?? '',
      slug:         json['slug'],
      icon:         json['icon'],
      ebooksCount:  json['ebooks_count'],
    );
  }
}

class EbookModel {
  final int id;
  final String title;
  final String slug;
  final String? description;
  final String? author;
  final double price;
  final String? coverUrl;
  final String? fileUrl;
  final String? djkiCertNo;
  final int totalPages;
  final String status;       // non-nullable — fix error #4 (_StatusBadge)
  final int? categoryId;
  final CategoryModel? category;

  // Library/pivot fields
  final bool isFinished;
  final String? finishedAt;
  final String sourceType;
  final String? libraryExpires;
  final bool subscriptionExpired;

  EbookModel({
    required this.id,
    required this.title,
    required this.slug,
    this.description,
    this.author,
    required this.price,
    this.coverUrl,
    this.fileUrl,
    this.djkiCertNo,
    required this.totalPages,
    this.status = 'draft',
    this.categoryId,
    this.category,
    this.isFinished = false,
    this.finishedAt,
    this.sourceType = 'purchase',
    this.libraryExpires,
    this.subscriptionExpired = false,
  });

  factory EbookModel.fromJson(Map<String, dynamic> json) {
    CategoryModel? category;
    if (json['category'] != null) {
      category = CategoryModel.fromJson(json['category']);
    }

    return EbookModel(
      id:                  json['id'],
      title:               json['title'] ?? '',
      slug:                json['slug'] ?? '',
      description:         json['description'],
      author:              json['author'],
      price:               double.parse((json['price'] ?? 0).toString()),
      coverUrl:            json['cover_url'],
      fileUrl:             json['file_url'],
      djkiCertNo:          json['djki_cert_no'],
      totalPages:          json['total_pages'] ?? 0,
      status:              json['status'] ?? 'draft',   // default 'draft' jika null
      categoryId:          json['category_id'],
      category:            category,
      isFinished:          json['is_finished'] == true,
      finishedAt:          json['finished_at'],
      sourceType:          json['source_type'] ?? 'purchase',
      libraryExpires:      json['library_expires'],
      subscriptionExpired: json['subscription_expired'] == true,
    );
  }

  /// fix error #5 — dipakai di admin_provider.dart getEbookDetail()
  factory EbookModel.fromJsonAdmin(Map<String, dynamic> json) {
    // Response admin detail biasanya wrap dalam key 'data'
    final data = json['data'] ?? json;
    return EbookModel.fromJson(data as Map<String, dynamic>);
  }

  bool get isFromSubscription => sourceType == 'subscription';
  bool get isAccessible => !subscriptionExpired;
}