import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/catalog_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/ebook_model.dart';
import 'ebook_detail_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../library/screens/library_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final auth = ref.watch(authProvider);

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
            IconButton(
              icon: const Icon(Icons.menu_book_rounded, color: Color(0xFF1D9E75)),
              tooltip: 'Library Saya',
              onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LibraryScreen())),
            ),
            PopupMenuButton(
              icon: CircleAvatar(
                radius: 16,
                backgroundImage: auth.user?.avatar != null
                    ? NetworkImage(auth.user!.avatar!)
                    : null,
                backgroundColor: const Color(0xFF1D9E75),
                child: auth.user?.avatar == null
                    ? Text(
                        auth.user!.name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      )
                    : null,
              ),
              itemBuilder: (_) => [
                PopupMenuItem(
                  child: const Text('Logout'),
                  onTap: () => ref.read(authProvider.notifier).logout(),
                ),
              ],
            ),
          ] else
            TextButton(
              onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: const Text(
                'Masuk',
                style: TextStyle(
                  color: Color(0xFF1D9E75),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari judul buku, mata kuliah...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(catalogProvider.notifier).fetchEbooks();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF1EFE8),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (val) =>
                  ref.read(catalogProvider.notifier).fetchEbooks(search: val),
              onChanged: (val) => setState(() {}),
            ),
          ),

          // Filter kategori
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
                      onTap: () => ref.read(catalogProvider.notifier)
                          .fetchEbooks(),
                    );
                  }
                  final cat = catalog.categories[i - 1];
                  return _CategoryChip(
                    label: cat.name,
                    selected: catalog.selectedCategory == cat.slug,
                    onTap: () => ref.read(catalogProvider.notifier)
                        .fetchEbooks(category: cat.slug),
                  );
                },
              ),
            ),

          const SizedBox(height: 8),

          // Grid buku
          Expanded(
            child: catalog.isLoading
                ? const Center(child: CircularProgressIndicator())
                : catalog.errorMessage != null
                    ? Center(child: Text(catalog.errorMessage!))
                    : catalog.ebooks.isEmpty
                        ? const Center(child: Text('Belum ada buku tersedia.'))
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.62,
                            ),
                            itemCount: catalog.ebooks.length,
                            itemBuilder: (ctx, i) => EbookCard(
                              ebook: catalog.ebooks[i],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EbookDetailScreen(
                                    slug: catalog.ebooks[i].slug,
                                  ),
                                ),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

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

// Shared widget — taruh di lib/shared/widgets/ebook_card.dart
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
            // Cover
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
                  Text(
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
        child: Icon(
          Icons.menu_book_rounded,
          size: 40,
          color: Color(0xFF1D9E75),
        ),
      ),
    );
  }
}