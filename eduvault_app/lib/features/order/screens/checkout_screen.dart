import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../catalog/models/ebook_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final EbookModel ebook;
  const CheckoutScreen({super.key, required this.ebook});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _loading = false;

  Future<void> _createOrder() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.dio.post(ApiConstants.orders, data: {
        'ebook_ids': [widget.ebook.id],
      });

      // res.data['snap_token'] → nanti gunakan untuk Midtrans Snap SDK
      // Untuk sekarang, simulasi pembayaran berhasil
      final orderCode = res.data['order']['order_code'];

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order $orderCode berhasil dibuat! (Integrasi Midtrans menyusul)'),
            backgroundColor: const Color(0xFF1D9E75),
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuat order. Coba lagi.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF1A1A2E)),
        title: const Text('Checkout',
            style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ringkasan Pembelian',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            // Item card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8E6DF)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 65,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F5EE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.menu_book_rounded,
                        color: Color(0xFF1D9E75)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.ebook.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        if (widget.ebook.category != null)
                          Text(widget.ebook.category!.name,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF888780))),
                      ],
                    ),
                  ),
                  Text(
                    'Rp ${widget.ebook.price.toStringAsFixed(0).replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (m) => '${m[1]}.',
                        )}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D9E75)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Pembayaran',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(
                  'Rp ${widget.ebook.price.toStringAsFixed(0).replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (m) => '${m[1]}.',
                      )}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Color(0xFF1D9E75)),
                ),
              ],
            ),

            const Spacer(),

            // Tombol bayar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _createOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Lanjut Bayar',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}