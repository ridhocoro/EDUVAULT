// lib/features/catalog/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/catalog_provider.dart';
import '../models/ebook_model.dart';
import 'ebook_detail_screen.dart';
import 'all_books_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final ebooks = catalog.filteredEbooks;

    final baruDirilis = ebooks.take(6).toList();
    final trending = ebooks.skip(6).take(10).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () => ref.read(catalogProvider.notifier).fetchEbooks(),
        color: const Color(0xFF1D9E75),
        child: CustomScrollView(
          slivers: [
          // ─── Header dengan Background Putih ───────────────────
          SliverAppBar(
            expandedHeight: 40,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 44, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search bar
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          color: Color(0xFF1A1A2E),
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Cari buku, penulis, atau kategori...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                          suffixIcon: _isSearching
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey.shade500,
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
            title: null,
          ),

          // ─── Category Chips ────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  if (catalog.categories.isNotEmpty)
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            // Baru Dirilis
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
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
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AllBooksScreen(),
                        ),
                      ),
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

            SliverToBoxAdapter(
              child: SizedBox(
                height: 245,
                child: baruDirilis.isEmpty
                    ? const Center(child: Text('Tidak ada buku.'))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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

            // Trending
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Text(
                      'Trending Hari Ini',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('🔥', style: TextStyle(fontSize: 16)),
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
                childCount: (trending.isEmpty ? ebooks : trending).length,
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ],
        ),
      )
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
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
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
            const SizedBox(height: 4),
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
            // Rank
            SizedBox(
              width: 32,
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D9E75),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ebook.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: ebook.coverUrl!,
                      height: 70,
                      width: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _CoverPlaceholder(height: 70, width: 52),
                      errorWidget: (_, __, ___) => _CoverPlaceholder(height: 70, width: 52),
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
          ],
        ),
      ),
    );
  }
}

// ─── Cover Placeholder ──────────────────────────────────────────────
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
        child: Icon(Icons.menu_book_rounded, size: 28, color: Color(0xFF1D9E75)),
      ),
    );
  }
}

// ─── Error View ─────────────────────────────────────────────────────
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
            const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFD1D5DB)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D9E75),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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

// ─── Helper Functions ───────────────────────────────────────────────
String _formatPrice(double v) {
  return v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
}