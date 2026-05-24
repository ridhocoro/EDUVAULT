// lib/features/admin/screens/quiz_management_screen.dart
//
// Screen ini dipanggil dari admin_dashboard_screen.dart
// Tambahkan navigasi ke sini dari list ebook di admin dashboard.
//
// Cara integrasi di admin_dashboard_screen.dart:
// Tambahkan tombol/icon pada setiap item ebook di admin list:
//
//   IconButton(
//     icon: const Icon(Icons.quiz_outlined),
//     tooltip: 'Kelola Quiz',
//     onPressed: () => Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => QuizManagementScreen(
//           ebookId: ebook.id,
//           ebookTitle: ebook.title,
//         ),
//       ),
//     ),
//   )

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';

// ── Data classes ─────────────────────────────────────────────────────

class AdminQuizQuestion {
  final int id;
  final int order;
  String question;
  String optionA;
  String optionB;
  String optionC;
  String optionD;
  String correctAnswer;
  String? explanation;

  AdminQuizQuestion({
    required this.id,
    required this.order,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctAnswer,
    this.explanation,
  });

  factory AdminQuizQuestion.fromJson(Map<String, dynamic> j) =>
      AdminQuizQuestion(
        id: j['id'] as int,
        order: j['order'] as int,
        question: j['question'] as String,
        optionA: j['option_a'] as String,
        optionB: j['option_b'] as String,
        optionC: j['option_c'] as String,
        optionD: j['option_d'] as String,
        correctAnswer: j['correct_answer'] as String,
        explanation: j['explanation'] as String?,
      );
}

class AdminQuizData {
  final int id;
  final String title;
  final String status;
  final List<AdminQuizQuestion> questions;

  const AdminQuizData({
    required this.id,
    required this.title,
    required this.status,
    required this.questions,
  });

  factory AdminQuizData.fromJson(Map<String, dynamic> j) => AdminQuizData(
        id: j['id'] as int,
        title: j['title'] as String,
        status: j['status'] as String,
        questions: (j['questions'] as List? ?? [])
            .map((q) =>
                AdminQuizQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );

  bool get isPublished => status == 'published';
}

// ── Screen ───────────────────────────────────────────────────────────

class QuizManagementScreen extends ConsumerStatefulWidget {
  final int ebookId;
  final String ebookTitle;

  const QuizManagementScreen({
    super.key,
    required this.ebookId,
    required this.ebookTitle,
  });

  @override
  ConsumerState<QuizManagementScreen> createState() =>
      _QuizManagementScreenState();
}

class _QuizManagementScreenState
    extends ConsumerState<QuizManagementScreen> {
  AdminQuizData? _quiz;
  bool _loading = true;
  bool _generating = false;
  bool _publishing = false;
  int _questionCount = 10;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.dio
          .get(ApiConstants.adminQuiz(widget.ebookId));
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _quiz = data['quiz'] != null
            ? AdminQuizData.fromJson(data['quiz'] as Map<String, dynamic>)
            : null;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final res = await ApiService.dio.post(
        ApiConstants.adminQuizGenerate(widget.ebookId),
        data: {'question_count': _questionCount},
      );
      final data = res.data as Map<String, dynamic>;
      if (data['success'] == true) {
        _showSnack('✅ ${data['message']}');
        await _loadQuiz();
      }
    } catch (e) {
      _showSnack('❌ Gagal generate soal');
    } finally {
      setState(() => _generating = false);
    }
  }

  Future<void> _publish() async {
    if (_quiz == null) return;
    setState(() => _publishing = true);
    try {
      await ApiService.dio
          .patch(ApiConstants.adminQuizPublish(_quiz!.id));
      _showSnack('✅ Quiz berhasil dipublish!');
      await _loadQuiz();
    } catch (_) {
      _showSnack('❌ Gagal publish quiz');
    } finally {
      setState(() => _publishing = false);
    }
  }

  Future<void> _deleteQuiz() async {
    if (_quiz == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Quiz?'),
        content:
            const Text('Semua soal dan riwayat jawaban akan terhapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus',
                style: TextStyle(color: Color(0xFFD32F2F))),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService.dio
          .delete(ApiConstants.adminQuizDelete(_quiz!.id));
      _showSnack('Quiz dihapus');
      setState(() => _quiz = null);
    } catch (_) {
      _showSnack('❌ Gagal menghapus');
    }
  }

  void _openEditQuestion(AdminQuizQuestion q) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EditQuestionScreen(
          question: q,
          onSaved: _loadQuiz,
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF1A1A2E)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kelola Quiz',
                style: TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            Text(widget.ebookTitle,
                style: const TextStyle(
                    color: Color(0xFF888780), fontSize: 11),
                overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          if (_quiz != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFD32F2F)),
              onPressed: _deleteQuiz,
              tooltip: 'Hapus Quiz',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Generate Panel ──────────────────────────────
                  _SectionCard(
                    title: _quiz == null
                        ? '🤖 Generate Quiz dengan AI'
                        : '🔄 Regenerate Quiz',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI akan membuat soal quiz otomatis berdasarkan deskripsi buku.',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF5F5E5A)),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Jumlah soal:',
                                style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 12),
                            DropdownButton<int>(
                              value: _questionCount,
                              items: [5, 10, 15, 20]
                                  .map((n) => DropdownMenuItem(
                                      value: n, child: Text('$n soal')))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _questionCount = v!),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _generating ? null : _generate,
                            icon: _generating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Icon(Icons.auto_awesome),
                            label: Text(_generating
                                ? 'Generating...'
                                : 'Generate Soal'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D9E75),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_quiz != null) ...[
                    const SizedBox(height: 16),

                    // ── Status Panel ────────────────────────────
                    _SectionCard(
                      title: 'Status Quiz',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _quiz!.isPublished
                                  ? const Color(0xFFE1F5EE)
                                  : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _quiz!.isPublished
                                  ? '✅ Published'
                                  : '📝 Draft',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _quiz!.isPublished
                                    ? const Color(0xFF0F6E56)
                                    : const Color(0xFFF57C00),
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (!_quiz!.isPublished)
                            ElevatedButton(
                              onPressed: _publishing ? null : _publish,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF1D9E75),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8)),
                              ),
                              child: _publishing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Text('Publish'),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Questions List ──────────────────────────
                    Text(
                      'Daftar Soal (${_quiz!.questions.length})',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E)),
                    ),
                    const SizedBox(height: 8),

                    ..._quiz!.questions.map((q) => _QuestionTile(
                          question: q,
                          onEdit: () => _openEditQuestion(q),
                        )),
                  ],
                ],
              ),
            ),
    );
  }
}

// ── Section Card ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Question Tile ────────────────────────────────────────────────────

class _QuestionTile extends StatelessWidget {
  final AdminQuizQuestion question;
  final VoidCallback onEdit;

  const _QuestionTile({required this.question, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E6DF)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFE1F5EE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${question.order}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F6E56)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.question,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Jawaban: ${question.correctAnswer.toUpperCase()}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1D9E75),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: Color(0xFF888780)),
            onPressed: onEdit,
            tooltip: 'Edit soal',
          ),
        ],
      ),
    );
  }
}

// ── Edit Question Screen ─────────────────────────────────────────────

class _EditQuestionScreen extends StatefulWidget {
  final AdminQuizQuestion question;
  final VoidCallback onSaved;

  const _EditQuestionScreen(
      {required this.question, required this.onSaved});

  @override
  State<_EditQuestionScreen> createState() => _EditQuestionScreenState();
}

class _EditQuestionScreenState extends State<_EditQuestionScreen> {
  late final TextEditingController _qCtrl;
  late final TextEditingController _aCtrl;
  late final TextEditingController _bCtrl;
  late final TextEditingController _cCtrl;
  late final TextEditingController _dCtrl;
  late final TextEditingController _expCtrl;
  late String _correct;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _qCtrl = TextEditingController(text: q.question);
    _aCtrl = TextEditingController(text: q.optionA);
    _bCtrl = TextEditingController(text: q.optionB);
    _cCtrl = TextEditingController(text: q.optionC);
    _dCtrl = TextEditingController(text: q.optionD);
    _expCtrl = TextEditingController(text: q.explanation ?? '');
    _correct = q.correctAnswer;
  }

  @override
  void dispose() {
    for (final c in [_qCtrl, _aCtrl, _bCtrl, _cCtrl, _dCtrl, _expCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.dio.put(
        ApiConstants.adminQuizQuestion(widget.question.id),
        data: {
          'question': _qCtrl.text.trim(),
          'option_a': _aCtrl.text.trim(),
          'option_b': _bCtrl.text.trim(),
          'option_c': _cCtrl.text.trim(),
          'option_d': _dCtrl.text.trim(),
          'correct_answer': _correct,
          'explanation': _expCtrl.text.trim(),
        },
      );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Gagal menyimpan')),
        );
      }
    } finally {
      setState(() => _saving = false);
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
        title: Text(
          'Edit Soal ${widget.question.order}',
          style: const TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Simpan',
                    style: TextStyle(
                        color: Color(0xFF1D9E75),
                        fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Field(label: 'Pertanyaan', controller: _qCtrl, maxLines: 3),
            _Field(label: 'Pilihan A', controller: _aCtrl),
            _Field(label: 'Pilihan B', controller: _bCtrl),
            _Field(label: 'Pilihan C', controller: _cCtrl),
            _Field(label: 'Pilihan D', controller: _dCtrl),
            const SizedBox(height: 4),
            const Text('Jawaban Benar',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            Row(
              children: ['a', 'b', 'c', 'd'].map((key) {
                final selected = _correct == key;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _correct = key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF1D9E75)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF1D9E75)
                              : const Color(0xFFE8E6DF),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          key.toUpperCase(),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF888780)),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            _Field(
                label: 'Penjelasan (opsional)',
                controller: _expCtrl,
                maxLines: 3),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;

  const _Field(
      {required this.label,
      required this.controller,
      this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE8E6DF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE8E6DF)),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
