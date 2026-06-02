// lib/features/library/screens/library_screen.dart — REPLACE file lama
// Perubahan:
//  - 3 tab: Semua | Beli Satuan | Langganan
//  - Search bar
//  - Badge "Langganan" di kartu buku subscription
//  - Lock state untuk buku subscription yang expired

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../catalog/models/ebook_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../subscription/screens/subscription_screen.dart';
import 'reader_screen.dart';
import '../../quiz/screens/quiz_screen.dart';

enum LibraryTab { semua, beliSatuan, langganan }

extension LibraryTabSource on LibraryTab {
  String get apiSource {
    switch (this) {
      case LibraryTab.beliSatuan:
        return 'purchase';
      case LibraryTab.langganan:
        return 'subscription';
      case LibraryTab.semua:
      default:
        return 'all';
    }
  }
}

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

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeTab = LibraryTab.values[_tabController.index];
          _library = [];
        });
        _fetchLibrary();
      }
    });

    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q != _searchQuery) {
        _searchQuery = q;
        _fetchLibrary();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(authProvider).isLoggedIn) {
        _fetchLibrary();
      }
    });

    ref.listenManual(authProvider, (previous, next) {
      final wasLoggedIn = previous?.isLoggedIn ?? false;
      if (!wasLoggedIn && next.isLoggedIn && mounted) _fetchLibrary();
      if (wasLoggedIn && !next.isLoggedIn && mounted) {
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLibrary() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService.dio.get(
        ApiConstants.library,
        queryParameters: {
          'source': _activeTab.apiSource,
          if (_searchQuery.isNotEmpty) 'search': _searchQuery,
        },
      );
      final raw = res.data;
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

      if (mounted) setState(() { _library = books; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = 'Gagal memuat koleksi.'; });
      }
    }
  }

  int get _selesaiCount  => _library.where((b) => b.isFinished).length;
  int get _subCount      => _library.where((b) => b.isFromSubscription).length;

  Future<void> _openBook(EbookModel ebook) async {
    // Buku subscription expired → tampilkan dialog
    if (ebook.subscriptionExpired) {
      _showSubExpiredDialog();
      return;
    }

    try {
      final res = await ApiService.dio.get(ApiConstants.libraryRead(ebook.id));
      // Backend bisa kembalikan 403 jika subscription expired (double check)
      final readUrl = res.data['read_url'];
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ReaderScreen(title: ebook.title, pdfUrl: readUrl, ebookId: ebook.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka buku.')),
        );
      }
    }
  }

  void _showSubExpiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Color(0xFFFF8C00), size: 20),
            SizedBox(width: 8),
            Text('Langganan Berakhir',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Lanjutkan langganan untuk tetap bisa membuka semua fitur buku ini.',
          style: TextStyle(fontSize: 14, color: Color(0xFF555555), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nanti', style: TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D9E75),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Lihat Paket'),
          ),
        ],
      ),
    );
  }

  Future<void> _openQuiz(EbookModel ebook) async {
    if (ebook.subscriptionExpired) {
      _showSubExpiredDialog();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(ebookId: ebook.id, bookTitle: ebook.title),
      ),
    );
  }

  Future<void> _markFinished(EbookModel ebook) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tandai Selesai?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
          '"${ebook.title}" akan dipindahkan ke tab Selesai.',
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
            id: ebook.id, title: ebook.title, slug: ebook.slug,
            description: ebook.description, author: ebook.author,
            price: ebook.price, coverUrl: ebook.coverUrl, fileUrl: ebook.fileUrl,
            djkiCertNo: ebook.djkiCertNo, totalPages: ebook.totalPages,
            status: ebook.status, categoryId: ebook.categoryId,
            category: ebook.category, isFinished: true,
            sourceType: ebook.sourceType, libraryExpires: ebook.libraryExpires,
            subscriptionExpired: ebook.subscriptionExpired,
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
          const SnackBar(content: Text('Gagal menandai buku sebagai selesai.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    if (!auth.isLoggedIn) return _buildGuest();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                        const SizedBox(height: 12),
                        // Stats row
                        Row(
                          children: [
                            _StatBox(value: '${_library.length}', label: 'Total'),
                            const SizedBox(width: 1),
                            _StatBox(value: '$_selesaiCount', label: 'Selesai'),
                            const SizedBox(width: 1),
                            _StatBox(value: '$_subCount', label: 'Langganan'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Search bar
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Cari buku di koleksimu...',
                            hintStyle: const TextStyle(
                                color: Color(0xFFAAAAAA), fontSize: 14),
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: Color(0xFFAAAAAA), size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        color: Color(0xFFAAAAAA), size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 14),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  // Tabs
                  TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF1A1A2E),
                    unselectedLabelColor: const Color(0xFF888780),
                    indicatorColor: const Color(0xFF1A1A2E),
                    indicatorWeight: 2.5,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w400, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Semua'),
                      Tab(text: 'Beli Satuan'),
                      Tab(text: 'Langganan'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Book List ─────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1D9E75)))
                : _error != null
                    ? _buildError()
                    : _library.isEmpty
                        ? _EmptyState(tab: _activeTab, search: _searchQuery)
                        : RefreshIndicator(
                            onRefresh: _fetchLibrary,
                            color: const Color(0xFF1D9E75),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              itemCount: _library.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (ctx, i) {
                                final ebook = _library[i];
                                return _LibraryBookCard(
                                  ebook: ebook,
                                  onRead: () => _openBook(ebook),
                                  onMarkFinished: ebook.isFinished
                                      ? null
                                      : () => _markFinished(ebook),
                                  onQuiz: () => _openQuiz(ebook),
                                  onRenewSub: ebook.subscriptionExpired
                                      ? _showSubExpiredDialog
                                      : null,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuest() {
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
                  width: 96, height: 96,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFFF0F4F2),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: Color(0xFF1D9E75), size: 46),
                ),
                const SizedBox(height: 20),
                const Text('Koleksi Kamu Kosong',
                    style: TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                const Text(
                  'Masuk untuk melihat buku yang\nsudah kamu beli dan baca.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFFAAAAAA), fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()));
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
                    child: const Text('Masuk ke Akun',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
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
            Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
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
          Text(value,
              style: const TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  TextStyle(color: Colors.grey.withOpacity(0.7), fontSize: 11),
              textAlign: TextAlign.center),
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
  final VoidCallback? onRenewSub;

  const _LibraryBookCard({
    required this.ebook,
    required this.onRead,
    required this.onMarkFinished,
    required this.onQuiz,
    this.onRenewSub,
  });

  @override
  Widget build(BuildContext context) {
    final isFinished = ebook.isFinished;
    final isLocked   = ebook.subscriptionExpired;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isLocked
            ? Border.all(color: const Color(0xFFFFCC02).withOpacity(0.6))
            : null,
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
          // ── Expired banner ────────────────────────────────────
          if (isLocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded,
                      size: 14, color: Color(0xFFFF8C00)),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Lanjutkan langganan untuk tetap bisa membuka semua fitur',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF795548),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: onRenewSub,
                    child: const Text(
                      'Perpanjang',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1D9E75),
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ColorFiltered(
                        colorFilter: isLocked
                            ? const ColorFilter.matrix([
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0, 0, 0, 1, 0,
                              ])
                            : const ColorFilter.mode(
                                Colors.transparent, BlendMode.multiply),
                        child: ebook.coverUrl != null
                            ? CachedNetworkImage(
                                imageUrl: ebook.coverUrl!,
                                height: 80, width: 60,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _Cover(),
                                errorWidget: (_, __, ___) => _Cover(),
                              )
                            : _Cover(),
                      ),
                    ),
                    if (isLocked)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.lock_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ebook.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isLocked
                              ? const Color(0xFF888888)
                              : const Color(0xFF1A1A2E),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ebook.author ?? ebook.category?.name ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF888780)),
                      ),
                      const SizedBox(height: 8),
                      // Source badge
                      Row(
                        children: [
                          if (ebook.isFromSubscription)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLocked
                                    ? const Color(0xFFFF8C00).withOpacity(0.12)
                                    : const Color(0xFF1D9E75).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isLocked
                                        ? Icons.lock_rounded
                                        : Icons.workspace_premium_rounded,
                                    size: 10,
                                    color: isLocked
                                        ? const Color(0xFFFF8C00)
                                        : const Color(0xFF1D9E75),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    isLocked ? 'Expired' : 'Langganan',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isLocked
                                          ? const Color(0xFFFF8C00)
                                          : const Color(0xFF1D9E75),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A2E).withOpacity(0.07),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shopping_bag_outlined,
                                      size: 10, color: Color(0xFF555555)),
                                  SizedBox(width: 3),
                                  Text(
                                    'Beli Satuan',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF555555)),
                                  ),
                                ],
                              ),
                            ),
                          if (isFinished) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D9E75).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      size: 10, color: Color(0xFF1D9E75)),
                                  SizedBox(width: 3),
                                  Text('Selesai',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1D9E75))),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Action buttons ────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: const Color(0xFF000000).withOpacity(0.06)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onRead,
                    icon: Icon(
                      isLocked
                          ? Icons.lock_rounded
                          : Icons.menu_book_outlined,
                      size: 16,
                    ),
                    label: const Text('Baca',
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: isLocked
                          ? const Color(0xFFAAAAAA)
                          : const Color(0xFF1A1A2E),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                  ),
                ),
                Container(
                    width: 1,
                    height: 32,
                    color: const Color(0xFF000000).withOpacity(0.06)),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onQuiz,
                    icon: const Icon(Icons.quiz_outlined, size: 16),
                    label: const Text('Quiz',
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: isLocked
                          ? const Color(0xFFAAAAAA)
                          : const Color(0xFF1D9E75),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                  ),
                ),
                if (!isFinished && !isLocked) ...[
                  Container(
                      width: 1,
                      height: 32,
                      color: const Color(0xFF000000).withOpacity(0.06)),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onMarkFinished,
                      icon: const Icon(Icons.check_circle_outline_rounded,
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
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80, width: 60,
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
  final String search;
  const _EmptyState({required this.tab, required this.search});

  @override
  Widget build(BuildContext context) {
    final String message;
    final IconData icon;

    if (search.isNotEmpty) {
      message = 'Tidak ada buku dengan kata kunci "$search"';
      icon = Icons.search_off_rounded;
    } else {
      switch (tab) {
        case LibraryTab.langganan:
          message = 'Belum ada buku dari langganan.\nCoba lihat paket subscription!';
          icon = Icons.workspace_premium_outlined;
          break;
        case LibraryTab.beliSatuan:
          message = 'Belum ada buku yang dibeli satuan.';
          icon = Icons.shopping_bag_outlined;
          break;
        default:
          message = 'Belum ada buku di koleksimu.\nBeli buku sekarang!';
          icon = Icons.menu_book_outlined;
      }
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: const Color(0xFFD3D1C7)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF888780), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
