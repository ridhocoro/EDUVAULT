import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../order/screens/checkout_screen.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../models/ebook_model.dart';
import '../widgets/reviews_section.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../chat/screens/chat_screen.dart';
import '../../trial_chat/screens/trial_chat_screen.dart';

class EbookDetailScreen extends ConsumerStatefulWidget {
  final String slug;
  const EbookDetailScreen({super.key, required this.slug});

  @override
  ConsumerState<EbookDetailScreen> createState() => _EbookDetailScreenState();
}

class _EbookDetailScreenState extends ConsumerState<EbookDetailScreen> {
  EbookModel? _ebook;
  bool _owned = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final res =
          await ApiService.dio.get('${ApiConstants.ebooks}/${widget.slug}');
      final data = res.data;

      EbookModel ebook;
      bool owned = false;

      if (data is Map && data.containsKey('ebook')) {
        // Format baru: { ebook: {...}, owned: bool }
        ebook = EbookModel.fromJson(data['ebook'] as Map<String, dynamic>);
        owned = (data['owned'] as bool?) ?? false;
      } else {
        // Fallback format lama (data langsung tanpa wrapper)
        ebook = EbookModel.fromJson(data as Map<String, dynamic>);
        owned = await _checkOwned(ebook.id);
      }

      setState(() {
        _ebook   = ebook;
        _owned   = owned;
        _loading = false;
      });

      // Load wishlist state jika sudah login
      final auth = ref.read(authProvider);
      if (auth.isLoggedIn) {
        await ref.read(wishlistProvider.notifier).loadWishlist();
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<bool> _checkOwned(int ebookId) async {
    try {
      final auth = ref.read(authProvider);
      if (!auth.isLoggedIn) return false;

      final res = await ApiService.dio.get(ApiConstants.library);
      final List items = res.data is List
          ? res.data as List
          : ((res.data as Map)['data'] as List? ?? []);
      return items.any((item) {
        final id =
            (item as Map)['ebook_id'] ?? (item['ebook'] as Map?)?['id'];
        return id == ebookId;
      });
    } catch (_) {
      return false;
    }
  }

  void _handleBuy() {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      ).then((_) {
        if (ref.read(authProvider).isLoggedIn) _handleBuy();
      });
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckoutScreen(ebook: _ebook!)),
    ).then((_) {
      // Refresh detail setelah kembali dari checkout (update status owned)
      _fetchDetail();
    });
  }

  Future<void> _toggleWishlist() async {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    await ref
        .read(wishlistProvider.notifier)
        .toggleWishlist(_ebook!.id);
  }

  // ============================================
  // METHOD UNTUK MEMBUKA CHAT SCREEN
  // ============================================
  void _openChat() {
    if (_ebook == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          bookId: _ebook!.id,
          bookTitle: _ebook!.title,
          bookCover: _ebook!.coverUrl,
        ),
      ),
    );
  }
  
  void _openTrialChat() {
    if (_ebook == null) return;
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      ).then((_) {
        if (ref.read(authProvider).isLoggedIn) _openTrialChat();
      });
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrialChatScreen(
          ebookId: _ebook!.id,
          bookTitle: _ebook!.title,
          bookCover: _ebook!.coverUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_ebook == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Buku tidak ditemukan.')),
      );
    }

    final wishlistState  = ref.watch(wishlistProvider);
    final inWishlist     = wishlistState.isInWishlist(_ebook!.id);
    final auth           = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF1A1A2E)),
        title: const Text(
          'Detail Buku',
          style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 16),
        ),
        actions: [
          // Wishlist bookmark icon
          IconButton(
            onPressed: _toggleWishlist,
            icon: Icon(
              inWishlist
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: inWishlist
                  ? const Color(0xFF1D9E75)
                  : const Color(0xFF1A1A2E),
            ),
            tooltip: inWishlist ? 'Hapus dari Wishlist' : 'Simpan ke Wishlist',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _ebook!.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: _ebook!.coverUrl!,
                        height: 220,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        height: 220,
                        width: 150,
                        color: const Color(0xFFE1F5EE),
                        child: const Icon(Icons.menu_book_rounded,
                            size: 60, color: Color(0xFF1D9E75)),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Kategori badge
            if (_ebook!.category != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F5EE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _ebook!.category!.name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0F6E56),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            const SizedBox(height: 10),
            Text(
              _ebook!.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            if (_ebook!.author != null) ...[
              const SizedBox(height: 6),
              Text(
                'oleh ${_ebook!.author}',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF5F5E5A)),
              ),
            ],

            const SizedBox(height: 16),

            // Info row
            Row(
              children: [
                _InfoChip(Icons.description_outlined,
                    '${_ebook!.totalPages} halaman'),
                const SizedBox(width: 12),
                if (_ebook!.djkiCertNo != null)
                  _InfoChip(Icons.verified_outlined, 'HKI Terdaftar'),
              ],
            ),

            const SizedBox(height: 20),

            // Deskripsi
            if (_ebook!.description != null) ...[
              const Text(
                'Tentang buku ini',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _ebook!.description!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5F5E5A),
                  height: 1.6,
                ),
              ),
            ],

            const SizedBox(height: 28),
            const Divider(color: Color(0xFFE8E6DF)),
            const SizedBox(height: 20),

            // ── Reviews Section ──────────────────────────────────
            ReviewsSection(
              ebookId: _ebook!.id,
              owned:   _owned,
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),

      // Bottom action bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE8E6DF))),
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Harga',
                  style: TextStyle(fontSize: 12, color: Color(0xFF888780)),
                ),
                Text(
                  'Rp ${_ebook!.price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D9E75),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _owned ? null : _handleBuy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _owned
                        ? const Color(0xFF888780)
                        : const Color(0xFF1D9E75),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _owned ? 'Sudah dimiliki' : 'Beli Sekarang',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // ============================================
      // FLOATING ACTION BUTTON CHAT
      // HANYA MUNCUL JIKA BUKU SUDAH DIBELI (_owned == true)
      // ===========================================
      floatingActionButton: _owned
          ? FloatingActionButton.extended(
              onPressed: _openChat,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Tanya AI'),
              backgroundColor: const Color(0xFF1D9E75),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            )
          : FloatingActionButton.extended(
              onPressed: _openTrialChat,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Coba Tanya AI'),
              backgroundColor: const Color(0xFF5F5E5A),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF888780)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF888780))),
      ],
    );
  }
}