import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../catalog/models/ebook_model.dart';
import 'reader_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  List<EbookModel> _library = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchLibrary();
  }

  Future<void> _fetchLibrary() async {
    try {
      final res = await ApiService.dio.get(ApiConstants.library);
      setState(() {
        _library = (res.data['data'] as List)
            .map((e) => EbookModel.fromJson(e))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _openBook(EbookModel ebook) async {
    try {
      final res = await ApiService.dio
          .get('${ApiConstants.library}/${ebook.id}/read');
      final readUrl = res.data['read_url'];
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ReaderScreen(title: ebook.title, pdfUrl: readUrl),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka buku.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF1A1A2E)),
        title: const Text('Library Saya',
            style: TextStyle(color: Color(0xFF1A1A2E))),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _library.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 64, color: Color(0xFFD3D1C7)),
                      SizedBox(height: 16),
                      Text('Belum ada buku di library kamu.',
                          style: TextStyle(color: Color(0xFF888780))),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: _library.length,
                  itemBuilder: (_, i) {
                    final ebook = _library[i];
                    return GestureDetector(
                      onTap: () => _openBook(ebook),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFE8E6DF), width: 0.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12)),
                              child: ebook.coverUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: ebook.coverUrl!,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      height: 150,
                                      color: const Color(0xFFE1F5EE),
                                      child: const Center(
                                        child: Icon(Icons.menu_book_rounded,
                                            size: 40,
                                            color: Color(0xFF1D9E75)),
                                      ),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ebook.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A1A2E))),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    const Icon(Icons.play_circle_filled,
                                        size: 14, color: Color(0xFF1D9E75)),
                                    const SizedBox(width: 4),
                                    const Text('Baca',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF1D9E75),
                                            fontWeight: FontWeight.w500)),
                                  ]),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}