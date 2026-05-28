import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../quiz/screens/quiz_screen.dart';

class ReaderScreen extends StatefulWidget {
  final String title;
  final String pdfUrl;
  final int ebookId; // ← TAMBAHAN: diperlukan untuk navigasi ke QuizScreen

  const ReaderScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
    required this.ebookId,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  String? _localPath;
  bool _loading = true;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/reading_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await Dio().download(widget.pdfUrl, path);
      if (mounted) setState(() { _localPath = path; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          ebookId: widget.ebookId,
          bookTitle: widget.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2C2A),
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // ── Tombol Quiz ──────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.quiz_outlined, color: Colors.white),
            tooltip: 'Quiz',
            onPressed: _openQuiz,
          ),
          // ── Nomor halaman ────────────────────────────────────
          if (_totalPages > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                '${_currentPage + 1} / $_totalPages',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1D9E75)),
                  SizedBox(height: 16),
                  Text('Memuat buku...',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : _localPath == null
              ? const Center(
                  child: Text('Gagal memuat PDF.',
                      style: TextStyle(color: Colors.white70)),
                )
              : PDFView(
                  filePath: _localPath!,
                  enableSwipe: true,
                  swipeHorizontal: true,
                  autoSpacing: false,
                  pageFling: true,
                  onRender: (pages) =>
                      setState(() => _totalPages = pages ?? 0),
                  onPageChanged: (page, _) =>
                      setState(() => _currentPage = page ?? 0),
                  onError: (err) => debugPrint('PDF Error: $err'),
                ),
    );
  }
}