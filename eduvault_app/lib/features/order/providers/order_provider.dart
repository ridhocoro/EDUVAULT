import 'package:flutter/material.dart';
import 'package:eduvault_app/core/services/api_service.dart';
import '../models/order_model.dart';

class OrderProvider extends ChangeNotifier {
  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchOrders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.get('/orders');
      
      if (response['success'] == true) {
        dynamic rawData;
        
        // Cek apakah response['data'] adalah Map dan memiliki key 'data' (struktur pagination Laravel)
        if (response['data'] is Map && response['data'].containsKey('data')) {
          rawData = response['data']['data'];
        } else {
          // Jika response['data'] langsung berupa List atau Map tanpa key 'data'
          rawData = response['data'];
        }

        // Pastikan rawData adalah List sebelum melakukan mapping
        if (rawData is List) {
          _orders = rawData.map((json) => OrderModel.fromJson(json)).toList();
        } else {
          _orders = [];
          debugPrint("Peringatan: Data yang diterima bukan merupakan List");
        }
      } else {
        _errorMessage = response['message'] ?? "Gagal memuat riwayat transaksi.";
      }
    } catch (e) {
      debugPrint("Detail Error fetchOrders: $e");
      _errorMessage = "Gagal memproses data transaksi. Silakan coba lagi.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}