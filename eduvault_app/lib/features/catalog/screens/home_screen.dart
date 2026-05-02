// lib/features/catalog/screens/home_screen.dart
// REPLACE file lama dengan file ini

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/catalog_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/profile_screen.dart';
import '../models/ebook_model.dart';
import 'ebook_detail_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../library/screens/library_screen.dart';
import '../../admin/screens/admin_dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showPriceFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _PriceFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final auth = ref.watch(authProvider);

    // Gunakan filteredEbooks (sudah di-sort/filter client-side)
    final ebooks = catalog.filteredEbooks;
    final hasFilter = catalog.priceSort != PriceSort.none ||
        catalog.minPrice != null ||
        catalog.maxPrice != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'EduVault',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
            fontSize: 20,
          ),
        ),
        actions: [
          if (auth.isLoggedIn) ...[
            // Tombol Admin Panel — hanya tampil untuk role admin
            if (auth.user?.role == 'admin')
              IconButton(
                icon: const Icon(Icons.admin_panel_settings_rounded,
                    color: Color(0xFF1D9E75)),
                tooltip: 'Admin Panel',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminDashboardScreen()),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.menu_book_rounded, color: Color(0xFF1D9E75)),
              tooltip: 'Library Saya',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LibraryScreen()),
              ),
            ),
            // Avatar → buka ProfileScreen
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: auth.user?.avatar != null
                      ? NetworkImage(auth.user!.avatar!)
                      : null,
                  backgroundColor: const Color(0xFF1D9E75),
                  child: auth.user?.avatar == null
                      ? Text(
                          auth.user!.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ] else
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: const Text(
                'Masuk',
                style: TextStyle(
                  color: Color(0xFF1D9E75),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ─── Search + Filter bar ──────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                // Search Field
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari judul buku, mata kuliah...',
                      hintStyle: const TextStyle(fontSize: 14),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(catalogProvider.notifier)
                                    .fetchEbooks();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1EFE8),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (val) => ref
                        .read(catalogProvider.notifier)
                        .fetchEbooks(search: val),
                    onChanged: (val) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                // Filter Price Button
                GestureDetector(
                  onTap: _showPriceFilterSheet,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: hasFilter
                          ? const Color(0xFF1D9E75)
                          : const Color(0xFFF1EFE8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: hasFilter ? Colors.white : const Color(0xFF5F5E5A),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Kategori chips ───────────────────────────────────
          if (catalog.categories.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: catalog.categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return _CategoryChip(
                      label: 'Semua',
                      selected: catalog.selectedCategory == null,
                      onTap: () =>
                          ref.read(catalogProvider.notifier).fetchEbooks(),
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

          // ─── Active filter badge ──────────────────────────────
          if (hasFilter)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _filterLabel(catalog),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1D9E75),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        ref.read(catalogProvider.notifier).resetFilters(),
                    child: const Text(
                      'Reset filter',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // ─── Grid buku ────────────────────────────────────────
          Expanded(
            child: catalog.isLoading
                ? const Center(child: CircularProgressIndicator())
                : catalog.errorMessage != null
                    ? Center(child: Text(catalog.errorMessage!))
                    : ebooks.isEmpty
                        ? const Center(
                            child: Text('Tidak ada buku yang sesuai filter.'),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.62,
                            ),
                            itemCount: ebooks.length,
                            itemBuilder: (ctx, i) => EbookCard(
                              ebook: ebooks[i],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EbookDetailScreen(slug: ebooks[i].slug),
                                ),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(CatalogState catalog) {
    final parts = <String>[];
    if (catalog.priceSort == PriceSort.free) {
      parts.add('Gratis');
    } else if (catalog.priceSort == PriceSort.asc) {
      parts.add('Harga: Murah → Mahal');
    } else if (catalog.priceSort == PriceSort.desc) {
      parts.add('Harga: Mahal → Murah');
    }
    if (catalog.minPrice != null) {
      parts.add('Min: Rp ${_fmt(catalog.minPrice!)}');
    }
    if (catalog.maxPrice != null) {
      parts.add('Max: Rp ${_fmt(catalog.maxPrice!)}');
    }
    return 'Filter aktif: ${parts.join(' · ')}';
  }

  String _fmt(double v) =>
      v.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]}.',
          );
}

// ──────────────────────────────────────────────────────────────────
// Price Filter Bottom Sheet
// ──────────────────────────────────────────────────────────────────
class _PriceFilterSheet extends ConsumerStatefulWidget {
  const _PriceFilterSheet();

  @override
  ConsumerState<_PriceFilterSheet> createState() => _PriceFilterSheetState();
}

class _PriceFilterSheetState extends ConsumerState<_PriceFilterSheet> {
  late PriceSort _selectedSort;
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = ref.read(catalogProvider);
    _selectedSort = state.priceSort;
    if (state.minPrice != null) {
      _minCtrl.text = state.minPrice!.toStringAsFixed(0);
    }
    if (state.maxPrice != null) {
      _maxCtrl.text = state.maxPrice!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final notifier = ref.read(catalogProvider.notifier);
    notifier.setPriceSort(_selectedSort);
    notifier.setPriceRange(
      min: _minCtrl.text.isEmpty ? null : double.tryParse(_minCtrl.text),
      max: _maxCtrl.text.isEmpty ? null : double.tryParse(_maxCtrl.text),
    );
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _selectedSort = PriceSort.none;
      _minCtrl.clear();
      _maxCtrl.clear();
    });
    ref.read(catalogProvider.notifier).resetFilters();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text(
              'Filter & Urutkan Harga',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),

          // Sort options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              children: [
                _SortChip(
                  label: 'Semua',
                  icon: Icons.apps,
                  selected: _selectedSort == PriceSort.none,
                  onTap: () => setState(() => _selectedSort = PriceSort.none),
                ),
                _SortChip(
                  label: 'Termurah',
                  icon: Icons.arrow_upward,
                  selected: _selectedSort == PriceSort.asc,
                  onTap: () => setState(() => _selectedSort = PriceSort.asc),
                ),
                _SortChip(
                  label: 'Termahal',
                  icon: Icons.arrow_downward,
                  selected: _selectedSort == PriceSort.desc,
                  onTap: () => setState(() => _selectedSort = PriceSort.desc),
                ),
                _SortChip(
                  label: 'Gratis',
                  icon: Icons.card_giftcard,
                  selected: _selectedSort == PriceSort.free,
                  onTap: () => setState(() => _selectedSort = PriceSort.free),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Range harga
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Rentang Harga (opsional)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _PriceField(
                    controller: _minCtrl,
                    label: 'Harga min',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PriceField(
                    controller: _maxCtrl,
                    label: 'Harga max',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Color(0xFFD3D1C7)),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D9E75),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Terapkan Filter',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
}

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1D9E75) : const Color(0xFFF1EFE8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : const Color(0xFF5F5E5A),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : const Color(0xFF5F5E5A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _PriceField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD3D1C7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD3D1C7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1D9E75), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Category Chip & Ebook Card (sama seperti sebelumnya)
// ──────────────────────────────────────────────────────────────────
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1D9E75) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF1D9E75) : const Color(0xFFD3D1C7),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : const Color(0xFF5F5E5A),
          ),
        ),
      ),
    );
  }
}

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
                      placeholder: (_, __) => Container(
                        height: 160,
                        color: const Color(0xFFF1EFE8),
                      ),
                      errorWidget: (_, __, ___) => _PlaceholderCover(),
                    )
                  : _PlaceholderCover(),
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
                  ebook.price == 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE1F5EE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'GRATIS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D9E75),
                            ),
                          ),
                        )
                      : Text(
                          'Rp ${ebook.price.toStringAsFixed(0).replaceAllMapped(
                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                (m) => '${m[1]}.',
                              )}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D9E75),
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

class _PlaceholderCover extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      color: const Color(0xFFE1F5EE),
      child: const Center(
        child: Icon(Icons.menu_book_rounded, size: 40, color: Color(0xFF1D9E75)),
      ),
    );
  }
}
