// lib/features/subscription/screens/subscription_checkout_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/subscription_model.dart';
import '../providers/subscription_provider.dart';

class SubscriptionCheckoutScreen extends ConsumerStatefulWidget {
  final SubscriptionPlanModel plan;
  const SubscriptionCheckoutScreen({super.key, required this.plan});

  @override
  ConsumerState<SubscriptionCheckoutScreen> createState() =>
      _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState
    extends ConsumerState<SubscriptionCheckoutScreen> {
  bool _loading = false;
  String? _error;

  String get _formattedPrice =>
      'Rp ${widget.plan.price.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]}.',
          )}';

  Future<void> _pay() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(subscriptionProvider.notifier)
          .subscribe(widget.plan.id);

      final snapToken = result['snap_token'] as String;
      final clientKey = result['client_key'] as String;

      if (!mounted) return;

      // Buka Midtrans Snap via WebView
      final paymentResult = await Navigator.push<_PaymentResult>(
        context,
        MaterialPageRoute(
          builder: (_) => _MidtransWebView(
            snapToken: snapToken,
            clientKey: clientKey,
            planName: widget.plan.name,
          ),
        ),
      );

      if (!mounted) return;

      if (paymentResult == _PaymentResult.success) {
        // Refresh status subscription
        await ref.read(subscriptionProvider.notifier).onPaymentSuccess();

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Berhasil berlangganan ${widget.plan.name}!'),
            backgroundColor: const Color(0xFF1D9E75),
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (paymentResult == _PaymentResult.pending) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran sedang diproses. Koleksi akan diperbarui otomatis.'),
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        // cancelled atau null (user tutup WebView)
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Gagal memproses pembayaran. Silakan coba lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Konfirmasi Langganan',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Plan summary card ────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D9E75).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.workspace_premium_rounded,
                            color: Color(0xFF1D9E75), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.plan.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            Text(
                              '${widget.plan.durationDays} hari akses penuh',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF888888),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  _SummaryRow(
                    label: 'Jumlah buku',
                    value: '${widget.plan.ebooks.isNotEmpty ? widget.plan.ebooks.length : (widget.plan.ebooksCount ?? 0)} buku',
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'Durasi',
                    value: '${widget.plan.durationDays} hari',
                  ),
                  const SizedBox(height: 8),
                  const _SummaryRow(
                    label: 'AI Chat',
                    value: 'Bebas tanpa batas',
                    valueColor: Color(0xFF1D9E75),
                  ),
                  const Divider(height: 28),
                  _SummaryRow(
                    label: 'Total Pembayaran',
                    value: _formattedPrice,
                    bold: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Info box ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFFD54F).withOpacity(0.5)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: Color(0xFFF9A825)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Akses berlaku selama 30 hari sejak pembayaran berhasil. '
                      'Buku dari paket ini akan muncul di Koleksi kamu.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF795548),
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            // ── Error box ────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 18, color: Color(0xFFE53935)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Color(0xFFB71C1C), fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ── Pay button ───────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _pay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Bayar $_formattedPrice',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Enum hasil pembayaran ────────────────────────────────────────────
enum _PaymentResult { success, pending, cancelled }

// ─── WebView Midtrans Snap ────────────────────────────────────────────
class _MidtransWebView extends StatefulWidget {
  final String snapToken;
  final String clientKey;
  final String planName;

  const _MidtransWebView({
    required this.snapToken,
    required this.clientKey,
    required this.planName,
  });

  @override
  State<_MidtransWebView> createState() => _MidtransWebViewState();
}

class _MidtransWebViewState extends State<_MidtransWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  // URL Midtrans Snap — ganti ke production saat live
  // Sandbox : https://app.sandbox.midtrans.com/snap/v2/vtweb/<token>
  // Production: https://app.midtrans.com/snap/v2/vtweb/<token>
  static const bool _isSandbox = true; // ← ganti false saat production

  String get _snapUrl {
    final base = _isSandbox
        ? 'https://app.sandbox.midtrans.com/snap/v2/vtweb'
        : 'https://app.midtrans.com/snap/v2/vtweb';
    return '$base/${widget.snapToken}';
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (request) {
            return _handleNavigation(request);
          },
        ),
      )
      ..loadRequest(Uri.parse(_snapUrl));
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final url = request.url.toLowerCase();

    // Midtrans redirect URL setelah transaksi selesai
    // Format: https://app.midtrans.com/snap/v2/vtweb/{token}/result?...
    // atau custom finish URL yang di-set di dashboard Midtrans
    if (url.contains('/finish') ||
        url.contains('transaction_status=settlement') ||
        url.contains('transaction_status=capture')) {
      Navigator.pop(context, _PaymentResult.success);
      return NavigationDecision.prevent;
    }

    if (url.contains('transaction_status=pending')) {
      Navigator.pop(context, _PaymentResult.pending);
      return NavigationDecision.prevent;
    }

    if (url.contains('/error') ||
        url.contains('transaction_status=cancel') ||
        url.contains('transaction_status=deny') ||
        url.contains('transaction_status=expire')) {
      Navigator.pop(context, _PaymentResult.cancelled);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Bayar — ${widget.planName}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context, _PaymentResult.cancelled),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
            ),
        ],
      ),
    );
  }
}

// ─── Summary Row ──────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 14 : 13,
            color: bold ? const Color(0xFF1A1A2E) : const Color(0xFF888888),
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 13,
            color: valueColor ?? const Color(0xFF1A1A2E),
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}