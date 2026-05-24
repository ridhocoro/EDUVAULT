// lib/features/trial_chat/providers/trial_chat_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';

// ── Data classes ────────────────────────────────────────────────────

class TrialChatMessage {
  final String text;
  final bool isUser;
  final bool isLoading;

  const TrialChatMessage({
    required this.text,
    required this.isUser,
    this.isLoading = false,
  });
}

class TrialChatState {
  final List<TrialChatMessage> messages;
  final int used;
  final int max;
  final bool isLoading;
  final bool isSending;

  const TrialChatState({
    this.messages = const [],
    this.used = 0,
    this.max = 3,
    this.isLoading = false,
    this.isSending = false,
  });

  int get remaining => (max - used).clamp(0, max);
  bool get exhausted => used >= max;

  TrialChatState copyWith({
    List<TrialChatMessage>? messages,
    int? used,
    int? max,
    bool? isLoading,
    bool? isSending,
  }) {
    return TrialChatState(
      messages: messages ?? this.messages,
      used: used ?? this.used,
      max: max ?? this.max,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
    );
  }
}

// ── Provider (family = satu instance per ebookId) ───────────────────

final trialChatProvider =
    StateNotifierProvider.family<TrialChatNotifier, TrialChatState, int>(
  (ref, ebookId) => TrialChatNotifier(ebookId),
);

class TrialChatNotifier extends StateNotifier<TrialChatState> {
  final int ebookId;

  TrialChatNotifier(this.ebookId) : super(const TrialChatState());

  /// Load riwayat chat + status trial dari server
  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await ApiService.dio
          .get(ApiConstants.trialChatHistory(ebookId));
      final data = res.data as Map<String, dynamic>;

      final history = (data['history'] as List? ?? [])
          .expand<TrialChatMessage>((item) => [
                TrialChatMessage(
                    text: item['message'] as String, isUser: true),
                TrialChatMessage(
                    text: item['response'] as String, isUser: false),
              ])
          .toList();

      state = state.copyWith(
        messages: history,
        used: data['used'] as int? ?? 0,
        max: data['max'] as int? ?? 3,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Kirim pertanyaan ke API trial chat
  Future<void> sendMessage(String text) async {
    if (state.exhausted || state.isSending) return;

    // Tambah pesan user + bubble loading AI
    final userMsg = TrialChatMessage(text: text, isUser: true);
    final loadingMsg =
        const TrialChatMessage(text: '', isUser: false, isLoading: true);

    state = state.copyWith(
      messages: [...state.messages, userMsg, loadingMsg],
      isSending: true,
    );

    try {
      final res = await ApiService.dio.post(
        ApiConstants.trialChat(ebookId),
        data: {'message': text},
      );
      final data = res.data as Map<String, dynamic>;

      if (data['success'] == true) {
        final aiMsg = TrialChatMessage(
          text: data['response'] as String,
          isUser: false,
        );

        // Hapus loading bubble, ganti dengan respons AI
        final newMessages = [...state.messages]..removeLast();
        newMessages.add(aiMsg);

        state = state.copyWith(
          messages: newMessages,
          used: data['used'] as int? ?? state.used + 1,
          max: data['max'] as int? ?? state.max,
          isSending: false,
        );
      } else {
        _removeLoadingAndSetSending();
      }
    } catch (_) {
      _removeLoadingAndSetSending();
    }
  }

  void _removeLoadingAndSetSending() {
    final newMessages = [...state.messages]..removeLast();
    state = state.copyWith(messages: newMessages, isSending: false);
  }
}
