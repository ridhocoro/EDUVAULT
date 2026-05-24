// lib/features/quiz/screens/quiz_screen.dart

import 'package:flutter/material.dart';
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
    final state = ref.watch(quizProvider(ebookId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      body: switch (state.phase) {
        QuizPhase.loading     => _buildLoading(),
        QuizPhase.notAvailable => _buildNotAvailable(context),
        QuizPhase.intro       => _buildIntro(context, ref, state),
        QuizPhase.playing     => _buildPlaying(context, ref, state),
        QuizPhase.result      => _buildResult(context, ref, state),
      },
    );
  }

  // ── Loading ──────────────────────────────────────────────────────

  Widget _buildLoading() => const Scaffold(
        backgroundColor: Color(0xFFF8F7F4),
        body: Center(child: CircularProgressIndicator()),
      );

  // ── Not Available ────────────────────────────────────────────────

  Widget _buildNotAvailable(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8F7F4),
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: BackButton(
              color: const Color(0xFF1A1A2E),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Quiz',
              style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 16)),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E6DF),
                    borderRadius: BorderRadius.circular(36),
                  ),
                  child: const Icon(Icons.quiz_outlined,
                      size: 36, color: Color(0xFF888780)),
                ),
                const SizedBox(height: 20),
                const Text('Quiz Belum Tersedia',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E))),
                const SizedBox(height: 8),
                const Text(
                  'Quiz untuk buku ini sedang disiapkan. Coba lagi nanti.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF888780)),
                ),
              ],
            ),
          ),
        ),
      );

  // ── Intro ────────────────────────────────────────────────────────

  Widget _buildIntro(
      BuildContext context, WidgetRef ref, QuizState state) {
    final quiz = state.quiz!;
    final best = state.bestAttempt;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: BackButton(
            color: const Color(0xFF1A1A2E),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Quiz',
            style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 16)),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
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
                  const Icon(Icons.quiz_rounded,
                      color: Colors.white70, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    quiz.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bookTitle,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stats
            Row(
              children: [
                _StatCard(
                  icon: Icons.help_outline,
                  label: 'Soal',
                  value: '${quiz.questions.length}',
                  color: const Color(0xFF1D9E75),
                ),
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
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F5EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Color(0xFF1D9E75), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Skor terbaikmu: ${best.score}/${best.total} (${best.percentage}%)',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF0F6E56)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Text(
              'Petunjuk',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 8),
            ...[
              '✅  Pilih satu jawaban untuk setiap soal',
              '⏱️  Tidak ada batas waktu, santai saja',
              '💡  Setelah selesai, kamu bisa melihat penjelasan tiap soal',
              '🔄  Bisa diulang berkali-kali untuk latihan',
            ].map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(t,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF5F5E5A))),
                )),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    ref.read(quizProvider(ebookId).notifier).startQuiz(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  best != null ? '🔄  Coba Lagi' : '🚀  Mulai Quiz',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Playing ──────────────────────────────────────────────────────

  Widget _buildPlaying(
      BuildContext context, WidgetRef ref, QuizState state) {
    final question = state.currentQuestion!;
    final total = state.quiz!.questions.length;
    final selectedAnswer = state.answers[question.id];
    final notifier = ref.read(quizProvider(ebookId).notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A1A2E)),
          onPressed: () => _showQuitDialog(context, ref),
        ),
        title: Text(
          '${state.currentIndex + 1} dari $total',
          style: const TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress bar gaya Duolingo
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (state.currentIndex + 1) / total,
                minHeight: 8,
                backgroundColor: const Color(0xFFE8E6DF),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF1D9E75)),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nomor soal badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F5EE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Soal ${state.currentIndex + 1}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0F6E56),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pertanyaan
                  Text(
                    question.question,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pilihan jawaban
                  ...['a', 'b', 'c', 'd'].map((key) => _OptionTile(
                        optionKey: key,
                        text: question.optionText(key),
                        isSelected: selectedAnswer == key,
                        onTap: () =>
                            notifier.selectAnswer(question.id, key),
                      )),
                ],
              ),
            ),
          ),

          // Bottom nav
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            color: Colors.white,
            child: Row(
              children: [
                if (state.currentIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: notifier.prevQuestion,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE8E6DF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('← Sebelumnya',
                          style: TextStyle(color: Color(0xFF5F5E5A))),
                    ),
                  ),
                if (state.currentIndex > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: selectedAnswer == null
                        ? null
                        : state.isLastQuestion
                            ? () => notifier.submitQuiz()
                            : notifier.nextQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D9E75),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE8E6DF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: state.isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            state.isLastQuestion
                                ? 'Selesai & Lihat Skor'
                                : 'Selanjutnya →',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
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

  // ── Result ───────────────────────────────────────────────────────

  Widget _buildResult(
      BuildContext context, WidgetRef ref, QuizState state) {
    final score = state.score ?? 0;
    final total = state.total ?? 1;
    final pct = state.percentage ?? 0;

    final (emoji, message, color) = switch (pct) {
      >= 90 => ('🏆', 'Luar Biasa!', const Color(0xFFF4A025)),
      >= 70 => ('🎉', 'Bagus Sekali!', const Color(0xFF1D9E75)),
      >= 50 => ('👍', 'Cukup Baik!', const Color(0xFF2196F3)),
      _     => ('💪', 'Terus Berlatih!', const Color(0xFFEF5350)),
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(
            color: const Color(0xFF1A1A2E),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Hasil Quiz',
            style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 16)),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 56)),
                  const SizedBox(height: 8),
                  Text(message,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: color)),
                  const SizedBox(height: 16),
                  // Donut progress
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
                            valueColor:
                                AlwaysStoppedAnimation(color),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$pct%',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: color),
                              ),
                              Text(
                                '$score/$total',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF888780)),
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

            const SizedBox(height: 20),

            // Pembahasan tiap soal
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pembahasan',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E)),
              ),
            ),
            const SizedBox(height: 12),

            ...state.results.asMap().entries.map((entry) {
              final i = entry.key;
              final result = entry.value;
              final question = state.quiz!.questions
                  .firstWhere((q) => q.id == result.questionId);

              return _ResultCard(
                index: i,
                question: question,
                result: result,
              );
            }),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF1D9E75)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Kembali',
                        style: TextStyle(color: Color(0xFF1D9E75))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        ref.read(quizProvider(ebookId).notifier).retryQuiz(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D9E75),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('🔄 Coba Lagi',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────

  void _showQuitDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar Quiz?'),
        content: const Text('Progresmu akan hilang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Lanjut Quiz'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // tutup dialog
              Navigator.pop(context); // keluar quiz
            },
            child: const Text('Keluar',
                style: TextStyle(color: Color(0xFFD32F2F))),
          ),
        ],
      ),
    );
  }
}

// ── Option Tile ─────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final String optionKey;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.optionKey,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE1F5EE)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1D9E75)
                : const Color(0xFFE8E6DF),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1D9E75)
                    : const Color(0xFFF0EFE9),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  optionKey.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF888780),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected
                      ? const Color(0xFF0F6E56)
                      : const Color(0xFF1A1A2E),
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat Card ───────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF888780))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Result Card ─────────────────────────────────────────────────────

class _ResultCard extends StatefulWidget {
  final int index;
  final QuizQuestion question;
  final QuizResult result;

  const _ResultCard({
    required this.index,
    required this.question,
    required this.result,
  });

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
          color: isCorrect
              ? const Color(0xFF1D9E75).withOpacity(0.3)
              : const Color(0xFFEF5350).withOpacity(0.3),
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
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? const Color(0xFFE1F5EE)
                          : const Color(0xFFFFEBEB),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCorrect ? Icons.check : Icons.close,
                      size: 14,
                      color: isCorrect
                          ? const Color(0xFF1D9E75)
                          : const Color(0xFFEF5350),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Soal ${widget.index + 1}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E)),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF888780),
                    size: 20,
                  ),
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
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 8),
                  _AnswerRow(
                    label: 'Jawabanmu',
                    value: '${widget.result.yourAnswer.toUpperCase()}. ${widget.question.optionText(widget.result.yourAnswer)}',
                    color: isCorrect
                        ? const Color(0xFF1D9E75)
                        : const Color(0xFFEF5350),
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
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F7F4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💡 Penjelasan',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5F5E5A))),
                          const SizedBox(height: 4),
                          Text(
                            widget.result.explanation!,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF5F5E5A)),
                          ),
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

  const _AnswerRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ',
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF888780))),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
