// lib/features/library/screens/library_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../catalog/models/ebook_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import 'reader_screen.dart';
import '../../quiz/screens/quiz_screen.dart';

enum LibraryTab { semua, selesai }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  List<EbookModel> _library = [];
  bool _loading = false;
  String? _error;
  LibraryTab _activeTab = LibraryTab.semua;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeTab = LibraryTab.values[_tabController.index];
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(authProvider).isLoggedIn) {
        _fetchLibrary();
      }
    });

    // Dengarkan perubahan auth — fetch otomatis saat user login
    ref.listenManual(authProvider, (previous, next) {
      final wasLoggedIn = previous?.isLoggedIn ?? false;
      final isNowLoggedIn = next.isLoggedIn;
      if (!wasLoggedIn && isNowLoggedIn && mounted) {
        _fetchLibrary();
      }
      // Reset library saat logout
      if (wasLoggedIn && !isNowLoggedIn && mounted) {
        setState(() {
          _library = [];
          _loading = false;
          _error = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLibrary() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService.dio.get(ApiConstants.library);
      final raw = res.data;

      // Laravel paginate() → Map dengan key "data" berisi List
      // Fallback: jika backend return List langsung
      List<dynamic> list;
      if (raw is Map && raw['data'] is List) {
        list = raw['data'] as List<dynamic>;
      } else if (raw is List) {
        list = raw;
      } else {
        list = [];
      }

      final books = list
          .whereType<Map<String, dynamic>>()
          .map((e) => EbookModel.fromJson(e))
          .toList();

      if (mounted) {
        setState(() {
          _library = books;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('LibraryScreen _fetchLibrary error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Gagal memuat koleksi. Tarik untuk muat ulang.';
        });
      }
    }
  }

  List<EbookModel> get _filteredLibrary {
    switch (_activeTab) {
      case LibraryTab.selesai:
        return _library.where((b) => b.isFinished).toList();
      case LibraryTab.semua:
      default:
        return _library;
    }
  }

  int get _selesaiCount => _library.where((b) => b.isFinished).length;

  Future<void> _openBook(EbookModel ebook) async {
    try {
      final res = await ApiService.dio
          .get('${ApiConstants.library}/${ebook.id}/read');
      final readUrl = res.data['read_url'];
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReaderScreen(title: ebook.title, pdfUrl: readUrl, ebookId: ebook.id),
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

  Future<void> _openQuiz(EbookModel ebook) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          ebookId: ebook.id,
          bookTitle: ebook.title,
        ),
      ),
    );
  }

  Future<void> _markFinished(EbookModel ebook) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Tandai Selesai?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          '"${ebook.title}" akan dipindahkan ke tab Selesai dan tidak bisa diubah kembali.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF555555)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D9E75),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.dio.post('${ApiConstants.library}/${ebook.id}/finish');

      setState(() {
        final idx = _library.indexWhere((b) => b.id == ebook.id);
        if (idx != -1) {
          _library[idx] = EbookModel(
            id: ebook.id,
            title: ebook.title,
            slug: ebook.slug,
            description: ebook.description,
            author: ebook.author,
            price: ebook.price,
            coverUrl: ebook.coverUrl,
            fileUrl: ebook.fileUrl,
            djkiCertNo: ebook.djkiCertNo,
            totalPages: ebook.totalPages,
            status: ebook.status,
            categoryId: ebook.categoryId,
            category: ebook.category,
            isFinished: true,
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${ebook.title}" ditandai selesai.'),
            backgroundColor: const Color(0xFF1D9E75),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Gagal menandai buku sebagai selesai.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // ── Guest State ──────────────────────────────────────────────
    if (!auth.isLoggedIn) {
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
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF0F4F2),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Color(0xFF1D9E75),
                      size: 46,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Koleksi Kamu Kosong',
                    style: TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Masuk untuk melihat buku yang\nsudah kamu beli dan baca.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        );
                        if (mounted && ref.read(authProvider).isLoggedIn) {
                          _fetchLibrary();
                        }
                      },
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

    // ── Logged In State ──────────────────────────────────────────
    final books = _filteredLibrary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
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
                        Text(
                          'Koleksi Saya',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.87),
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _StatBox(
                              value: '${_library.length}',
                              label: 'Total Buku',
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
                  TabBar(
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
                      Tab(text: 'Selesai'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Book List
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF1D9E75)))
                : _error != null
                    ? _buildError()
                    : books.isEmpty
                        ? _EmptyState(tab: _activeTab)
                        : RefreshIndicator(
                            onRefresh: _fetchLibrary,
                            color: const Color(0xFF1D9E75),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              itemCount: books.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (ctx, i) {
                                final ebook = books[i];
                                return _LibraryBookCard(
                                  ebook: ebook,
                                  onRead: () => _openBook(ebook),
                                  onMarkFinished: ebook.isFinished
                                      ? null
                                      : () => _markFinished(ebook),
                                  onQuiz: () => _openQuiz(ebook),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchLibrary,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A2E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Box ──────────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String value;
  final String label;

  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.withOpacity(0.7),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Library Book Card ─────────────────────────────────────────────────
class _LibraryBookCard extends StatelessWidget {
  final EbookModel ebook;
  final VoidCallback onRead;
  final VoidCallback? onMarkFinished;
  final VoidCallback onQuiz;

  const _LibraryBookCard({
    required this.ebook,
    required this.onRead,
    required this.onMarkFinished,
    required this.onQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final isFinished = ebook.isFinished;

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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ebook.author ?? ebook.category?.name ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888780),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (isFinished)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D9E75).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 12, color: Color(0xFF1D9E75)),
                              SizedBox(width: 4),
                              Text(
                                'Selesai',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D9E75),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
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
                Expanded(
                  child: TextButton.icon(
                    onPressed: onRead,
                    icon: const Icon(Icons.menu_book_outlined, size: 16),
                    label: const Text('Baca',
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1A1A2E),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: const Color(0xFF000000).withOpacity(0.06),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onQuiz,
                    icon: const Icon(Icons.quiz_outlined, size: 16),
                    label: const Text('Quiz',
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1D9E75),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                  ),
                ),
                if (!isFinished) ...[
                  Container(
                    width: 1,
                    height: 32,
                    color: const Color(0xFF000000).withOpacity(0.06),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onMarkFinished,
                      icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16),
                      label: const Text('Selesai',
                          style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1D9E75),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero),
                      ),
                    ),
                  ),
                ],
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
    final message = tab == LibraryTab.selesai
        ? 'Belum ada buku yang selesai dibaca.'
        : 'Belum ada buku di koleksimu.\nBeli buku sekarang!';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tab == LibraryTab.selesai
                ? Icons.check_circle_outline_rounded
                : Icons.menu_book_outlined,
            size: 64,
            color: const Color(0xFFD3D1C7),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF888780), fontSize: 14),
          ),
        ],
      ),
    );
  }
}