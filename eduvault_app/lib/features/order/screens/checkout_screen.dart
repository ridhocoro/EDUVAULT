import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
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

  // ── Polling status order sampai paid / failed / timeout ─────────
  Future<String> _pollOrderStatus(String orderCode) async {
    const maxAttempts = 10;
    const delay = Duration(seconds: 3);

    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(delay);
      try {
        final res = await ApiService.dio.get(ApiConstants.orderDetail(orderCode));
        final status = res.data['status'] as String? ?? '';
        if (status == 'paid') return 'success';
        if (status == 'failed') return 'failed';
        // status 'pending' → lanjut polling
      } catch (_) {
        // network error → lanjut polling
      }
    }
    // Timeout setelah ~30 detik → anggap pending
    return 'pending';
  }

  Future<void> _pay() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.dio.post(ApiConstants.orders, data: {
        'ebook_ids': [widget.ebook.id],
      });

      final snapToken = res.data['snap_token'] as String?;
      final orderCode = res.data['order']?['order_code'] as String?;

      if (snapToken == null || orderCode == null) {
        throw Exception('Data order tidak lengkap dari server.');
      }

      if (!mounted) return;

      // Buka WebView Snap Midtrans
      final webResult = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => _MidtransSnapWebView(snapToken: snapToken),
        ),
      );

      if (!mounted) return;

      // Langsung polling — baik setelah bayar maupun setelah user klik X
      // Polling akan tentukan apakah paid, pending, atau failed
      setState(() => _loading = true);
      _showPollingDialog();

      final finalStatus = await _pollOrderStatus(orderCode);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // tutup dialog polling

      if (finalStatus == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran berhasil! Buku sudah tersedia di Library. 🎉'),
            backgroundColor: Color(0xFF1D9E75),
            duration: Duration(seconds: 3),
          ),
        );
        // Kembali ke halaman detail buku (bukan home) agar _fetchDetail() terpanggil
        Navigator.pop(context);
      } else if (finalStatus == 'pending') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran diproses. Jika sudah bayar, buku akan muncul di Library dalam beberapa saat.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran gagal. Silakan coba lagi.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses pembayaran: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPollingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF1D9E75)),
            SizedBox(width: 20),
            Expanded(child: Text('Mengecek status pembayaran...')),
          ],
        ),
      ),
    );
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
                    width: 50, height: 65,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F5EE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Color(0xFF1D9E75)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.ebook.title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        if (widget.ebook.category != null)
                          Text(widget.ebook.category!.name,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF888780))),
                      ],
                    ),
                  ),
                  Text('Rp ${_formatPrice(widget.ebook.price)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1D9E75))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: Color(0xFFE8E6DF)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FBF7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFB8E8D8)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.payment_rounded, color: Color(0xFF1D9E75), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pilih metode pembayaran di halaman berikutnya\n(Transfer Bank, QRIS, GoPay, dll.)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF2E7D62)),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Pembayaran',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text('Rp ${_formatPrice(widget.ebook.price)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF1D9E75))),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _pay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Bayar Sekarang',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }
}

// ── WebView Midtrans Snap ─────────────────────────────────────────
class _MidtransSnapWebView extends StatefulWidget {
  final String snapToken;
  const _MidtransSnapWebView({required this.snapToken});

  @override
  State<_MidtransSnapWebView> createState() => _MidtransSnapWebViewState();
}

class _MidtransSnapWebViewState extends State<_MidtransSnapWebView> {
  late final WebViewController _controller;
  bool _webLoading = true;

  static const String _snapBaseUrl =
      'https://app.sandbox.midtrans.com/snap/v2/vtweb/';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            // Deteksi halaman finish/success/pending dari Midtrans
            if (_isFinishUrl(url)) {
              final result = _parseResult(url);
              Navigator.pop(context, result);
            }
          },
          onPageFinished: (_) => setState(() => _webLoading = false),
        ),
      )
      ..loadRequest(Uri.parse('$_snapBaseUrl${widget.snapToken}'));
  }

  bool _isFinishUrl(String url) {
    return url.contains('/finish') ||
        url.contains('/unfinish') ||
        url.contains('/error') ||
        url.contains('transaction_status=');
  }

  String _parseResult(String url) {
    if (url.contains('transaction_status=settlement') ||
        url.contains('transaction_status=capture') ||
        url.contains('/finish')) {
      return 'paid';
    }
    if (url.contains('transaction_status=pending') ||
        url.contains('/unfinish')) {
      return 'pending';
    }
    return 'pending'; // default: anggap pending, polling akan tentukan hasilnya
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A1A2E)),
          // Saat user klik X, anggap sudah selesai bayar → trigger polling
          onPressed: () => Navigator.pop(context, 'pending'),
        ),
        title: const Text('Pembayaran',
            style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 16)),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_webLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
            ),
        ],
      ),
    );
  }
}
