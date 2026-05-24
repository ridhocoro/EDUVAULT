// lib/features/auth/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../../wishlist/screens/wishlist_screen.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../../order/screens/order_history_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../admin/screens/admin_dashboard_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    // ─── Not logged in ─────────────────────────────────────────────
    if (!auth.isLoggedIn || user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF0F0F0),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFFAAAAAA),
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum Masuk',
                    style: TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Masuk untuk mengakses koleksi\ndan profil kamu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D9E75),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Masuk ke Akun',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final isAdmin = user.role == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Light Header ───────────────────────────────────────
            Container(
              color: Colors.white,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFDDDDDD),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFFEEEEEE),
                          backgroundImage: user.avatar != null
                              ? CachedNetworkImageProvider(user.avatar!)
                              : null,
                          child: user.avatar == null
                              ? Icon(
                                  Icons.person_rounded,
                                  color: const Color(0xFF888888),
                                  size: 32,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Name + badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                color: Color(0xFF1A1A2E),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isAdmin
                                    ? const Color(0xFF1D9E75).withOpacity(0.2)
                                    : const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isAdmin
                                      ? const Color(0xFF1D9E75).withOpacity(0.5)
                                      : const Color(0xFFCCCCCC),
                                ),
                              ),
                              child: Text(
                                isAdmin ? 'Administrator' : 'Member',
                                style: TextStyle(
                                  color: isAdmin
                                      ? const Color(0xFF1D9E75)
                                      : const Color(0xFF666666),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ─── Admin Panel Banner (hanya role admin) ─────────────
            if (isAdmin) ...[
              _SectionHeader(title: 'Administrasi'),
              Container(
                color: Colors.white,
                child: _SettingsRow(
                  icon: Icons.admin_panel_settings_rounded,
                  iconColor: const Color(0xFF1D9E75),
                  title: 'Admin Panel',
                  subtitle: 'Kelola buku, kategori & statistik',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminDashboardScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ─── Akun Section ───────────────────────────────────────
            _SectionHeader(title: 'Akun'),
            Container(
              color: Colors.white,
              child: _SettingsRow(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: user.email,
              ),
            ),

            const SizedBox(height: 20),

            // ─── Koleksi Section ────────────────────────────────────
            _SectionHeader(title: 'Koleksi'),
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  Consumer(builder: (context, ref, _) {
                    final wishlistCount =
                        ref.watch(wishlistProvider).items.length;
                    return _SettingsRow(
                      icon: Icons.bookmark_border_rounded,
                      title: 'Wishlist Saya',
                      subtitle: wishlistCount > 0
                          ? '$wishlistCount buku tersimpan'
                          : 'Buku yang ingin dibeli nanti',
                      badgeCount: wishlistCount > 0 ? wishlistCount : null,
                      onTap: () {
                        ref.read(wishlistProvider.notifier).loadWishlist();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const WishlistScreen()),
                        );
                      },
                    );
                  }),
                  _RowDivider(),
                  _SettingsRow(
                    icon: Icons.receipt_long_outlined,
                    title: 'Riwayat Pesanan',
                    subtitle: 'Lihat semua transaksi',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const OrderHistoryScreen()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── Logout ─────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: const Text('Keluar'),
                      content: const Text(
                          'Apakah kamu yakin ingin logout dari EduVault?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Batal',
                              style: TextStyle(color: Color(0xFF888888))),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Keluar'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(authProvider.notifier).logout();
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.redAccent.withOpacity(0.04),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded,
                          color: Colors.redAccent, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Keluar',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF888780),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Settings Row ─────────────────────────────────────────────────────
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final int? badgeCount;

  const _SettingsRow({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? const Color(0xFF888780)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (badgeCount != null)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D9E75),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 50,
      endIndent: 0,
      color: Color(0xFFF0F0F0),
    );
  }
}