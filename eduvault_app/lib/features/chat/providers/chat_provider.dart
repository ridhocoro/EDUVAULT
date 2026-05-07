// lib/features/chat/providers/chat_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eduvault_app/core/services/api_service.dart';
import 'package:eduvault_app/features/chat/models/chat_model.dart';
import 'package:eduvault_app/core/constants/api_constants.dart';

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});

class ChatState {
  final List<ChatMessage> messages;
  final bool isSending;
  final String? error;

  ChatState({
    this.messages = const [],
    this.isSending = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      error: error ?? this.error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(ChatState());

  Future<void> sendMessage({
    required int bookId,
    required String message,
  }) async {
    // Tambahkan pesan user
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: message,
      isUser: true,
      timestamp: DateTime.now(),
    );

    // Tambahkan loading indicator
    final loadingMessage = ChatMessage(
      id: 'loading_${DateTime.now().millisecondsSinceEpoch}',
      content: '',
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage, loadingMessage],
      isSending: true,
      error: null,
    );

    try {
      final dio = ApiService.dio;
      final response = await dio.post(
        ApiConstants.chat(bookId),
        data: {
          'message': message,
        },
      );

      final aiResponse = response.data['response'] as String;

      // Hapus loading message dan tambah response AI
      final newMessages = List<ChatMessage>.from(state.messages)
        ..removeWhere((msg) => msg.id == loadingMessage.id);

      final aiMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: aiResponse,
        isUser: false,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...newMessages, aiMessage],
        isSending: false,
      );
    } catch (e) {
      // Hapus loading message
      final newMessages = List<ChatMessage>.from(state.messages)
        ..removeWhere((msg) => msg.id == loadingMessage.id);

      state = state.copyWith(
        messages: newMessages,
        isSending: false,
        error: e.toString(),
      );
    }
  }

  void clearMessages() {
    state = ChatState();
  }
}