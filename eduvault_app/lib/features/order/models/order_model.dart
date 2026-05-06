class OrderModel {
  final int id;
  final String orderCode;
  final double totalAmount;
  final String status;
  final String? midtransToken;
  final DateTime createdAt;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.orderCode,
    required this.totalAmount,
    required this.status,
    this.midtransToken,
    required this.createdAt,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      // Sesuaikan dengan nama kolom di database Anda (order_code atau order_number)
      orderCode: json['order_code'] ?? 'ORD-${json['id']}',
      totalAmount: double.parse(json['total_amount'].toString()),
      status: json['status'],
      midtransToken: json['midtrans_token'],
      createdAt: DateTime.parse(json['created_at']),
      items: (json['items'] as List)
          .map((item) => OrderItemModel.fromJson(item))
          .toList(),
    );
  }
}

class OrderItemModel {
  final int id;
  final String ebookTitle;
  final double price;

  OrderItemModel({required this.id, required this.ebookTitle, required this.price});

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'],
      // Mengambil judul dari relasi ebook yang sudah di-load di Laravel
      ebookTitle: json['ebook'] != null ? json['ebook']['title'] : 'Buku Tidak Tersedia',
      price: double.parse(json['price'].toString()),
    );
  }
}