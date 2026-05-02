import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/wishlist_provider.dart';
import '../../catalog/screens/ebook_detail_screen.dart';
import '../../catalog/models/wishlist_model.dart';

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(wishlistProvider.notifier).loadWishlist(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wishlistProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Wishlist Saya',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.items.isEmpty
              ? _EmptyWishlist()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    return _WishlistCard(item: state.items[index]);
                  },
                ),
    );
  }
}

class _EmptyWishlist extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE1F5EE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.bookmark_border_rounded,
              size: 40,
              color: Color(0xFF1D9E75),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Wishlist masih kosong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Simpan buku yang ingin kamu beli nanti',
            style: TextStyle(fontSize: 14, color: Color(0xFF888780)),
          ),
        ],
      ),
    );
  }
}

class _WishlistCard extends ConsumerWidget {
  final WishlistModel item;
  const _WishlistCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ebook = item.ebook;
    if (ebook == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EbookDetailScreen(slug: ebook.slug),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ebook.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: ebook.coverUrl!,
                        width: 64,
                        height: 88,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 64,
                        height: 88,
                        color: const Color(0xFFE1F5EE),
                        child: const Icon(Icons.menu_book_rounded,
                            color: Color(0xFF1D9E75)),
                      ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ebook.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1F5EE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          ebook.category!.name,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF0F6E56)),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      ebook.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    if (ebook.author != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        ebook.author!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF888780)),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Rp ${ebook.price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D9E75),
                      ),
                    ),
                  ],
                ),
              ),
              // Remove button
              IconButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Hapus dari Wishlist'),
                      content: Text(
                          'Hapus "${ebook.title}" dari wishlist?'),
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
                          child: const Text('Hapus'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref
                        .read(wishlistProvider.notifier)
                        .removeFromWishlist(ebook.id);
                  }
                },
                icon: const Icon(Icons.bookmark_remove_outlined,
                    color: Colors.redAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
