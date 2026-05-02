// lib/features/admin/models/admin_models.dart

class AdminStats {
  final EbookStats ebooks;
  final UserStats users;
  final OrderStats orders;
  final double totalRevenue;
  final List<TopEbook> topEbooks;

  const AdminStats({
    required this.ebooks,
    required this.users,
    required this.orders,
    required this.totalRevenue,
    required this.topEbooks,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      ebooks: EbookStats.fromJson(json['ebooks']),
      users: UserStats.fromJson(json['users']),
      orders: OrderStats.fromJson(json['orders']),
      totalRevenue: double.parse(json['revenue']['total'].toString()),
      topEbooks: (json['top_ebooks'] as List)
          .map((e) => TopEbook.fromJson(e))
          .toList(),
    );
  }
}

class EbookStats {
  final int total, published, draft, archived;
  const EbookStats({
    required this.total,
    required this.published,
    required this.draft,
    required this.archived,
  });
  factory EbookStats.fromJson(Map<String, dynamic> j) => EbookStats(
        total: j['total'],
        published: j['published'],
        draft: j['draft'],
        archived: j['archived'],
      );
}

class UserStats {
  final int total, admins;
  const UserStats({required this.total, required this.admins});
  factory UserStats.fromJson(Map<String, dynamic> j) =>
      UserStats(total: j['total'], admins: j['admins']);
}

class OrderStats {
  final int total, paid, pending;
  const OrderStats(
      {required this.total, required this.paid, required this.pending});
  factory OrderStats.fromJson(Map<String, dynamic> j) =>
      OrderStats(total: j['total'], paid: j['paid'], pending: j['pending']);
}

class TopEbook {
  final int id;
  final String title;
  final String? author;
  final double price;
  final int salesCount;
  final String? categoryName;

  const TopEbook({
    required this.id,
    required this.title,
    this.author,
    required this.price,
    required this.salesCount,
    this.categoryName,
  });

  factory TopEbook.fromJson(Map<String, dynamic> j) => TopEbook(
        id: j['id'],
        title: j['title'],
        author: j['author'],
        price: double.parse(j['price'].toString()),
        salesCount: j['sales_count'] ?? 0,
        categoryName: j['category']?['name'],
      );
}
