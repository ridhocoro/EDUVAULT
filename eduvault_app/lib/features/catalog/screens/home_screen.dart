// lib/features/catalog/screens/home_screen.dart
// REDESIGN sesuai Figma — Dark header, horizontal scroll, trending list

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/catalog_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../models/ebook_model.dart';
import 'ebook_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  static const _darkBg = Color(0xFF0F1923);
  static const _accentGreen = Color(0xFF1D9E75);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final auth = ref.watch(authProvider);
    final ebooks = catalog.filteredEbooks;

    // Split into "Baru Dirilis" (first 6) and "Trending" (rest or all sorted by rating)
    final baruDirilis = ebooks.take(6).toList();
    final trending = ebooks.skip(6).take(10).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // ─── Dark App Bar ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: _darkBg,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                color: _darkBg,
                padding: const EdgeInsets.fromLTRB(16, 50, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: logo + cart
                    Row(
                      children: [
                        const Icon(
                          Icons.menu_book_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Eduvault',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        if (auth.isLoggedIn && auth.user?.role == 'admin')
                          IconButton(
                            icon: const Icon(Icons.admin_panel_settings_rounded,
                                color: Color(0xFF1D9E75), size: 22),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminDashboardScreen()),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        const SizedBox(width: 12),
                        Stack(
                          children: [
                            const Icon(Icons.shopping_bag_outlined,
                                color: Colors.white, size: 22),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Search bar
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2A35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Cari buku, penulis, atau kategori...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.white.withOpacity(0.4),
                            size: 20,
                          ),
                          suffixIcon: _isSearching
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.white.withOpacity(0.5),
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _isSearching = false);
                                    ref
                                        .read(catalogProvider.notifier)
                                        .fetchEbooks();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (val) {
                          setState(() => _isSearching = val.isNotEmpty);
                        },
                        onSubmitted: (val) => ref
                            .read(catalogProvider.notifier)
                            .fetchEbooks(search: val),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Pinned title when collapsed
            title: null,
          ),

          // ─── Category Chips ────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: _darkBg,
              child: Column(
                children: [
                  if (catalog.categories.isNotEmpty)
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: catalog.categories.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          if (i == 0) {
                            return _CategoryChip(
                              label: 'Semua',
                              selected: catalog.selectedCategory == null,
                              onTap: () => ref
                                  .read(catalogProvider.notifier)
                                  .fetchEbooks(),
                            );
                          }
                          final cat = catalog.categories[i - 1];
                          return _CategoryChip(
                            label: cat.name,
                            selected: catalog.selectedCategory == cat.slug,
                            onTap: () => ref
                                .read(catalogProvider.notifier)
                                .fetchEbooks(category: cat.slug),
                          );
                        },
                      ),
                    ),
                  // Bottom curve
                  Container(
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Content ──────────────────────────────────────────
          if (catalog.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (catalog.errorMessage != null)
            SliverFillRemaining(
              child: _ErrorView(
                message: catalog.errorMessage!,
                onRetry: () =>
                    ref.read(catalogProvider.notifier).fetchEbooks(),
              ),
            )
          else ...[
            // ─── Baru Dirilis Section ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    const Text(
                      'Baru Dirilis',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {},
                      child: const Text(
                        'Lihat semua',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1D9E75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Horizontal scroll cards
            SliverToBoxAdapter(
              child: SizedBox(
                height: 240,
                child: baruDirilis.isEmpty
                    ? const Center(child: Text('Tidak ada buku.'))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        itemCount: baruDirilis.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (ctx, i) => _HorizontalBookCard(
                          ebook: baruDirilis[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EbookDetailScreen(
                                  slug: baruDirilis[i].slug),
                            ),
                          ),
                        ),
                      ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ─── Trending Section ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    const Text(
                      'Trending Hari Ini',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('🔥', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),

            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final list = trending.isEmpty ? ebooks : trending;
                  if (i >= list.length) return null;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _TrendingBookCard(
                      ebook: list[i],
                      rank: i + 1,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EbookDetailScreen(slug: list[i].slug),
                        ),
                      ),
                    ),
                  );
                },
                childCount:
                    (trending.isEmpty ? ebooks : trending).length,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ],
      ),
    );
  }
}

// ─── Horizontal Book Card ────────────────────────────────────────────
class _HorizontalBookCard extends StatelessWidget {
  final EbookModel ebook;
  final VoidCallback onTap;

  const _HorizontalBookCard({required this.ebook, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ebook.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: ebook.coverUrl!,
                      height: 160,
                      width: 120,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _CoverPlaceholder(
                        height: 160,
                        width: 120,
                      ),
                      errorWidget: (_, __, ___) => _CoverPlaceholder(
                        height: 160,
                        width: 120,
                      ),
                    )
                  : _CoverPlaceholder(height: 160, width: 120),
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              ebook.title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Author
            Text(
              ebook.author ?? '',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF888780),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Rating + format
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    size: 12, color: Color(0xFFFFC107)),
                const SizedBox(width: 2),
                const Text(
                  '4.8',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5F1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ebook.price == 0
                        ? 'FREE'
                        : ebook.totalPages > 0
                            ? 'PDF'
                            : 'EPUB',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D9E75),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            // Price
            Text(
              ebook.price == 0
                  ? 'Gratis'
                  : 'Rp ${_formatPrice(ebook.price)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ebook.price == 0
                    ? const Color(0xFF1D9E75)
                    : const Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Trending Book Card ──────────────────────────────────────────────
class _TrendingBookCard extends StatelessWidget {
  final EbookModel ebook;
  final int rank;
  final VoidCallback onTap;

  const _TrendingBookCard({
    required this.ebook,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ebook.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: ebook.coverUrl!,
                      height: 70,
                      width: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          _CoverPlaceholder(height: 70, width: 52),
                      errorWidget: (_, __, ___) =>
                          _CoverPlaceholder(height: 70, width: 52),
                    )
                  : _CoverPlaceholder(height: 70, width: 52),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ebook.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ebook.author ?? ebook.category?.name ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888780),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 13, color: Color(0xFFFFC107)),
                      const SizedBox(width: 2),
                      const Text(
                        '4.8',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.download_outlined,
                          size: 13, color: Color(0xFF888780)),
                      const SizedBox(width: 2),
                      const Text(
                        '12k',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888780),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5F1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PDF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D9E75),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ebook.price == 0
                        ? 'Gratis'
                        : 'Rp ${_formatPrice(ebook.price)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Beli button
            if (ebook.price > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Beli',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D9E75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Ambil',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Category Chip ──────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1D9E75)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? Colors.white
                : Colors.white.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}

// ─── Shared Widgets ─────────────────────────────────────────────────
class _CoverPlaceholder extends StatelessWidget {
  final double height;
  final double width;

  const _CoverPlaceholder({required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      color: const Color(0xFFE1F5EE),
      child: const Center(
        child: Icon(Icons.menu_book_rounded,
            size: 28, color: Color(0xFF1D9E75)),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: Color(0xFFD1D5DB)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D9E75),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EbookCard (kept for backward compat) ──────────────────────────
class EbookCard extends StatelessWidget {
  final EbookModel ebook;
  final VoidCallback onTap;

  const EbookCard({super.key, required this.ebook, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E6DF), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: ebook.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: ebook.coverUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          _CoverPlaceholder(height: 160, width: double.infinity),
                      errorWidget: (_, __, ___) =>
                          _CoverPlaceholder(height: 160, width: double.infinity),
                    )
                  : _CoverPlaceholder(height: 160, width: double.infinity),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ebook.category != null)
                    Text(
                      ebook.category!.name,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF1D9E75),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    ebook.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ebook.price == 0
                        ? 'Gratis'
                        : 'Rp ${_formatPrice(ebook.price)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ebook.price == 0
                          ? const Color(0xFF1D9E75)
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatPrice(double v) =>
    v.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
