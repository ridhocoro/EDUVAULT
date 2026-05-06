// lib/features/admin/screens/admin_dashboard_screen.dart
// REPLACE file lama dengan file ini (file baru)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart' as dio_pkg;
import '../providers/admin_provider.dart';
import '../models/admin_models.dart';
import '../../catalog/models/ebook_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';

// Warna tema
const _green = Color(0xFF1D9E75);
const _bg = Color(0xFFF8F7F4);
const _white = Colors.white;
const _dark = Color(0xFF1A1A2E);
const _grey = Color(0xFF6B7280);
const _lightGreen = Color(0xFFE1F5EE);

// ──────────────────────────────────────────────────────────────────
// Entry point — AdminDashboardScreen (Tab navigator)
// ──────────────────────────────────────────────────────────────────
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    // Load data awal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(adminProvider.notifier);
      notifier.loadDashboard();
      notifier.loadEbooks();
      notifier.loadCategories();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _white,
        elevation: 0,
        title: const Text(
          'Admin Panel',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: _dark,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _dark),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: _green,
          unselectedLabelColor: _grey,
          indicatorColor: _green,
          indicatorWeight: 2,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Buku'),
            Tab(text: 'Kategori'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _DashboardTab(),
          _EbooksTab(),
          _CategoriesTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TAB 1: Dashboard
// ══════════════════════════════════════════════════════════════════
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminProvider);

    if (state.isLoading && state.stats == null) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }

    if (state.stats == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Gagal memuat data', style: TextStyle(color: _grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.read(adminProvider.notifier).loadDashboard(),
              style: ElevatedButton.styleFrom(backgroundColor: _green),
              child: const Text('Coba Lagi',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final s = state.stats!;

    return RefreshIndicator(
      color: _green,
      onRefresh: () => ref.read(adminProvider.notifier).loadDashboard(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Stat cards ────────────────────────────────────────
          _SectionLabel('Ringkasan'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              _StatCard(
                label: 'Total Buku',
                value: '${s.ebooks.total}',
                sub:
                    '${s.ebooks.published} aktif • ${s.ebooks.draft} draft',
                icon: Icons.menu_book_rounded,
                color: _green,
              ),
              _StatCard(
                label: 'Pendapatan',
                value: _rupiah(s.totalRevenue),
                sub: '${s.orders.paid} transaksi lunas',
                icon: Icons.payments_rounded,
                color: const Color(0xFFF59E0B),
              ),
              _StatCard(
                label: 'Pengguna',
                value: '${s.users.total}',
                sub: '${s.users.admins} admin',
                icon: Icons.people_rounded,
                color: const Color(0xFF8B5CF6),
              ),
              _StatCard(
                label: 'Order',
                value: '${s.orders.total}',
                sub: '${s.orders.pending} menunggu',
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF3B82F6),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Status buku breakdown ─────────────────────────────
          _SectionLabel('Status Buku'),
          const SizedBox(height: 10),
          _card(
            child: Row(
              children: [
                _StatusPill(
                    'Published', s.ebooks.published, const Color(0xFF1D9E75)),
                _StatusPill('Draft', s.ebooks.draft, const Color(0xFFF59E0B)),
                _StatusPill(
                    'Archived', s.ebooks.archived, const Color(0xFFEF4444)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Top ebooks ────────────────────────────────────────
          if (s.topEbooks.isNotEmpty) ...[
            _SectionLabel('Buku Terlaris'),
            const SizedBox(height: 10),
            ...s.topEbooks.asMap().entries.map(
                  (e) => _TopEbookTile(rank: e.key + 1, ebook: e.value),
                ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TAB 2: Ebooks
// ══════════════════════════════════════════════════════════════════
class _EbooksTab extends ConsumerStatefulWidget {
  const _EbooksTab();

  @override
  ConsumerState<_EbooksTab> createState() => _EbooksTabState();
}

class _EbooksTabState extends ConsumerState<_EbooksTab> {
  final _searchCtrl = TextEditingController();
  String _selectedStatus = '';

  static const _statusOptions = [
    ('', 'Semua'),
    ('published', 'Published'),
    ('draft', 'Draft'),
    ('archived', 'Archived'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    ref
        .read(adminProvider.notifier)
        .loadEbooks(page: 1, search: q, status: _selectedStatus);
  }

  void _setStatus(String s) {
    setState(() => _selectedStatus = s);
    ref
        .read(adminProvider.notifier)
        .loadEbooks(page: 1, status: s, search: _searchCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);

    return Column(
      children: [
        // ── Toolbar ──────────────────────────────────────────────
        Container(
          color: _white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search
              TextField(
                controller: _searchCtrl,
                onSubmitted: _search,
                decoration: InputDecoration(
                  hintText: 'Cari judul atau penulis...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 18, color: _grey),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            _search('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: _bg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              // Status filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _statusOptions.map((opt) {
                    final selected = _selectedStatus == opt.$1;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(opt.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: selected ? Colors.white : _dark,
                            )),
                        selected: selected,
                        onSelected: (_) => _setStatus(opt.$1),
                        selectedColor: _green,
                        backgroundColor: _bg,
                        checkmarkColor: Colors.white,
                        side: BorderSide(
                          color: selected ? _green : const Color(0xFFD1D5DB),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // ── FAB tambah buku ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${state.ebookTotal} buku',
                style: const TextStyle(fontSize: 12, color: _grey),
              ),
              ElevatedButton.icon(
                onPressed: () => _showEbookForm(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Tambah Buku',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),

        // ── List ─────────────────────────────────────────────────
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator(color: _green))
              : state.ebooks.isEmpty
                  ? const Center(
                      child: Text('Tidak ada buku',
                          style: TextStyle(color: _grey)))
                  : RefreshIndicator(
                      color: _green,
                      onRefresh: () => ref
                          .read(adminProvider.notifier)
                          .loadEbooks(page: 1),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                        itemCount: state.ebooks.length +
                            (state.ebookCurrentPage < state.ebookLastPage
                                ? 1
                                : 0),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          if (i == state.ebooks.length) {
                            return Center(
                              child: TextButton(
                                onPressed: () => ref
                                    .read(adminProvider.notifier)
                                    .loadEbooks(
                                        page:
                                            state.ebookCurrentPage + 1),
                                child: const Text('Muat lebih banyak',
                                    style: TextStyle(color: _green)),
                              ),
                            );
                          }
                          return _EbookTile(
                            ebook: state.ebooks[i],
                            onEdit: () =>
                                _showEbookForm(context, ref,
                                    ebook: state.ebooks[i]),
                            onToggle: () =>
                                _toggleEbook(context, ref, state.ebooks[i]),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Future<void> _toggleEbook(
      BuildContext ctx, WidgetRef ref, EbookModel ebook) async {
    final isActive = ebook.status == 'published' || ebook.status == 'draft';
    final label = isActive ? 'nonaktifkan' : 'aktifkan';

    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => _ConfirmDialog(
        title: isActive ? 'Nonaktifkan Buku' : 'Aktifkan Buku',
        message: 'Apakah kamu yakin ingin $label "${ebook.title}"?',
        confirmLabel: isActive ? 'Nonaktifkan' : 'Aktifkan',
        isDestructive: isActive,
      ),
    );

    if (ok != true) return;

    final notifier = ref.read(adminProvider.notifier);
    final err = isActive
        ? await notifier.deactivateEbook(ebook.id)
        : await notifier.activateEbook(ebook.id);

    if (!ctx.mounted) return;
    _showSnack(ctx, err == null ? 'Berhasil!' : err, isError: err != null);
  }

  Future<void> _showEbookForm(BuildContext ctx, WidgetRef ref,
      {EbookModel? ebook}) async {
    // Jika edit, load detail dulu untuk dapat file_url
    EbookModel? detail = ebook;
    if (ebook != null) {
      detail = await ref.read(adminProvider.notifier).getEbookDetail(ebook.id);
    }

    if (!ctx.mounted) return;

    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EbookFormSheet(ebook: detail),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TAB 3: Categories
// ══════════════════════════════════════════════════════════════════
class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(adminProvider).categories;

    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        onPressed: () => _showCatForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kategori',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: cats.isEmpty
          ? const Center(
              child: Text('Belum ada kategori', style: TextStyle(color: _grey)))
          : RefreshIndicator(
              color: _green,
              onRefresh: () => ref.read(adminProvider.notifier).loadCategories(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final cat = cats[i];
                  return _card(
                    child: ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _lightGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.category_rounded,
                            color: _green, size: 18),
                      ),
                      title: Text(cat.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(cat.slug,
                          style:
                              const TextStyle(fontSize: 11, color: _grey)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (cat.ebooksCount != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _lightGreen,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${cat.ebooksCount} buku',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: _green,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 18, color: _grey),
                            onPressed: () =>
                                _showCatForm(ctx, ref, cat: cat),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: Color(0xFFEF4444)),
                            onPressed: () =>
                                _deleteCategory(ctx, ref, cat),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _deleteCategory(
      BuildContext ctx, WidgetRef ref, CategoryModel cat) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => _ConfirmDialog(
        title: 'Hapus Kategori',
        message:
            'Hapus kategori "${cat.name}"? Pastikan tidak ada buku di kategori ini.',
        confirmLabel: 'Hapus',
        isDestructive: true,
      ),
    );

    if (ok != true) return;

    final err =
        await ref.read(adminProvider.notifier).deleteCategory(cat.id);
    if (!ctx.mounted) return;
    _showSnack(ctx, err == null ? 'Kategori dihapus' : err,
        isError: err != null);
  }

  Future<void> _showCatForm(BuildContext ctx, WidgetRef ref,
      {CategoryModel? cat}) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryFormSheet(category: cat),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Form Sheet: Tambah / Edit Buku
// ══════════════════════════════════════════════════════════════════
class _EbookFormSheet extends ConsumerStatefulWidget {
  final EbookModel? ebook;
  const _EbookFormSheet({this.ebook});

  @override
  ConsumerState<_EbookFormSheet> createState() => _EbookFormSheetState();
}

class _EbookFormSheetState extends ConsumerState<_EbookFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _price;
  late final TextEditingController _desc;
  late final TextEditingController _pages;
  late final TextEditingController _djki;
  late final TextEditingController _cover;
  String _status = 'draft';
  int? _categoryId;

  // Upload state
  String? _existingFileUrl;   // path file yang sudah ada di server
  String? _uploadedFileName;  // nama file setelah upload berhasil
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final b = widget.ebook;
    _title  = TextEditingController(text: b?.title);
    _author = TextEditingController(text: b?.author);
    _price  = TextEditingController(text: b?.price.toStringAsFixed(0) ?? '0');
    _desc   = TextEditingController(text: b?.description);
    _pages  = TextEditingController(text: b?.totalPages.toString() ?? '0');
    _djki   = TextEditingController(text: b?.djkiCertNo);
    _cover  = TextEditingController(text: b?.coverUrl);
    _status = b?.status ?? 'draft';
    _categoryId = b?.categoryId ?? b?.category?.id;
    _existingFileUrl = b?.fileUrl;
  }

  @override
  void dispose() {
    for (final c in [_title, _author, _price, _desc, _pages, _djki, _cover]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Upload file PDF/EPUB ke server ────────────────────────────
  Future<void> _pickAndUpload() async {
    // Harus simpan buku dulu sebelum upload file
    if (widget.ebook == null) {
      _showSnack(context, 'Simpan buku terlebih dahulu sebelum upload file.', isError: true);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _isUploading = true);

    try {
      final formData = dio_pkg.FormData.fromMap({
        'file': await dio_pkg.MultipartFile.fromFile(
          file.path!,
          filename: file.name,
        ),
      });

      final res = await ApiService.dio.post(
        ApiConstants.adminEbookUpload(widget.ebook!.id),
        data: formData,
        options: dio_pkg.Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      setState(() {
        _existingFileUrl = res.data['file_url'] as String?;
        _uploadedFileName = file.name;
        _isUploading = false;
      });

      if (mounted) {
        _showSnack(context, 'File "${file.name}" berhasil diupload!');
        // Refresh daftar buku di admin
        ref.read(adminProvider.notifier).loadEbooks();
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        _showSnack(context, 'Gagal upload: ${e.toString()}', isError: true);
      }
    }
  }

  // ── Hapus file dari server ────────────────────────────────────
  Future<void> _deleteFile() async {
    if (widget.ebook == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus file?'),
        content: const Text('File PDF/EPUB akan dihapus dari server.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.dio.delete(ApiConstants.adminEbookUpload(widget.ebook!.id));
      setState(() {
        _existingFileUrl = null;
        _uploadedFileName = null;
      });
      if (mounted) _showSnack(context, 'File berhasil dihapus.');
    } catch (e) {
      if (mounted) _showSnack(context, 'Gagal hapus file.', isError: true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'title':        _title.text.trim(),
      'author':       _author.text.trim().isEmpty ? null : _author.text.trim(),
      'price':        double.tryParse(_price.text) ?? 0,
      'description':  _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'total_pages':  int.tryParse(_pages.text) ?? 0,
      'djki_cert_no': _djki.text.trim().isEmpty ? null : _djki.text.trim(),
      'cover_url':    _cover.text.trim().isEmpty ? null : _cover.text.trim(),
      'status':       _status,
      'category_id':  _categoryId,
    };

    final notifier = ref.read(adminProvider.notifier);
    final String? err;

    if (widget.ebook != null) {
      err = await notifier.updateEbook(widget.ebook!.id, data);
    } else {
      err = await notifier.createEbook(data);
    }

    if (!mounted) return;

    if (err != null) {
      _showSnack(context, err, isError: true);
    } else {
      Navigator.pop(context);
      _showSnack(context, widget.ebook == null
          ? 'Buku berhasil dibuat! Buka Edit untuk upload file PDF.'
          : 'Buku berhasil disimpan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(adminProvider).categories;
    final isSaving = ref.watch(adminProvider).isSaving;
    final isEdit = widget.ebook != null;

    return Container(
      decoration: const BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            _sheetHandle(),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Buku' : 'Tambah Buku',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _dark),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: _grey),
                  ),
                ],
              ),
            ),

            // Form fields
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field('Judul Buku *', _title,
                        validator: (v) =>
                            v!.isEmpty ? 'Judul wajib diisi' : null),
                    _field('Penulis', _author),
                    _row([
                      _field('Harga (Rp) *', _price,
                          keyboard: TextInputType.number,
                          validator: (v) =>
                              v!.isEmpty ? 'Wajib diisi' : null),
                      _field('Total Halaman', _pages,
                          keyboard: TextInputType.number),
                    ]),
                    _field('Deskripsi', _desc, maxLines: 3),
                    _field('No. Sertifikat DJKI', _djki),
                    _field('URL Cover', _cover,
                        keyboard: TextInputType.url,
                        hint: 'https://...'),

                    // ── Upload File PDF/EPUB ────────────────────
                    const SizedBox(height: 8),
                    const Text('File Buku (PDF / EPUB)',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _grey)),
                    const SizedBox(height: 8),

                    // Status file yang sudah ada
                    if (_existingFileUrl != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FBF7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFB8E8D8)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded,
                                color: _green, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _uploadedFileName ??
                                    _existingFileUrl!.split('/').last,
                                style: const TextStyle(
                                    fontSize: 13, color: _dark),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isEdit)
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 20),
                                onPressed: _deleteFile,
                                tooltip: 'Hapus file',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Tombol upload
                    if (isEdit) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isUploading ? null : _pickAndUpload,
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: _green),
                                )
                              : const Icon(Icons.upload_file_rounded,
                                  color: _green, size: 18),
                          label: Text(
                            _isUploading
                                ? 'Mengupload...'
                                : _existingFileUrl != null
                                    ? 'Ganti File PDF/EPUB'
                                    : 'Upload File PDF/EPUB',
                            style: const TextStyle(color: _green),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _green),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFE082)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.orange, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Simpan buku terlebih dahulu, lalu buka Edit untuk upload file PDF/EPUB.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    const Text('Kategori *',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _grey)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _categoryId,
                      validator: (v) => v == null ? 'Pilih kategori' : null,
                      decoration: _inputDecor(hint: 'Pilih kategori'),
                      items: cats
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name,
                                    style: const TextStyle(fontSize: 14)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                    const SizedBox(height: 14),

                    // Status
                    const Text('Status',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _grey)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: _inputDecor(),
                      items: const [
                        DropdownMenuItem(
                            value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(
                            value: 'published', child: Text('Published')),
                        DropdownMenuItem(
                            value: 'archived', child: Text('Archived')),
                      ],
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Save button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          isEdit ? 'Simpan Perubahan' : 'Tambah Buku',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: _grey)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboard,
          validator: validator,
          style: const TextStyle(fontSize: 14),
          decoration: _inputDecor(hint: hint),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _row(List<Widget> children) {
    return Row(
      children: children
          .map((c) => Expanded(child: Padding(
                padding: EdgeInsets.only(
                    right: c == children.first ? 8 : 0),
                child: c,
              )))
          .toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Form Sheet: Tambah / Edit Kategori
// ══════════════════════════════════════════════════════════════════
class _CategoryFormSheet extends ConsumerStatefulWidget {
  final CategoryModel? category;
  const _CategoryFormSheet({this.category});

  @override
  ConsumerState<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<_CategoryFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _icon;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name);
    _icon = TextEditingController(text: widget.category?.icon);
  }

  @override
  void dispose() {
    _name.dispose();
    _icon.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(adminProvider.notifier);
    final String? err;

    if (widget.category != null) {
      err = await notifier.updateCategory(
          widget.category!.id, _name.text.trim(), _icon.text.trim().isEmpty ? null : _icon.text.trim());
    } else {
      err = await notifier.createCategory(
          _name.text.trim(), _icon.text.trim().isEmpty ? null : _icon.text.trim());
    }

    if (!mounted) return;
    if (err != null) {
      _showSnack(context, err, isError: true);
    } else {
      Navigator.pop(context);
      _showSnack(context, 'Kategori berhasil disimpan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(adminProvider).isSaving;
    final isEdit = widget.category != null;

    return Container(
      decoration: const BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEdit ? 'Edit Kategori' : 'Tambah Kategori',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _dark)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: _grey),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nama Kategori *',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _grey)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _name,
                    validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    decoration:
                        _inputDecor(hint: 'Contoh: Ekonomi & Bisnis'),
                  ),
                  const SizedBox(height: 14),
                  const Text('Icon (opsional)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _grey)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _icon,
                    decoration: _inputDecor(hint: 'business'),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              isEdit ? 'Simpan Perubahan' : 'Tambah',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Reusable Widgets
// ══════════════════════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border(top: BorderSide(color: color, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: _grey)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                  letterSpacing: -0.5)),
          Text(sub,
              style: const TextStyle(fontSize: 10, color: _grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusPill(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: _grey)),
          ],
        ),
      ),
    );
  }
}

class _TopEbookTile extends StatelessWidget {
  final int rank;
  final TopEbook ebook;

  const _TopEbookTile({required this.rank, required this.ebook});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _card(
        child: ListTile(
          dense: true,
          leading: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rank == 1 ? const Color(0xFFFEF3C7) : _bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text('$rank',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: rank == 1
                          ? const Color(0xFFD97706)
                          : _grey)),
            ),
          ),
          title: Text(ebook.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text(
              '${ebook.categoryName ?? '—'} • ${ebook.author ?? '—'}',
              style: const TextStyle(fontSize: 11, color: _grey)),
          trailing: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _lightGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${ebook.salesCount} terjual',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _green),
            ),
          ),
        ),
      ),
    );
  }
}

class _EbookTile extends StatelessWidget {
  final EbookModel ebook;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _EbookTile({
    required this.ebook,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isArchived = ebook.status == 'archived';

    return _card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Cover
            Container(
              width: 48,
              height: 64,
              decoration: BoxDecoration(
                color: _lightGreen,
                borderRadius: BorderRadius.circular(6),
                image: ebook.coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(ebook.coverUrl!),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: ebook.coverUrl == null
                  ? const Icon(Icons.menu_book_rounded,
                      color: _green, size: 22)
                  : null,
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatusBadge(ebook.status),
                      const Spacer(),
                      Text(
                        ebook.price == 0
                            ? 'Gratis'
                            : 'Rp ${_rupiah(ebook.price)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ebook.price == 0 ? _green : _dark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(ebook.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: _dark)),
                  const SizedBox(height: 2),
                  Text(
                    '${ebook.author ?? '—'} • ${ebook.category?.name ?? '—'}',
                    style: const TextStyle(fontSize: 11, color: _grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _ActionBtn(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        onTap: onEdit,
                      ),
                      const SizedBox(width: 6),
                      _ActionBtn(
                        label: isArchived ? 'Aktifkan' : 'Nonaktifkan',
                        icon: isArchived
                            ? Icons.check_circle_outline
                            : Icons.block_outlined,
                        color: isArchived
                            ? _green
                            : const Color(0xFFEF4444),
                        onTap: onToggle,
                      ),
                    ],
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

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final colors = {
      'published': (_lightGreen, _green),
      'draft': (const Color(0xFFFEF3C7), const Color(0xFFD97706)),
      'archived': (const Color(0xFFFEE2E2), const Color(0xFFEF4444)),
    };
    final c = colors[status] ?? (_bg, _grey);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.$1,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: c.$2)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = _grey,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDestructive;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      content: Text(message, style: const TextStyle(fontSize: 14, color: _grey)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal', style: TextStyle(color: _grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isDestructive ? const Color(0xFFEF4444) : _green,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(confirmLabel,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _dark,
            letterSpacing: 0.2));
  }
}

// ══════════════════════════════════════════════════════════════════
// Helpers
// ══════════════════════════════════════════════════════════════════
Widget _card({required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

Widget _sheetHandle() {
  return Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

InputDecoration _inputDecor({String? hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFD1D5DB)),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _green, width: 1.5),
    ),
    filled: true,
    fillColor: _bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    isDense: true,
  );
}

void _showSnack(BuildContext ctx, String msg, {bool isError = false}) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: isError ? const Color(0xFFEF4444) : _green,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ));
}

String _rupiah(double v) {
  return v
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
}