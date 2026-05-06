import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/order_provider.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Memanggil data setelah frame pertama dirender
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<OrderProvider>().fetchOrders();
      }
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'success': return Colors.green;
      case 'pending': return Colors.orange;
      case 'failed':
      case 'cancel': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        title: const Text(
          "Riwayat Transaksi",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchOrders(),
                    child: const Text("Coba Lagi"),
                  ),
                ],
              ),
            );
          }

          if (provider.orders.isEmpty) {
            return const Center(child: Text("Belum ada riwayat pesanan."));
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchOrders(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.orders.length,
              itemBuilder: (context, index) {
                final order = provider.orders[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    shape: const RoundedRectangleBorder(side: BorderSide.none),
                    title: Text(
                      order.orderCode,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                    ),
                    subtitle: Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Rp ${order.totalAmount.toStringAsFixed(0)}",
                          style: TextStyle(
                            color: _getStatusColor(order.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          order.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: _getStatusColor(order.status),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      const Divider(height: 1),
                      ...order.items.map((item) => ListTile(
                        leading: const Icon(Icons.book, size: 20),
                        title: Text(item.ebookTitle, style: const TextStyle(fontSize: 14)),
                        trailing: Text(
                          "Rp ${item.price.toStringAsFixed(0)}",
                          style: const TextStyle(fontSize: 14),
                        ),
                      )),
                      if (order.status.toLowerCase() == 'pending')
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                // Integrasi Midtrans
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1D9E75),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text("Bayar Sekarang"),
                            ),
                          ),
                        )
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}