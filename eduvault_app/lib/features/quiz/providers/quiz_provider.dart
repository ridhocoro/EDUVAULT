// lib/features/quiz/providers/quiz_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';

// ── Data classes ────────────────────────────────────────────────────

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
      default: return '';
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

  const BestAttempt(
      {required this.score, required this.total, required this.percentage});
}

class QuizData {
  final int id;
  final String title;
  final List<QuizQuestion> questions;

  const QuizData(
      {required this.id, required this.title, required this.questions});
}

enum QuizPhase { loading, notAvailable, intro, playing, result }

class QuizState {
  final QuizPhase phase;
  final QuizData? quiz;
  final BestAttempt? bestAttempt;

  // Playing state
  final int currentIndex;
  final Map<int, String> answers; // questionId → pilihan user
  final bool isSubmitting;
  final DateTime? startTime;

  // Result state
  final int? score;
  final int? total;
  final int? percentage;
  final List<QuizResult> results;

  const QuizState({
    this.phase = QuizPhase.loading,
    this.quiz,
    this.bestAttempt,
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
      quiz != null && currentIndex < quiz!.questions.length
          ? quiz!.questions[currentIndex]
          : null;

  bool get isLastQuestion =>
      quiz != null && currentIndex == quiz!.questions.length - 1;

  int get answeredCount => answers.length;

  QuizState copyWith({
    QuizPhase? phase,
    QuizData? quiz,
    BestAttempt? bestAttempt,
    int? currentIndex,
    Map<int, String>? answers,
    bool? isSubmitting,
    DateTime? startTime,
    int? score,
    int? total,
    int? percentage,
    List<QuizResult>? results,
  }) {
    return QuizState(
      phase: phase ?? this.phase,
      quiz: quiz ?? this.quiz,
      bestAttempt: bestAttempt ?? this.bestAttempt,
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
}

// ── Provider ────────────────────────────────────────────────────────

final quizProvider =
    StateNotifierProvider.family<QuizNotifier, QuizState, int>(
  (ref, ebookId) => QuizNotifier(ebookId),
);

class QuizNotifier extends StateNotifier<QuizState> {
  final int ebookId;

  QuizNotifier(this.ebookId) : super(const QuizState()) {
    loadQuiz();
  }

  Future<void> loadQuiz() async {
    state = state.copyWith(phase: QuizPhase.loading);
    try {
      final res =
          await ApiService.dio.get(ApiConstants.quiz(ebookId));
      final data = res.data as Map<String, dynamic>;

      if (data['available'] != true || data['quiz'] == null) {
        state = state.copyWith(phase: QuizPhase.notAvailable);
        return;
      }

      final quizData = data['quiz'] as Map<String, dynamic>;
      final quiz = QuizData(
        id: quizData['id'] as int,
        title: quizData['title'] as String,
        questions: (quizData['questions'] as List)
            .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );

      BestAttempt? best;
      if (data['best_attempt'] != null) {
        final b = data['best_attempt'] as Map<String, dynamic>;
        best = BestAttempt(
          score: b['score'] as int,
          total: b['total'] as int,
          percentage: b['percentage'] as int,
        );
      }

      state = state.copyWith(
        phase: QuizPhase.intro,
        quiz: quiz,
        bestAttempt: best,
      );
    } catch (_) {
      state = state.copyWith(phase: QuizPhase.notAvailable);
    }
  }

  void startQuiz() {
    state = state.copyWith(
      phase: QuizPhase.playing,
      currentIndex: 0,
      answers: {},
      startTime: DateTime.now(),
    );
  }

  void selectAnswer(int questionId, String answer) {
    final newAnswers = Map<int, String>.from(state.answers);
    newAnswers[questionId] = answer;
    state = state.copyWith(answers: newAnswers);
  }

  void nextQuestion() {
    if (state.isLastQuestion) return;
    state = state.copyWith(currentIndex: state.currentIndex + 1);
  }

  void prevQuestion() {
    if (state.currentIndex == 0) return;
    state = state.copyWith(currentIndex: state.currentIndex - 1);
  }

  Future<void> submitQuiz() async {
    if (state.quiz == null || state.isSubmitting) return;
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
          'quiz_id': state.quiz!.id,
          'answers': answers,
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

  void retryQuiz() => startQuiz();
}
