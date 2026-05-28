// lib/features/quiz/providers/quiz_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';

// ─── Model classes ────────────────────────────────────────────────────

class QuizQuestion {
  final int id;
  final int order;
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;

  const QuizQuestion({
    required this.id,
    required this.order,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        id: j['id'] as int,
        order: j['order'] as int,
        question: j['question'] as String,
        optionA: j['option_a'] as String,
        optionB: j['option_b'] as String,
        optionC: j['option_c'] as String,
        optionD: j['option_d'] as String,
      );

  String optionText(String key) {
    switch (key) {
      case 'a': return optionA;
      case 'b': return optionB;
      case 'c': return optionC;
      case 'd': return optionD;
      default:  return '';
    }
  }
}

class QuizResult {
  final int questionId;
  final String yourAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final String? explanation;

  const QuizResult({
    required this.questionId,
    required this.yourAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    this.explanation,
  });

  factory QuizResult.fromJson(Map<String, dynamic> j) => QuizResult(
        questionId: j['question_id'] as int,
        yourAnswer: j['your_answer'] as String,
        correctAnswer: j['correct_answer'] as String,
        isCorrect: j['is_correct'] as bool,
        explanation: j['explanation'] as String?,
      );
}

class BestAttempt {
  final int score;
  final int total;
  final int percentage;
  const BestAttempt({required this.score, required this.total, required this.percentage});
}

class QuizData {
  final int id;
  final String title;
  final String quizType;       // 'full' | 'chapter'
  final int? chapterNumber;
  final String? chapterTitle;
  final List<QuizQuestion> questions;
  final BestAttempt? bestAttempt;

  const QuizData({
    required this.id,
    required this.title,
    required this.quizType,
    this.chapterNumber,
    this.chapterTitle,
    required this.questions,
    this.bestAttempt,
  });

  bool get isFullBook => quizType == 'full';

  // Label untuk ditampilkan di UI
  String get typeLabel {
    if (isFullBook) return '📖 Full Buku';
    final num = chapterNumber != null ? 'Bab $chapterNumber' : 'Per Bab';
    final sub = chapterTitle != null ? ': $chapterTitle' : '';
    return '📑 $num$sub';
  }

  factory QuizData.fromJson(Map<String, dynamic> j) {
    BestAttempt? best;
    if (j['best_attempt'] != null) {
      final b = j['best_attempt'] as Map<String, dynamic>;
      best = BestAttempt(
        score: b['score'] as int,
        total: b['total'] as int,
        percentage: b['percentage'] as int,
      );
    }
    return QuizData(
      id: j['id'] as int,
      title: j['title'] as String,
      quizType: j['quiz_type'] as String? ?? 'full',
      chapterNumber: j['chapter_number'] as int?,
      chapterTitle: j['chapter_title'] as String?,
      questions: (j['questions'] as List? ?? [])
          .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      bestAttempt: best,
    );
  }
}

// ─── Phase & State ────────────────────────────────────────────────────

enum QuizPhase {
  loading,      // memuat daftar quiz dari server
  setup,        // layar pilih/buat quiz (belum ada quiz ATAU sudah ada, user pilih aksi)
  generating,   // sedang generate soal dari AI
  intro,        // quiz sudah dipilih, tampilkan info sebelum mulai
  playing,      // sedang mengerjakan soal
  result,       // tampilkan skor
}

class QuizState {
  final QuizPhase phase;

  // Daftar quiz yang sudah ada
  final List<QuizData> savedQuizzes;
  final bool hasFile; // apakah buku punya PDF/EPUB

  // Quiz yang sedang aktif
  final QuizData? activeQuiz;

  // Generate state
  final String generateError;

  // Playing state
  final int currentIndex;
  final Map<int, String> answers;
  final bool isSubmitting;
  final DateTime? startTime;

  // Result state
  final int? score;
  final int? total;
  final int? percentage;
  final List<QuizResult> results;

  const QuizState({
    this.phase = QuizPhase.loading,
    this.savedQuizzes = const [],
    this.hasFile = false,
    this.activeQuiz,
    this.generateError = '',
    this.currentIndex = 0,
    this.answers = const {},
    this.isSubmitting = false,
    this.startTime,
    this.score,
    this.total,
    this.percentage,
    this.results = const [],
  });

  QuizQuestion? get currentQuestion =>
      activeQuiz != null && currentIndex < activeQuiz!.questions.length
          ? activeQuiz!.questions[currentIndex]
          : null;

  bool get isLastQuestion =>
      activeQuiz != null && currentIndex == activeQuiz!.questions.length - 1;

  int get answeredCount => answers.length;

  QuizState copyWith({
    QuizPhase? phase,
    List<QuizData>? savedQuizzes,
    bool? hasFile,
    QuizData? activeQuiz,
    bool clearActiveQuiz = false,
    String? generateError,
    int? currentIndex,
    Map<int, String>? answers,
    bool? isSubmitting,
    DateTime? startTime,
    int? score,
    int? total,
    int? percentage,
    List<QuizResult>? results,
  }) =>
      QuizState(
        phase: phase ?? this.phase,
        savedQuizzes: savedQuizzes ?? this.savedQuizzes,
        hasFile: hasFile ?? this.hasFile,
        activeQuiz: clearActiveQuiz ? null : (activeQuiz ?? this.activeQuiz),
        generateError: generateError ?? this.generateError,
        currentIndex: currentIndex ?? this.currentIndex,
        answers: answers ?? this.answers,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        startTime: startTime ?? this.startTime,
        score: score ?? this.score,
        total: total ?? this.total,
        percentage: percentage ?? this.percentage,
        results: results ?? this.results,
      );
}

// ─── Provider ─────────────────────────────────────────────────────────

final quizProvider =
    StateNotifierProvider.family<QuizNotifier, QuizState, int>(
  (ref, ebookId) => QuizNotifier(ebookId),
);

class QuizNotifier extends StateNotifier<QuizState> {
  final int ebookId;
  QuizNotifier(this.ebookId) : super(const QuizState()) {
    loadQuizList();
  }

  // ── Load daftar quiz yang sudah dibuat user ──────────────────────
  Future<void> loadQuizList() async {
    state = state.copyWith(phase: QuizPhase.loading);
    try {
      final res = await ApiService.dio.get(ApiConstants.quizList(ebookId));
      final data = res.data as Map<String, dynamic>;

      final quizzes = (data['quizzes'] as List? ?? [])
          .map((q) => QuizData.fromJson(q as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        phase: QuizPhase.setup,
        savedQuizzes: quizzes,
        hasFile: data['has_file'] as bool? ?? false,
        generateError: '',
      );
    } catch (_) {
      state = state.copyWith(phase: QuizPhase.setup, savedQuizzes: []);
    }
  }

  // ── Generate quiz baru ───────────────────────────────────────────
  Future<void> generateQuiz({
    required String quizType,   // 'full' | 'chapter'
    required int questionCount,
    int? chapterNumber,
    String? chapterTitle,
  }) async {
    state = state.copyWith(phase: QuizPhase.generating, generateError: '');
    try {
      final body = <String, dynamic>{
        'quiz_type':      quizType,
        'question_count': questionCount,
      };
      if (quizType == 'chapter' && chapterNumber != null) {
        body['chapter_number'] = chapterNumber;
        if (chapterTitle != null && chapterTitle.isNotEmpty) {
          body['chapter_title'] = chapterTitle;
        }
      }

      final res = await ApiService.dio.post(
        ApiConstants.quizGenerate(ebookId),
        data: body,
      );
      final data = res.data as Map<String, dynamic>;

      if (data['success'] == true) {
        final newQuiz = QuizData.fromJson(data['quiz'] as Map<String, dynamic>);
        // Tambahkan ke daftar dan langsung masuk intro
        final updated = [newQuiz, ...state.savedQuizzes];
        state = state.copyWith(
          phase: QuizPhase.intro,
          savedQuizzes: updated,
          activeQuiz: newQuiz,
          generateError: '',
        );
      } else {
        state = state.copyWith(
          phase: QuizPhase.setup,
          generateError: data['error'] as String? ?? 'Gagal generate soal.',
        );
      }
    } catch (e) {
      final errMsg = e.toString().contains('422')
          ? 'Buku belum memiliki file PDF/EPUB.'
          : 'Gagal generate soal. Coba lagi.';
      state = state.copyWith(
        phase: QuizPhase.setup,
        generateError: errMsg,
      );
    }
  }

  // ── Pilih quiz yang sudah ada untuk dimulai ──────────────────────
  void selectQuiz(QuizData quiz) {
    state = state.copyWith(
      phase: QuizPhase.intro,
      activeQuiz: quiz,
      generateError: '',
    );
  }

  // ── Kembali ke layar setup ───────────────────────────────────────
  void backToSetup() {
    state = state.copyWith(
      phase: QuizPhase.setup,
      clearActiveQuiz: true,
      generateError: '',
    );
  }

  // ── Mulai mengerjakan quiz ───────────────────────────────────────
  void startQuiz() {
    state = state.copyWith(
      phase: QuizPhase.playing,
      currentIndex: 0,
      answers: {},
      startTime: DateTime.now(),
    );
  }

  // ── Pilih jawaban ────────────────────────────────────────────────
  void selectAnswer(int questionId, String answer) {
    final updated = Map<int, String>.from(state.answers);
    updated[questionId] = answer;
    state = state.copyWith(answers: updated);
  }

  void nextQuestion() {
    if (!state.isLastQuestion) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  void prevQuestion() {
    if (state.currentIndex > 0) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    }
  }

  // ── Submit jawaban ke server ─────────────────────────────────────
  Future<void> submitQuiz() async {
    if (state.activeQuiz == null || state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true);

    final duration = state.startTime != null
        ? DateTime.now().difference(state.startTime!).inSeconds
        : null;

    final answers = state.answers.entries
        .map((e) => {'question_id': e.key, 'answer': e.value})
        .toList();

    try {
      final res = await ApiService.dio.post(
        ApiConstants.quizSubmit(ebookId),
        data: {
          'quiz_id':          state.activeQuiz!.id,
          'answers':          answers,
          'duration_seconds': duration,
        },
      );
      final data = res.data as Map<String, dynamic>;

      final results = (data['results'] as List)
          .map((r) => QuizResult.fromJson(r as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        phase: QuizPhase.result,
        score: data['score'] as int,
        total: data['total'] as int,
        percentage: data['percentage'] as int,
        results: results,
        isSubmitting: false,
      );
    } catch (_) {
      state = state.copyWith(isSubmitting: false);
    }
  }

  // ── Hapus quiz dari daftar ───────────────────────────────────────
  Future<void> deleteQuiz(int quizId) async {
    try {
      await ApiService.dio.delete(ApiConstants.quizDelete(ebookId, quizId));
      final updated = state.savedQuizzes.where((q) => q.id != quizId).toList();
      state = state.copyWith(savedQuizzes: updated);
    } catch (_) {
      // silent fail — UI bisa tampilkan snackbar sendiri
      rethrow;
    }
  }

  // ── Ulangi quiz yang sama ────────────────────────────────────────
  void retryQuiz() => startQuiz();

  // ── Kembali ke setup untuk buat/pilih quiz lain ──────────────────
  void chooseAnotherQuiz() => backToSetup();
}
