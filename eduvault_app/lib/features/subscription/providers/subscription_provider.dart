// lib/features/subscription/providers/subscription_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../models/subscription_model.dart';

// ── State ─────────────────────────────────────────────────────────────

class SubscriptionState {
  final List<SubscriptionPlanModel> plans;
  final UserSubscriptionModel? activeSubscription;
  final bool loadingPlans;
  final bool loadingMySub;
  final String? error;

  const SubscriptionState({
    this.plans = const [],
    this.activeSubscription,
    this.loadingPlans = false,
    this.loadingMySub = false,
    this.error,
  });

  bool get hasActiveSub =>
      activeSubscription != null && activeSubscription!.isActive;

  SubscriptionState copyWith({
    List<SubscriptionPlanModel>? plans,
    UserSubscriptionModel? activeSubscription,
    bool clearSub = false,
    bool? loadingPlans,
    bool? loadingMySub,
    String? error,
  }) {
    return SubscriptionState(
      plans:              plans ?? this.plans,
      activeSubscription: clearSub ? null : (activeSubscription ?? this.activeSubscription),
      loadingPlans:       loadingPlans ?? this.loadingPlans,
      loadingMySub:       loadingMySub ?? this.loadingMySub,
      error:              error,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier() : super(const SubscriptionState());

  /// Ambil daftar paket subscription (publik)
  Future<void> fetchPlans() async {
    state = state.copyWith(loadingPlans: true, error: null);
    try {
      final res = await ApiService.dio.get(ApiConstants.subscriptionPlans);
      final list = (res.data['data'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => SubscriptionPlanModel.fromJson(e))
          .toList();
      state = state.copyWith(plans: list, loadingPlans: false);
    } catch (e) {
      state = state.copyWith(
        loadingPlans: false,
        error: 'Gagal memuat paket langganan.',
      );
    }
  }

  /// Ambil subscription aktif user
  Future<void> fetchMySubscription() async {
    state = state.copyWith(loadingMySub: true, error: null);
    try {
      final res = await ApiService.dio.get(ApiConstants.mySubscription);
      final data = res.data;
      if (data['active'] == true && data['subscription'] != null) {
        final sub = UserSubscriptionModel.fromJson(data['subscription']);
        state = state.copyWith(activeSubscription: sub, loadingMySub: false);
      } else {
        state = state.copyWith(clearSub: true, loadingMySub: false);
      }
    } catch (_) {
      state = state.copyWith(loadingMySub: false, clearSub: true);
    }
  }

  /// Buat order subscription — return snap_token dan client_key
  Future<Map<String, dynamic>> subscribe(int planId) async {
    final res = await ApiService.dio.post(
      ApiConstants.subscribeToPlan(planId),
    );
    return {
      'snap_token': res.data['snap_token'],
      'client_key': res.data['client_key'],
      'order':      res.data['order'],
    };
  }

  /// Dipanggil setelah pembayaran berhasil — refresh status sub
  Future<void> onPaymentSuccess() async {
    await fetchMySubscription();
  }

  void reset() {
    state = const SubscriptionState();
  }
}

// ── Provider ──────────────────────────────────────────────────────────

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  (ref) => SubscriptionNotifier(),
);
