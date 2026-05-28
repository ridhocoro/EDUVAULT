// lib/features/order/screens/order_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/order_provider.dart';
import '../models/order_model.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  static const _primaryDark = Color(0xFF1A1A2E);
  static const _accent = Color(0xFF1D9E75);
  static const _bgColor = Color(0xFFF8F7F4);

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OrderProvider>().fetchOrders();
    });
  }

  // ── Helpers ────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'success':
        return const Color(0xFF1D9E75);
      case 'pending':
        return const Color(0xFFE59C2B);
      case 'failed':
      case 'cancel':
      case 'refunded':
        return const Color(0xFFE53935);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Lunas';
      case 'pending':
        return 'Menunggu Pembayaran';
      case 'failed':
        return 'Gagal';
      case 'cancel':
        return 'Dibatalkan';
      case 'refunded':
        return 'Dikembalikan';
      default:
        return status.toUpperCase();
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'success':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.access_time_rounded;
      case 'failed':
      case 'cancel':
        return Icons.cancel_rounded;
      case 'refunded':
        return Icons.reply_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  String _paymentMethodLabel(String? method) {
    if (method == null || method.isEmpty) return '—';
    final map = {
      'qris': 'QRIS',
      'va_bca': 'VA BCA',
      'va_bni': 'VA BNI',
      'va_bri': 'VA BRI',
      'va_mandiri': 'VA Mandiri',
      'gopay': 'GoPay',
      'shopeepay': 'ShopeePay',
      'credit_card': 'Kartu Kredit',
      'bank_transfer': 'Transfer Bank',
    };
    return map[method.toLowerCase()] ?? method.toUpperCase();
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          'Riwayat Transaksi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _primaryDark,
        surfaceTintColor: Colors.white,
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
            );
          }

          if (provider.errorMessage != null) {
            return _buildError(provider);
          }

          if (provider.orders.isEmpty) {
            return _buildEmpty();
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchOrders(),
            color: _accent,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              itemCount: provider.orders.length,
              itemBuilder: (context, index) =>
                  _buildOrderCard(provider.orders[index]),
            ),
          );
        },
      ),
    );
  }

  // ── Order Card ──────────────────────────────────────────────────

  Widget _buildOrderCard(OrderModel order) {
    final statusColor = _statusColor(order.status);
    final isPending = order.status.toLowerCase() == 'pending';
    final isPaid = order.status.toLowerCase() == 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────
            _buildCardHeader(order, statusColor, isPaid),

            // ── Divider ────────────────────────────────────────
            Divider(height: 1, color: Colors.grey.shade100),

            // ── Items List ─────────────────────────────────────
            ...order.items.map((item) => _buildItemTile(item)),

            // ── Footer ─────────────────────────────────────────
            _buildCardFooter(order, isPending, isPaid),
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader(OrderModel order, Color statusColor, bool isPaid) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Order Code + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _primaryDark,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm', 'id_ID')
                          .format(order.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildStatusBadge(order.status, statusColor),
            ],
          ),

          const SizedBox(height: 14),

          // Row: Info chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildInfoChip(
                Icons.menu_book_rounded,
                '${order.itemCount} Buku',
                Colors.blue.shade50,
                Colors.blue.shade700,
              ),
              _buildInfoChip(
                Icons.payments_rounded,
                _currencyFormat.format(order.totalAmount),
                Colors.green.shade50,
                Colors.green.shade700,
              ),
              if (order.paymentMethod != null)
                _buildInfoChip(
                  Icons.credit_card_rounded,
                  _paymentMethodLabel(order.paymentMethod),
                  Colors.purple.shade50,
                  Colors.purple.shade700,
                ),
              if (isPaid && order.paidAt != null)
                _buildInfoChip(
                  Icons.check_circle_outline_rounded,
                  'Dibayar ${DateFormat('dd MMM yyyy').format(order.paidAt!)}',
                  Colors.teal.shade50,
                  Colors.teal.shade700,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            _statusLabel(status),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
      IconData icon, String label, Color bgColor, Color fgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fgColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── Item Tile ───────────────────────────────────────────────────

  Widget _buildItemTile(OrderItemModel item) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.ebookCoverUrl != null
                ? Image.network(
                    item.ebookCoverUrl!,
                    width: 52,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildCoverFallback(),
                  )
                : _buildCoverFallback(),
          ),

          const SizedBox(width: 12),

          // Book Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.ebookTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _primaryDark,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.ebookAuthor != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          item.ebookAuthor!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (item.ebookCategory != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.label_outline_rounded,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text(
                        item.ebookCategory!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
                if (item.ebookTotalPages != null && item.ebookTotalPages! > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.article_outlined,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text(
                        '${item.ebookTotalPages} halaman',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                // Price tag
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _currencyFormat.format(item.price),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverFallback() {
    return Container(
      width: 52,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.menu_book_rounded,
          size: 28, color: Colors.grey.shade400),
    );
  }

  // ── Card Footer ─────────────────────────────────────────────────

  Widget _buildCardFooter(OrderModel order, bool isPending, bool isPaid) {
    // Footer untuk order PAID — tampilkan referensi Midtrans
    if (isPaid && order.midtransOrderId != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 6),
            Text(
              'Ref: ${order.midtransOrderId}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade400,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
    }

    // Footer untuk order PENDING — tombol bayar
    if (isPending) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // TODO: Integrasi Midtrans Snap
            },
            icon: const Icon(Icons.payment_rounded, size: 18),
            label: const Text(
              'Bayar Sekarang',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
        ),
      );
    }

    return const SizedBox(height: 4);
  }

  // ── Empty & Error States ────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 48, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum Ada Transaksi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Riwayat pembelian bukumu akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(OrderProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded,
                  size: 48, color: Colors.red.shade300),
            ),
            const SizedBox(height: 20),
            Text(
              'Gagal Memuat Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.fetchOrders(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryDark,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
