class EbookModel {
  final int id;
  final String title;
  final String slug;
  final String? description;
  final String? author;
  final double price;
  final String? coverUrl;
  final String? djkiCertNo;
  final int totalPages;
  final String status;
  final CategoryModel? category;

  EbookModel({
    required this.id,
    required this.title,
    required this.slug,
    this.description,
    this.author,
    required this.price,
    this.coverUrl,
    this.djkiCertNo,
    required this.totalPages,
    required this.status,
    this.category,
  });

  factory EbookModel.fromJson(Map<String, dynamic> json) {
    return EbookModel(
      id:          json['id'],
      title:       json['title'],
      slug:        json['slug'],
      description: json['description'],
      author:      json['author'],
      price:       double.parse(json['price'].toString()),
      coverUrl:    json['cover_url'],
      djkiCertNo:  json['djki_cert_no'],
      totalPages:  json['total_pages'] ?? 0,
      status:      json['status'],
      category:    json['category'] != null
                     ? CategoryModel.fromJson(json['category'])
                     : null,
    );
  }
}

class CategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? icon;

  CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id:   json['id'],
      name: json['name'],
      slug: json['slug'],
      icon: json['icon'],
    );
  }
}