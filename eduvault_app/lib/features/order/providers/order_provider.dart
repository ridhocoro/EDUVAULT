// lib/features/order/providers/order_provider.dart

import 'package:flutter/material.dart';
import 'package:eduvault_app/core/services/api_service.dart';
import '../models/order_model.dart';

class OrderProvider extends ChangeNotifier {
  List<OrderModel> _orders = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Pagination state
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;

  // Getters
  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  bool get hasMorePages => _currentPage < _lastPage;
  int get total => _total;

  // ── Fetch (refresh dari awal) ─────────────────────────────────
  Future<void> fetchOrders() async {
    _isLoading = true;
    _errorMessage = null;
    _currentPage = 1;
    notifyListeners();

    try {
      final response = await ApiService.get('/orders?page=1');

      if (response['success'] == true) {
        final rawData = _extractList(response['data']);
        _orders = rawData.map((j) => OrderModel.fromJson(j)).toList();

        final meta = response['meta'] as Map<String, dynamic>?;
        if (meta != null) {
          _currentPage = meta['current_page'] ?? 1;
          _lastPage    = meta['last_page'] ?? 1;
          _total       = meta['total'] ?? _orders.length;
        }
      } else {
        _errorMessage = response['message'] ?? 'Gagal memuat riwayat transaksi.';
      }
    } catch (e) {
      debugPrint('Error fetchOrders: $e');
      _errorMessage = 'Gagal memproses data transaksi. Silakan coba lagi.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Load More (pagination) ─────────────────────────────────────
  Future<void> loadMoreOrders() async {
    if (_isLoadingMore || !hasMorePages) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final response = await ApiService.get('/orders?page=$nextPage');

      if (response['success'] == true) {
        final rawData = _extractList(response['data']);
        final newOrders = rawData.map((j) => OrderModel.fromJson(j)).toList();
        _orders.addAll(newOrders);

        final meta = response['meta'] as Map<String, dynamic>?;
        if (meta != null) {
          _currentPage = meta['current_page'] ?? nextPage;
          _lastPage    = meta['last_page'] ?? _lastPage;
        }
      }
    } catch (e) {
      debugPrint('Error loadMoreOrders: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ── Helper: ekstrak list dari berbagai struktur response ───────
  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data.containsKey('data') && data['data'] is List) {
      return data['data'] as List;
    }
    debugPrint('Peringatan: data bukan List, diterima: ${data.runtimeType}');
    return [];
  }
}
