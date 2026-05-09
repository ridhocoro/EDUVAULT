// lib/features/library/screens/library_screen.dart
// REDESIGN sesuai Figma — Stats header, tab filter, progress cards

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../catalog/models/ebook_model.dart';
import 'reader_screen.dart';

enum LibraryTab { semua, sedangDibaca, selesai }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  List<EbookModel> _library = [];
  bool _loading = true;
  LibraryTab _activeTab = LibraryTab.semua;
  late TabController _tabController;

  // Simulated progress data per book
  final Map<int, double> _progressMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _activeTab = LibraryTab.values[_tabController.index];
      });
    });
    _fetchLibrary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLibrary() async {
    try {
      final res = await ApiService.dio.get(ApiConstants.library);
      final books = (res.data['data'] as List)
          .map((e) => EbookModel.fromJson(e))
          .toList();

      // Simulate progress for demo
      for (int i = 0; i < books.length; i++) {
        if (i == books.length - 1) {
          _progressMap[books[i].id] = 1.0; // last book = 100%
        } else {
          _progressMap[books[i].id] = (i % 3 == 0) ? 0.65 : 0.34;
        }
      }

      setState(() {
        _library = books;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<EbookModel> get _filteredLibrary {
    switch (_activeTab) {
      case LibraryTab.sedangDibaca:
        return _library.where((b) {
          final p = _progressMap[b.id] ?? 0;
          return p > 0 && p < 1.0;
        }).toList();
      case LibraryTab.selesai:
        return _library
            .where((b) => (_progressMap[b.id] ?? 0) >= 1.0)
            .toList();
      case LibraryTab.semua:
      default:
        return _library;
    }
  }

  int get _sedangDibacaCount =>
      _library.where((b) {
        final p = _progressMap[b.id] ?? 0;
        return p > 0 && p < 1.0;
      }).length;

  int get _selesaiCount =>
      _library.where((b) => (_progressMap[b.id] ?? 0) >= 1.0).length;

  Future<void> _openBook(EbookModel ebook) async {
    try {
      final res = await ApiService.dio
          .get('${ApiConstants.library}/${ebook.id}/read');
      final readUrl = res.data['read_url'];
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ReaderScreen(title: ebook.title, pdfUrl: readUrl),
          ),
        );
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
    final books = _filteredLibrary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ─── Dark Header ───────────────────────────────────────
          Container(
            color: const Color(0xFF0F1923),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Koleksi Saya',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Stats row
                        Row(
                          children: [
                            _StatBox(
                              value: '${_library.length}',
                              label: 'Total Buku',
                            ),
                            const SizedBox(width: 1),
                            _StatBox(
                              value: '$_sedangDibacaCount',
                              label: 'Sedang Dibaca',
                            ),
                            const SizedBox(width: 1),
                            _StatBox(
                              value: '$_selesaiCount',
                              label: 'Selesai',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ─── Tab Bar ──────────────────────────────────
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF1A1A2E),
                      unselectedLabelColor: const Color(0xFF888780),
                      indicatorColor: const Color(0xFF1A1A2E),
                      indicatorWeight: 2.5,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                      ),
                      tabs: const [
                        Tab(text: 'Semua'),
                        Tab(text: 'Sedang Dibaca'),
                        Tab(text: 'Selesai'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Book List ────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : books.isEmpty
                    ? _EmptyState(tab: _activeTab)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        itemCount: books.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final ebook = books[i];
                          final progress = _progressMap[ebook.id] ?? 0;
                          return _LibraryBookCard(
                            ebook: ebook,
                            progress: progress,
                            onRead: () => _openBook(ebook),
                            onDownload: () {},
                            onDelete: () {
                              setState(() {
                                _library.remove(ebook);
                              });
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Box ──────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String value;
  final String label;

  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
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
      ),
    );
  }
}

// ─── Library Book Card ─────────────────────────────────────────────
class _LibraryBookCard extends StatelessWidget {
  final EbookModel ebook;
  final double progress;
  final VoidCallback onRead;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _LibraryBookCard({
    required this.ebook,
    required this.progress,
    required this.onRead,
    required this.onDownload,
    required this.onDelete,
  });

  String _timeAgo() {
    // Simplified — in real app, use actual last_read timestamp
    return '2 jam lalu';
  }

  String _formatLabel() {
    return ebook.totalPages > 0 ? 'PDF' : 'EPUB';
  }

  @override
  Widget build(BuildContext context) {
    final isFinished = progress >= 1.0;
    final progressPercent = (progress * 100).toInt();

    return Container(
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ebook.coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: ebook.coverUrl!,
                          height: 80,
                          width: 60,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              _Cover(height: 80, width: 60),
                          errorWidget: (_, __, ___) =>
                              _Cover(height: 80, width: 60),
                        )
                      : _Cover(height: 80, width: 60),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
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
                          const Icon(Icons.access_time,
                              size: 12, color: Color(0xFFAAAAAA)),
                          const SizedBox(width: 3),
                          Text(
                            _timeAgo(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFAAAAAA),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('•',
                              style: TextStyle(color: Color(0xFFCCCCCC))),
                          const SizedBox(width: 8),
                          Text(
                            _formatLabel(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFAAAAAA),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Progress bar
                      Row(
                        children: [
                          const Text(
                            'Progress',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFAAAAAA),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$progressPercent%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFEEEEEE),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isFinished
                                ? const Color(0xFF1D9E75)
                                : const Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Action buttons ──────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: const Color(0xFF000000).withOpacity(0.06),
                ),
              ),
            ),
            child: Row(
              children: [
                // Read / Continue
                Expanded(
                  child: TextButton.icon(
                    onPressed: onRead,
                    icon: const Icon(Icons.menu_book_outlined, size: 16),
                    label: Text(
                      isFinished ? 'Baca Lagi' : 'Lanjutkan',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1A1A2E),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: const Color(0xFF000000).withOpacity(0.06),
                ),
                // Download
                Expanded(
                  child: TextButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text(
                      'Download',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1A1A2E),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: const Color(0xFF000000).withOpacity(0.06),
                ),
                // Delete
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Color(0xFFE53935),
                  ),
                  padding: const EdgeInsets.all(10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final double height;
  final double width;

  const _Cover({required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      color: const Color(0xFFE1F5EE),
      child: const Center(
        child: Icon(Icons.menu_book_rounded,
            size: 22, color: Color(0xFF1D9E75)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final LibraryTab tab;

  const _EmptyState({required this.tab});

  @override
  Widget build(BuildContext context) {
    final messages = {
      LibraryTab.semua: 'Belum ada buku di koleksimu.\nBeli buku sekarang!',
      LibraryTab.sedangDibaca: 'Tidak ada buku yang sedang dibaca.',
      LibraryTab.selesai: 'Belum ada buku yang selesai dibaca.',
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_outlined,
              size: 64, color: Color(0xFFD3D1C7)),
          const SizedBox(height: 16),
          Text(
            messages[tab] ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF888780),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
