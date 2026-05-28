// lib/features/quiz/screens/quiz_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/quiz_provider.dart';

class QuizScreen extends ConsumerWidget {
  final int ebookId;
  final String bookTitle;

  const QuizScreen({
    super.key,
    required this.ebookId,
    required this.bookTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(quizProvider(ebookId));
    final notifier = ref.read(quizProvider(ebookId).notifier);

    return switch (state.phase) {
      QuizPhase.loading    => _LoadingScreen(bookTitle: bookTitle),
      QuizPhase.setup      => _SetupScreen(ebookId: ebookId, bookTitle: bookTitle, state: state, notifier: notifier),
      QuizPhase.generating => _GeneratingScreen(bookTitle: bookTitle),
      QuizPhase.intro      => _IntroScreen(ebookId: ebookId, bookTitle: bookTitle, state: state, notifier: notifier),
      QuizPhase.playing    => _PlayingScreen(ebookId: ebookId, bookTitle: bookTitle, state: state, notifier: notifier),
      QuizPhase.result     => _ResultScreen(ebookId: ebookId, bookTitle: bookTitle, state: state, notifier: notifier),
    };
  }
}

// ─── Loading ──────────────────────────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  final String bookTitle;
  const _LoadingScreen({required this.bookTitle});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8F7F4),
        appBar: _appBar(context, 'Quiz', bookTitle),
        body: const Center(child: CircularProgressIndicator()),
      );
}

// ─── Generating ───────────────────────────────────────────────────────

class _GeneratingScreen extends StatelessWidget {
  final String bookTitle;
  const _GeneratingScreen({required this.bookTitle});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8F7F4),
        appBar: _appBar(context, 'Quiz', bookTitle),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F5EE),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(Icons.auto_awesome, size: 36, color: Color(0xFF1D9E75)),
                ),
                const SizedBox(height: 24),
                const Text('AI sedang membuat soal...',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                const SizedBox(height: 8),
                const Text('Soal dibuat dari isi PDF/EPUB buku ini.\nMohon tunggu sebentar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF888780))),
                const SizedBox(height: 32),
                const CircularProgressIndicator(color: Color(0xFF1D9E75)),
              ],
            ),
          ),
        ),
      );
}

// ─── Setup — pilih aksi: buat quiz baru atau pilih quiz lama ──────────

class _SetupScreen extends ConsumerStatefulWidget {
  final int ebookId;
  final String bookTitle;
  final QuizState state;
  final QuizNotifier notifier;

  const _SetupScreen({
    required this.ebookId,
    required this.bookTitle,
    required this.state,
    required this.notifier,
  });

  @override
  ConsumerState<_SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<_SetupScreen> {
  // Form generate
  String _quizType    = 'full';
  int _questionCount  = 10;
  final _chapterNoCtrl    = TextEditingController();
  final _chapterTitleCtrl = TextEditingController();
  bool _showForm = false;

  @override
  void dispose() {
    _chapterNoCtrl.dispose();
    _chapterTitleCtrl.dispose();
    super.dispose();
  }

  void _submitGenerate() {
    if (_quizType == 'chapter') {
      final no = int.tryParse(_chapterNoCtrl.text.trim());
      if (no == null || no < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nomor bab harus diisi dengan angka yang valid')));
        return;
      }
    }
    widget.notifier.generateQuiz(
      quizType:      _quizType,
      questionCount: _questionCount,
      chapterNumber: _quizType == 'chapter'
          ? int.tryParse(_chapterNoCtrl.text.trim())
          : null,
      chapterTitle:  _quizType == 'chapter'
          ? (_chapterTitleCtrl.text.trim().isEmpty ? null : _chapterTitleCtrl.text.trim())
          : null,
    );
  }

  Future<void> _deleteQuiz(QuizData quiz) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Quiz?'),
        content: Text('Quiz "${quiz.typeLabel}" akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Color(0xFFD32F2F))),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await widget.notifier.deleteQuiz(quiz.id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus quiz')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state    = widget.state;
    final notifier = widget.notifier;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: _appBar(context, 'Quiz', widget.bookTitle),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Banner jika tidak ada file ───────────────────────
            if (!state.hasFile)
              _WarningBanner(
                message: 'Buku ini belum memiliki file PDF/EPUB. '
                    'Quiz tidak bisa dibuat hingga admin mengupload file buku.',
              ),
            if (!state.hasFile) const SizedBox(height: 12),

            // ── Error generate ───────────────────────────────────
            if (state.generateError.isNotEmpty)
              _WarningBanner(message: state.generateError, isError: true),
            if (state.generateError.isNotEmpty) const SizedBox(height: 12),

            // ── Panel buat quiz baru ─────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🤖', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Buat Quiz Baru',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                      ),
                      // Toggle tampilkan/sembunyikan form
                      TextButton(
                        onPressed: () => setState(() => _showForm = !_showForm),
                        child: Text(_showForm ? 'Tutup ▲' : 'Buka ▼',
                            style: const TextStyle(color: Color(0xFF1D9E75), fontSize: 13)),
                      ),
                    ],
                  ),

                  if (_showForm) ...[
                    const SizedBox(height: 14),
                    const Divider(color: Color(0xFFE8E6DF), height: 1),
                    const SizedBox(height: 14),

                    // Pilih tipe quiz
                    const Text('Tipe Quiz',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _TypeChip(
                          label: '📖 Full Buku',
                          selected: _quizType == 'full',
                          onTap: () => setState(() => _quizType = 'full'),
                        ),
                        const SizedBox(width: 10),
                        _TypeChip(
                          label: '📑 Per Bab',
                          selected: _quizType == 'chapter',
                          onTap: () => setState(() => _quizType = 'chapter'),
                        ),
                      ],
                    ),

                    // Input bab (hanya jika chapter)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: _quizType == 'chapter'
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 90,
                                    child: _InputField(
                                      label: 'Nomor Bab *',
                                      controller: _chapterNoCtrl,
                                      hint: 'cth: 3',
                                      keyboardType: TextInputType.number,
                                      formatters: [FilteringTextInputFormatter.digitsOnly],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _InputField(
                                      label: 'Judul Bab (opsional)',
                                      controller: _chapterTitleCtrl,
                                      hint: 'cth: Algoritma Sorting',
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 14),

                    // Jumlah soal
                    const Text('Jumlah Soal',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [5, 10, 15, 20].map((n) {
                        final sel = _questionCount == n;
                        return ChoiceChip(
                          label: Text('$n'),
                          selected: sel,
                          onSelected: (_) => setState(() => _questionCount = n),
                          selectedColor: const Color(0xFF1D9E75),
                          labelStyle: TextStyle(
                            color: sel ? Colors.white : const Color(0xFF444444),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          backgroundColor: const Color(0xFFF0EEE9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide.none,
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: state.hasFile ? _submitGenerate : null,
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Generate Soal dengan AI'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D9E75),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE8E6DF),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),

                    if (!state.hasFile)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('File buku belum tersedia',
                            style: TextStyle(fontSize: 11, color: Color(0xFFD32F2F))),
                      ),
                  ],
                ],
              ),
            ),

            // ── Daftar quiz yang sudah dibuat ────────────────────
            if (state.savedQuizzes.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Quiz Tersimpan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 10),
              ...state.savedQuizzes.map((quiz) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SavedQuizCard(
                      quiz: quiz,
                      onStart: () => notifier.selectQuiz(quiz),
                      onDelete: () => _deleteQuiz(quiz),
                    ),
                  )),
            ],

            // ── Empty state ──────────────────────────────────────
            if (state.savedQuizzes.isEmpty && state.hasFile)
              _EmptyState(onCreateTap: () => setState(() => _showForm = true)),
          ],
        ),
      ),
    );
  }
}

// ─── Intro — info quiz sebelum mulai ─────────────────────────────────

class _IntroScreen extends StatelessWidget {
  final int ebookId;
  final String bookTitle;
  final QuizState state;
  final QuizNotifier notifier;

  const _IntroScreen({
    required this.ebookId,
    required this.bookTitle,
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final quiz = state.activeQuiz!;
    final best = quiz.bestAttempt;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(
          color: const Color(0xFF1A1A2E),
          onPressed: notifier.backToSetup,
        ),
        title: const Text('Quiz', style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D9E75), Color(0xFF0F6E56)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.quiz_rounded, color: Colors.white70, size: 32),
                  const SizedBox(height: 12),
                  Text(quiz.typeLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(bookTitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stats
            Row(
              children: [
                _StatCard(icon: Icons.help_outline, label: 'Soal',
                    value: '${quiz.questions.length}', color: const Color(0xFF1D9E75)),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.emoji_events_outlined,
                  label: 'Best Score',
                  value: best != null ? '${best.percentage}%' : '-',
                  color: const Color(0xFFF4A025),
                ),
              ],
            ),

            if (best != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F5EE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFF1D9E75), size: 18),
                    const SizedBox(width: 8),
                    Text('Skor terbaikmu: ${best.score}/${best.total} (${best.percentage}%)',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F6E56))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Text('Petunjuk',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            ...const [
              '✅  Pilih satu jawaban untuk setiap soal',
              '⏱️  Tidak ada batas waktu, santai saja',
              '💡  Setelah selesai, kamu bisa melihat penjelasan tiap soal',
              '🔄  Bisa diulang berkali-kali untuk latihan',
            ].map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(t, style: const TextStyle(fontSize: 13, color: Color(0xFF5F5E5A))),
                )),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: notifier.startQuiz,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(best != null ? '🔄  Coba Lagi' : '🚀  Mulai Quiz',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: notifier.backToSetup,
                child: const Text('← Pilih / Buat Quiz Lain',
                    style: TextStyle(color: Color(0xFF888780))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Playing ──────────────────────────────────────────────────────────

class _PlayingScreen extends StatelessWidget {
  final int ebookId;
  final String bookTitle;
  final QuizState state;
  final QuizNotifier notifier;

  const _PlayingScreen({
    required this.ebookId,
    required this.bookTitle,
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final quiz     = state.activeQuiz!;
    final question = state.currentQuestion!;
    final total    = quiz.questions.length;
    final selected = state.answers[question.id];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A1A2E)),
          onPressed: () => _showQuitDialog(context),
        ),
        title: Text(
          '${state.currentIndex + 1} dari $total',
          style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 15, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (state.currentIndex + 1) / total,
            minHeight: 4,
            backgroundColor: const Color(0xFFE8E6DF),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF1D9E75)),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F5EE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Soal ${state.currentIndex + 1}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F6E56), fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 16),
                  Text(question.question,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E), height: 1.4)),
                  const SizedBox(height: 24),
                  ...['a', 'b', 'c', 'd'].map((key) => _OptionTile(
                        optionKey: key,
                        text: question.optionText(key),
                        isSelected: selected == key,
                        onTap: () => notifier.selectAnswer(question.id, key),
                      )),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            color: Colors.white,
            child: Row(
              children: [
                if (state.currentIndex > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: notifier.prevQuestion,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE8E6DF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('← Sebelumnya', style: TextStyle(color: Color(0xFF5F5E5A))),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: selected == null
                        ? null
                        : state.isLastQuestion
                            ? () => _confirmSubmit(context)
                            : notifier.nextQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D9E75),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE8E6DF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: state.isSubmitting
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            state.isLastQuestion ? 'Selesai & Lihat Skor' : 'Selanjutnya →',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQuitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar Quiz?'),
        content: const Text('Progresmu akan hilang.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Lanjut Quiz')),
          TextButton(
            onPressed: () { Navigator.pop(context); notifier.backToSetup(); },
            child: const Text('Keluar', style: TextStyle(color: Color(0xFFD32F2F))),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSubmit(BuildContext context) async {
    final unanswered = (state.activeQuiz?.questions.length ?? 0) - state.answeredCount;
    if (unanswered > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Ada soal belum dijawab'),
          content: Text('$unanswered soal belum dijawab. Kumpulkan sekarang?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Kembali')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kumpulkan', style: TextStyle(color: Color(0xFF1D9E75))),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    notifier.submitQuiz();
  }
}

// ─── Result ───────────────────────────────────────────────────────────

class _ResultScreen extends StatelessWidget {
  final int ebookId;
  final String bookTitle;
  final QuizState state;
  final QuizNotifier notifier;

  const _ResultScreen({
    required this.ebookId,
    required this.bookTitle,
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final score = state.score ?? 0;
    final total = state.total ?? 1;
    final pct   = state.percentage ?? 0;

    final (emoji, message, color) = switch (pct) {
      >= 90 => ('🏆', 'Luar Biasa!',     const Color(0xFFF4A025)),
      >= 70 => ('🎉', 'Bagus Sekali!',   const Color(0xFF1D9E75)),
      >= 50 => ('👍', 'Cukup Baik!',     const Color(0xFF2196F3)),
      _     => ('💪', 'Terus Berlatih!', const Color(0xFFEF5350)),
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: const Color(0xFF1A1A2E), onPressed: notifier.backToSetup),
        title: const Text('Hasil Quiz', style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Score card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 56)),
                  const SizedBox(height: 8),
                  Text(message, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CircularProgressIndicator(
                            value: pct / 100,
                            strokeWidth: 10,
                            backgroundColor: const Color(0xFFE8E6DF),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$pct%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
                              Text('$score/$total', style: const TextStyle(fontSize: 12, color: Color(0xFF888780))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: notifier.chooseAnotherQuiz,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF1D9E75)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Quiz Lain', style: TextStyle(color: Color(0xFF1D9E75))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: notifier.retryQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D9E75),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('🔄 Coba Lagi', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pembahasan
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Pembahasan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
            ),
            const SizedBox(height: 12),
            ...state.results.asMap().entries.map((entry) {
              final i        = entry.key;
              final result   = entry.value;
              final question = state.activeQuiz!.questions
                  .firstWhere((q) => q.id == result.questionId);
              return _ResultCard(index: i, question: question, result: result);
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────

AppBar _appBar(BuildContext context, String title, String subtitle) => AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: BackButton(color: const Color(0xFF1A1A2E), onPressed: () => Navigator.pop(context)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 15, fontWeight: FontWeight.w600)),
          Text(subtitle, style: const TextStyle(color: Color(0xFF888780), fontSize: 11), overflow: TextOverflow.ellipsis),
        ],
      ),
    );

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: child,
      );
}

class _WarningBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const _WarningBanner({required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isError ? const Color(0xFFEF9A9A) : const Color(0xFFFFE082),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isError ? '❌' : '⚠️', style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: TextStyle(
                      fontSize: 12,
                      color: isError ? const Color(0xFFB71C1C) : const Color(0xFF7B5800))),
            ),
          ],
        ),
      );
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1D9E75) : const Color(0xFFF0EEE9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? const Color(0xFF1D9E75) : const Color(0xFFDDDBD5)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF444444))),
        ),
      );
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;

  const _InputField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.formatters,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: formatters,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFFBBB9B3), fontSize: 12),
              filled: true,
              fillColor: const Color(0xFFF8F7F4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE8E6DF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE8E6DF)),
              ),
            ),
          ),
        ],
      );
}

class _SavedQuizCard extends StatelessWidget {
  final QuizData quiz;
  final VoidCallback onStart;
  final VoidCallback onDelete;
  const _SavedQuizCard({required this.quiz, required this.onStart, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E6DF)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(quiz.typeLabel,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 2),
                  Text('${quiz.questions.length} soal',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF888780))),
                  if (quiz.bestAttempt != null)
                    Text('Best: ${quiz.bestAttempt!.percentage}%',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1D9E75), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFCCCAC5)),
              onPressed: onDelete,
              tooltip: 'Hapus quiz',
            ),
            ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D9E75),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Mulai', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Text('📝', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('Belum ada quiz untuk buku ini',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 8),
              const Text('Buat quiz dari isi PDF/EPUB buku\ndan pilih materi yang ingin diujikan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF888780))),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onCreateTap,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Buat Quiz Sekarang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                  Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF888780))),
                ],
              ),
            ],
          ),
        ),
      );
}

class _OptionTile extends StatelessWidget {
  final String optionKey;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  const _OptionTile({required this.optionKey, required this.text, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE1F5EE) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF1D9E75) : const Color(0xFFE8E6DF),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1D9E75) : const Color(0xFFF0EFE9),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(optionKey.toUpperCase(),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : const Color(0xFF888780))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? const Color(0xFF0F6E56) : const Color(0xFF1A1A2E),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
              ),
            ],
          ),
        ),
      );
}

class _ResultCard extends StatefulWidget {
  final int index;
  final QuizQuestion question;
  final QuizResult result;
  const _ResultCard({required this.index, required this.question, required this.result});
  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final isCorrect = widget.result.isCorrect;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? const Color(0xFF1D9E75).withOpacity(0.3) : const Color(0xFFEF5350).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: isCorrect ? const Color(0xFFE1F5EE) : const Color(0xFFFFEBEB),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(isCorrect ? Icons.check : Icons.close,
                        size: 14, color: isCorrect ? const Color(0xFF1D9E75) : const Color(0xFFEF5350)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Soal ${widget.index + 1}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                  ),
                  Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: const Color(0xFF888780), size: 20),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Color(0xFFE8E6DF)),
                  Text(widget.question.question,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 8),
                  _AnswerRow(
                    label: 'Jawabanmu',
                    value: '${widget.result.yourAnswer.toUpperCase()}. ${widget.question.optionText(widget.result.yourAnswer)}',
                    color: isCorrect ? const Color(0xFF1D9E75) : const Color(0xFFEF5350),
                  ),
                  if (!isCorrect) ...[
                    const SizedBox(height: 4),
                    _AnswerRow(
                      label: 'Jawaban benar',
                      value: '${widget.result.correctAnswer.toUpperCase()}. ${widget.question.optionText(widget.result.correctAnswer)}',
                      color: const Color(0xFF1D9E75),
                    ),
                  ],
                  if (widget.result.explanation != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFF8F7F4), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💡 Penjelasan',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF5F5E5A))),
                          const SizedBox(height: 4),
                          Text(widget.result.explanation!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF5F5E5A))),
                        ],
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

class _AnswerRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AnswerRow({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Color(0xFF888780))),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      );
}
