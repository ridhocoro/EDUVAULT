// lib/features/order/models/order_model.dart

class OrderModel {
  final int id;
  final String orderCode;
  final double totalAmount;
  final String status;
  final String? paymentMethod;
  final String? midtransToken;
  final String? midtransOrderId;
  final DateTime createdAt;
  final DateTime? paidAt;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.orderCode,
    required this.totalAmount,
    required this.status,
    this.paymentMethod,
    this.midtransToken,
    this.midtransOrderId,
    required this.createdAt,
    this.paidAt,
    required this.items,
  });

  int get itemCount => items.length;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      orderCode: json['order_code'] ?? 'ORD-${json['id']}',
      totalAmount: double.parse(json['total_amount'].toString()),
      status: json['status'],
      paymentMethod: json['payment_method'],
      midtransToken: json['midtrans_token'],
      midtransOrderId: json['midtrans_order_id'],
      createdAt: DateTime.parse(json['created_at']),
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      items: (json['items'] as List? ?? [])
          .map((item) => OrderItemModel.fromJson(item))
          .toList(),
    );
  }
}

class OrderItemModel {
  final int id;
  final double price;

  // Data dari relasi ebook
  final int? ebookId;
  final String ebookTitle;
  final String? ebookAuthor;
  final String? ebookCoverUrl;
  final String? ebookCategory;
  final int? ebookTotalPages;

  OrderItemModel({
    required this.id,
    required this.price,
    this.ebookId,
    required this.ebookTitle,
    this.ebookAuthor,
    this.ebookCoverUrl,
    this.ebookCategory,
    this.ebookTotalPages,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final ebook = json['ebook'] as Map<String, dynamic>?;
    final category = ebook?['category'] as Map<String, dynamic>?;

    return OrderItemModel(
      id: json['id'],
      price: double.parse(json['price'].toString()),
      ebookId: ebook?['id'],
      ebookTitle: ebook?['title'] ?? 'Buku Tidak Tersedia',
      ebookAuthor: ebook?['author'],
      ebookCoverUrl: ebook?['cover_url'],
      ebookCategory: category?['name'],
      ebookTotalPages: ebook?['total_pages'],
    );
  }
}
