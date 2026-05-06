import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../../library/screens/library_screen.dart';
import '../../wishlist/screens/wishlist_screen.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../../order/screens/order_history_screen.dart'; // Sesuaikan path folder Anda

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Tidak ada data user.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profil Saya',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── Header avatar + nama ─────────────────────────────
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFF1D9E75),
                    backgroundImage: user.avatar != null
                        ? CachedNetworkImageProvider(user.avatar!)
                        : null,
                    child: user.avatar == null
                        ? Text(
                            user.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5F5E5A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F5EE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user.role == 'admin' ? '👑 Admin' : '📚 Pengguna',
                      style: const TextStyle(
                        color: Color(0xFF1D9E75),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ─── Menu profil ──────────────────────────────────────
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _MenuItem(
                    icon: Icons.menu_book_rounded,
                    label: 'Library Saya',
                    subtitle: 'E-book yang sudah dibeli',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LibraryScreen()),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),

                  // ── Wishlist ──────────────────────────────────
                  Consumer(
                    builder: (context, ref, _) {
                      final wishlistCount =
                          ref.watch(wishlistProvider).items.length;
                      return _MenuItem(
                        icon: Icons.bookmark_rounded,
                        label: 'Wishlist Saya',
                        subtitle: wishlistCount > 0
                            ? '$wishlistCount buku tersimpan'
                            : 'Buku yang ingin dibeli nanti',
                        badge: wishlistCount > 0
                            ? wishlistCount.toString()
                            : null,
                        onTap: () {
                          // Load terbaru sebelum buka screen
                          ref
                              .read(wishlistProvider.notifier)
                              .loadWishlist();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const WishlistScreen()),
                          );
                        },
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),

                  _MenuItem(
                    icon: Icons.receipt_long_outlined,
                    label: 'Riwayat Pesanan',
                    subtitle: 'Lihat semua transaksi',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OrderHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuItem(
                    icon: Icons.info_outline_rounded,
                    label: 'Tentang Aplikasi',
                    subtitle: 'EduVault v1.0.0',
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'EduVault',
                        applicationVersion: '1.0.0',
                        applicationLegalese:
                            '© 2025 EduVault. All rights reserved.',
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ─── Logout ───────────────────────────────────────────
            Container(
              color: Colors.white,
              child: _MenuItem(
                icon: Icons.logout_rounded,
                label: 'Keluar',
                subtitle: 'Logout dari akun ini',
                iconColor: Colors.redAccent,
                textColor: Colors.redAccent,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Keluar'),
                      content: const Text(
                          'Apakah kamu yakin ingin logout dari EduVault?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Batal'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Keluar'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconColor;
  final Color textColor;
  final String? badge;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.iconColor = const Color(0xFF1D9E75),
    this.textColor = const Color(0xFF1A1A2E),
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: textColor,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Color(0xFF888780), fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1D9E75),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
