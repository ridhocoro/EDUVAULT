// lib/features/subscription/models/subscription_model.dart

import '../../catalog/models/ebook_model.dart';

class SubscriptionPlanModel {
  final int id;
  final String name;
  final String? description;
  final double price;
  final int durationDays;
  final String status;
  final List<EbookModel> ebooks;
  final int? ebooksCount;

  SubscriptionPlanModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.durationDays,
    required this.status,
    this.ebooks = const [],
    this.ebooksCount,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id:           json['id'],
      name:         json['name'] ?? '',
      description:  json['description'],
      price:        double.parse(json['price'].toString()),
      durationDays: json['duration_days'] ?? 30,
      status:       json['status'] ?? 'active',
      ebooksCount:  json['ebooks_count'],
      ebooks: (json['ebooks'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => EbookModel.fromJson(e))
          .toList(),
    );
  }
}

class UserSubscriptionModel {
  final int id;
  final int userId;
  final int subscriptionPlanId;
  final DateTime startsAt;
  final DateTime expiresAt;
  final String status;
  final SubscriptionPlanModel? plan;

  UserSubscriptionModel({
    required this.id,
    required this.userId,
    required this.subscriptionPlanId,
    required this.startsAt,
    required this.expiresAt,
    required this.status,
    this.plan,
  });

  bool get isActive =>
      status == 'active' && expiresAt.isAfter(DateTime.now());

  int get daysLeft =>
      expiresAt.difference(DateTime.now()).inDays.clamp(0, 9999);

  factory UserSubscriptionModel.fromJson(Map<String, dynamic> json) {
    return UserSubscriptionModel(
      id:                   json['id'],
      userId:               json['user_id'],
      subscriptionPlanId:   json['subscription_plan_id'],
      startsAt:             DateTime.parse(json['starts_at']),
      expiresAt:            DateTime.parse(json['expires_at']),
      status:               json['status'] ?? 'active',
      plan: json['plan'] != null
          ? SubscriptionPlanModel.fromJson(json['plan'])
          : null,
    );
  }
}
