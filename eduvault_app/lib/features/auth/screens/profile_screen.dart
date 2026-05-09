// lib/features/auth/screens/profile_screen.dart
// REDESIGN sesuai Figma — Dark header + stats + settings list

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../../wishlist/screens/wishlist_screen.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../../order/screens/order_history_screen.dart';
import '../../auth/screens/login_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    // Not logged in state
    if (!auth.isLoggedIn || user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Column(
          children: [
            // Dark header
            Container(
              color: const Color(0xFF0F1923),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    children: [
                      // Avatar placeholder
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: Colors.white.withOpacity(0.5),
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum Masuk',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9E75),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Masuk ke Akun',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isPremium = user.role == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Dark Header ─────────────────────────────────────
            Container(
              color: const Color(0xFF0F1923),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    children: [
                      // Avatar + name
                      Row(
                        children: [
                          // Avatar
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 32,
                              backgroundColor:
                                  Colors.white.withOpacity(0.1),
                              backgroundImage: user.avatar != null
                                  ? CachedNetworkImageProvider(user.avatar!)
                                  : null,
                              child: user.avatar == null
                                  ? Icon(
                                      Icons.person_rounded,
                                      color: Colors.white.withOpacity(0.7),
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
                                    color: Colors.white,
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
                                    color: isPremium
                                        ? const Color(0xFF1D9E75)
                                            .withOpacity(0.2)
                                        : Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isPremium
                                          ? const Color(0xFF1D9E75)
                                              .withOpacity(0.5)
                                          : Colors.white.withOpacity(0.15),
                                    ),
                                  ),
                                  child: Text(
                                    isPremium
                                        ? 'Member Premium'
                                        : 'Member',
                                    style: TextStyle(
                                      color: isPremium
                                          ? const Color(0xFF1D9E75)
                                          : Colors.white.withOpacity(0.6),
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
                      const SizedBox(height: 20),

                      // Stats row
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            _HeaderStat(value: '24', label: 'Buku Dibeli'),
                            _Divider(),
                            _HeaderStat(value: '18', label: 'Selesai Dibaca'),
                            _Divider(),
                            _HeaderStat(value: '156', label: 'Jam Baca'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ─── Akun Section ─────────────────────────────────────
            _SectionHeader(title: 'Akun'),
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    subtitle: user.email,
                  ),
                  _RowDivider(),
                  _SettingsRow(
                    icon: Icons.phone_outlined,
                    title: 'Nomor Telepon',
                    subtitle: '+62 812-3456-7890',
                  ),
                  _RowDivider(),
                  _SettingsRow(
                    icon: Icons.credit_card_outlined,
                    title: 'Metode Pembayaran',
                    subtitle: '2 kartu tersimpan',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── Koleksi Section ──────────────────────────────────
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
                      badgeCount:
                          wishlistCount > 0 ? wishlistCount : null,
                      onTap: () {
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

            // ─── Pengaturan Section ───────────────────────────────
            _SectionHeader(title: 'Pengaturan'),
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.settings_outlined,
                    title: 'Pengaturan Aplikasi',
                    onTap: () {},
                  ),
                  _RowDivider(),
                  _SettingsRow(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifikasi',
                    onTap: () {},
                  ),
                  _RowDivider(),
                  _SettingsRow(
                    icon: Icons.help_outline_rounded,
                    title: 'Bantuan & Dukungan',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── Logout ───────────────────────────────────────────
            Container(
              color: Colors.white,
              child: InkWell(
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

// ─── Header Stat ────────────────────────────────────────────────────
class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;

  const _HeaderStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: 1,
      color: Colors.white.withOpacity(0.1),
    );
  }
}

// ─── Section Header ─────────────────────────────────────────────────
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

// ─── Settings Row ────────────────────────────────────────────────────
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final int? badgeCount;

  const _SettingsRow({
    required this.icon,
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
            Icon(icon, size: 20, color: const Color(0xFF888780)),
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
