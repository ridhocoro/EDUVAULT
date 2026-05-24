// lib/features/catalog/screens/all_books_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/catalog_provider.dart';
import '../models/ebook_model.dart';
import 'ebook_detail_screen.dart';

class AllBooksScreen extends ConsumerWidget {
  const AllBooksScreen({super.key});

  String _formatPrice(num price) {
    return price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final ebooks = catalog.filteredEbooks;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1A1A2E), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Semua Buku',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: catalog.isLoading
          ? const Center(child: CircularProgressIndicator())
          : catalog.errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(catalog.errorMessage!,
                          style: const TextStyle(color: Color(0xFF888888))),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () =>
                            ref.read(catalogProvider.notifier).fetchEbooks(),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                )
              : ebooks.isEmpty
                  ? const Center(
                      child: Text('Tidak ada buku.',
                          style: TextStyle(color: Color(0xFF888888))),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.58,
                      ),
                      itemCount: ebooks.length,
                      itemBuilder: (ctx, i) {
                        final ebook = ebooks[i];
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EbookDetailScreen(slug: ebook.slug),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ebook.coverUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: ebook.coverUrl!,
                                        height: 175,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) =>
                                            _CoverPlaceholder(
                                                height: 175,
                                                width: double.infinity),
                                        errorWidget: (_, __, ___) =>
                                            _CoverPlaceholder(
                                                height: 175,
                                                width: double.infinity),
                                      )
                                    : _CoverPlaceholder(
                                        height: 175, width: double.infinity),
                              ),
                              const SizedBox(height: 8),
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
                              const SizedBox(height: 3),
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: ebook.price == 0
                                      ? const Color(0xFF1D9E75)
                                      : const Color(0xFF1A1A2E),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  final double height;
  final double width;

  const _CoverPlaceholder({required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(
          Icons.menu_book_rounded,
          color: Color(0xFF1D9E75),
          size: 40,
        ),
      ),
    );
  }
}