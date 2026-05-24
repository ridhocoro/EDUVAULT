// lib/features/trial_chat/screens/trial_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trial_chat_provider.dart';

class TrialChatScreen extends ConsumerStatefulWidget {
  final int ebookId;
  final String bookTitle;
  final String? bookCover;

  const TrialChatScreen({
    super.key,
    required this.ebookId,
    required this.bookTitle,
    this.bookCover,
  });

  @override
  ConsumerState<TrialChatScreen> createState() => _TrialChatScreenState();
}

class _TrialChatScreenState extends ConsumerState<TrialChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load history & status saat buka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trialChatProvider(widget.ebookId).notifier).loadHistory();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    await ref
        .read(trialChatProvider(widget.ebookId).notifier)
        .sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trialChatProvider(widget.ebookId));

    // Auto scroll saat ada pesan baru
    if (state.messages.isNotEmpty) _scrollToBottom();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF1A1A2E)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Coba Tanya AI',
              style: TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            Text(
              widget.bookTitle,
              style: const TextStyle(color: Color(0xFF888780), fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Counter sisa trial
          if (!state.isLoading)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: state.exhausted
                    ? const Color(0xFFFFE5E5)
                    : const Color(0xFFE1F5EE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                state.exhausted
                    ? 'Habis'
                    : '${state.remaining}/${state.max} sisa',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: state.exhausted
                      ? const Color(0xFFD32F2F)
                      : const Color(0xFF0F6E56),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Banner info trial
          _TrialBanner(
            remaining: state.remaining,
            max: state.max,
            exhausted: state.exhausted,
          ),

          // Chat messages
          Expanded(
            child: state.isLoading && state.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                    ? _EmptyState(bookTitle: widget.bookTitle)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: state.messages.length,
                        itemBuilder: (_, i) => _ChatBubble(
                          message: state.messages[i],
                        ),
                      ),
          ),

          // Input area
          _InputArea(
            controller: _controller,
            isSending: state.isSending,
            exhausted: state.exhausted,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ── Banner info sisa trial ──────────────────────────────────────────

class _TrialBanner extends StatelessWidget {
  final int remaining;
  final int max;
  final bool exhausted;

  const _TrialBanner({
    required this.remaining,
    required this.max,
    required this.exhausted,
  });

  @override
  Widget build(BuildContext context) {
    if (exhausted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFFFFEBEB),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 16, color: Color(0xFFD32F2F)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Trial AI sudah habis. Beli buku ini untuk bertanya tanpa batas!',
                style: TextStyle(fontSize: 12, color: Color(0xFFD32F2F)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFF0FBF7),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF1D9E75)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mode Trial — Kamu bisa bertanya $remaining kali lagi tentang buku ini.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F6E56)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String bookTitle;
  const _EmptyState({required this.bookTitle});

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      'Apa topik utama buku ini?',
      'Cocok untuk siapa buku ini?',
      'Apa yang bisa saya pelajari dari buku ini?',
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE1F5EE),
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(Icons.auto_awesome,
                size: 32, color: Color(0xFF1D9E75)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Coba Tanya AI',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 8),
          Text(
            'Punya pertanyaan tentang "$bookTitle"? Tanya AI dulu sebelum memutuskan membeli.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF888780)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Contoh pertanyaan:',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5F5E5A)),
          ),
          const SizedBox(height: 12),
          ...suggestions.map((s) => _SuggestionChip(text: s)),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  const _SuggestionChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E6DF)),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 13, color: Color(0xFF5F5E5A))),
    );
  }
}

// ── Chat bubble ─────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final TrialChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF1D9E75),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF1D9E75)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: message.isLoading
                  ? const _TypingIndicator()
                  : Text(
                      message.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: isUser
                            ? Colors.white
                            : const Color(0xFF1A1A2E),
                        height: 1.5,
                      ),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(delay: 0),
          SizedBox(width: 4),
          _Dot(delay: 150),
          SizedBox(width: 4),
          _Dot(delay: 300),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF888780),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Input area ──────────────────────────────────────────────────────

class _InputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final bool exhausted;
  final VoidCallback onSend;

  const _InputArea({
    required this.controller,
    required this.isSending,
    required this.exhausted,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8E6DF))),
      ),
      child: exhausted
          ? SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Beli Buku untuk Akses Penuh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isSending,
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: 'Tanya tentang buku ini...',
                      hintStyle: const TextStyle(
                          color: Color(0xFFBBB9B4), fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFFF8F7F4),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: isSending
                      ? const SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1D9E75)),
                            ),
                          ),
                        )
                      : Material(
                          color: const Color(0xFF1D9E75),
                          borderRadius: BorderRadius.circular(22),
                          child: InkWell(
                            onTap: onSend,
                            borderRadius: BorderRadius.circular(22),
                            child: const SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(Icons.send_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
