import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/review_provider.dart';
import '../models/review_model.dart';
import '../../auth/providers/auth_provider.dart';

class ReviewsSection extends ConsumerStatefulWidget {
  final int ebookId;
  final bool owned; // apakah user sudah beli buku ini

  const ReviewsSection({
    super.key,
    required this.ebookId,
    required this.owned,
  });

  @override
  ConsumerState<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends ConsumerState<ReviewsSection> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(reviewProvider(widget.ebookId).notifier).loadReviews(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(reviewProvider(widget.ebookId));
    final auth     = ref.watch(authProvider);
    final isLoggedIn = auth.isLoggedIn;

    // Cek apakah user sudah punya review
    final myReview = isLoggedIn
        ? state.reviews.where((r) => r.userId == auth.user?.id).firstOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────
        Row(
          children: [
            const Text(
              'Ulasan Pembaca',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const Spacer(),
            if (state.totalReviews > 0) ...[
              const Icon(Icons.star_rounded,
                  size: 16, color: Color(0xFFF5A623)),
              const SizedBox(width: 4),
              Text(
                '${state.averageRating ?? '-'} (${state.totalReviews})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ── Rating summary bar ───────────────────────────────────
        if (state.totalReviews > 0) ...[
          _RatingBar(reviews: state.reviews),
          const SizedBox(height: 16),
        ],

        // ── Write review button / hint ───────────────────────────
        if (widget.owned && isLoggedIn) ...[
          _WriteReviewButton(
            ebookId: widget.ebookId,
            existingReview: myReview,
          ),
          const SizedBox(height: 16),
        ] else if (!isLoggedIn) ...[
          // Guest: bisa lihat ulasan, tapi tidak bisa menulis
          _ReviewHint(
            icon: Icons.edit_off_outlined,
            message: 'Login dan beli buku ini untuk menulis ulasan.',
          ),
          const SizedBox(height: 12),
        ] else ...[
          // Sudah login tapi belum beli
          _ReviewHint(
            icon: Icons.shopping_bag_outlined,
            message: 'Beli buku ini untuk bisa menulis ulasan.',
          ),
          const SizedBox(height: 12),
        ],

        // ── List reviews ────────────────────────────────────────
        if (state.loading)
          const Center(child: CircularProgressIndicator())
        else if (state.reviews.isEmpty)
          const _EmptyReviews()
        else
          ...state.reviews.map((r) => _ReviewCard(
                review: r,
                isOwn: r.userId == auth.user?.id,
                ebookId: widget.ebookId,
              )),
      ],
    );
  }
}

// ── Rating distribution bar ──────────────────────────────────────────
class _RatingBar extends StatelessWidget {
  final List<ReviewModel> reviews;
  const _RatingBar({required this.reviews});

  @override
  Widget build(BuildContext context) {
    final total = reviews.length;
    return Column(
      children: List.generate(5, (i) {
        final star  = 5 - i;
        final count = reviews.where((r) => r.rating == star).length;
        final pct   = total > 0 ? count / total : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Text('$star', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF5A623)),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE8E6DF),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFF5A623)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 20,
                child: Text(
                  '$count',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF888780)),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Write/Edit review button ─────────────────────────────────────────
class _WriteReviewButton extends ConsumerWidget {
  final int ebookId;
  final ReviewModel? existingReview;

  const _WriteReviewButton({
    required this.ebookId,
    this.existingReview,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () => _showReviewDialog(context, ref),
      icon: Icon(
        existingReview != null
            ? Icons.edit_outlined
            : Icons.rate_review_outlined,
        size: 18,
      ),
      label: Text(existingReview != null ? 'Edit Ulasan Saya' : 'Tulis Ulasan'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1D9E75),
        side: const BorderSide(color: Color(0xFF1D9E75)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showReviewDialog(BuildContext context, WidgetRef ref) {
    int selectedRating = existingReview?.rating ?? 0;
    final commentCtrl =
        TextEditingController(text: existingReview?.comment ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E6DF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                existingReview != null ? 'Edit Ulasan' : 'Tulis Ulasan',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 16),

              // Star rating
              const Text('Rating',
                  style: TextStyle(fontSize: 14, color: Color(0xFF5F5E5A))),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedRating = star),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        star <= selectedRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 36,
                        color: star <= selectedRating
                            ? const Color(0xFFF5A623)
                            : const Color(0xFFCCCBC8),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Comment
              const Text('Komentar (opsional)',
                  style: TextStyle(fontSize: 14, color: Color(0xFF5F5E5A))),
              const SizedBox(height: 8),
              TextField(
                controller: commentCtrl,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: 'Bagikan pengalamanmu membaca buku ini...',
                  hintStyle: const TextStyle(color: Color(0xFFB0AEA8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE8E6DF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1D9E75)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: selectedRating == 0
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          final ok = await ref
                              .read(reviewProvider(ebookId).notifier)
                              .submitReview(
                                rating:  selectedRating,
                                comment: commentCtrl.text.trim().isEmpty
                                    ? null
                                    : commentCtrl.text.trim(),
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Ulasan berhasil disimpan!'
                                    : 'Gagal menyimpan ulasan.'),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9E75),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Simpan Ulasan',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Single review card ───────────────────────────────────────────────
class _ReviewCard extends ConsumerWidget {
  final ReviewModel review;
  final bool isOwn;
  final int ebookId;

  const _ReviewCard({
    required this.review,
    required this.isOwn,
    required this.ebookId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E6DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User + rating row
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1D9E75),
                child: Text(
                  (review.user?.name ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          review.user?.name ?? 'Pengguna',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        if (isOwn) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE1F5EE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Saya',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF1D9E75),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Stars
                    Row(
                      children: List.generate(5, (i) => Icon(
                        i < review.rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 14,
                        color: i < review.rating
                            ? const Color(0xFFF5A623)
                            : const Color(0xFFCCCBC8),
                      )),
                    ),
                  ],
                ),
              ),
              if (isOwn)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 20),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hapus Ulasan'),
                        content: const Text(
                            'Yakin ingin menghapus ulasan ini?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Batal'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref
                          .read(reviewProvider(ebookId).notifier)
                          .deleteReview();
                    }
                  },
                ),
            ],
          ),

          // Comment
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF5F5E5A),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E6DF)),
      ),
      child: const Center(
        child: Text(
          'Belum ada ulasan untuk buku ini.\nJadi yang pertama mengulas!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF888780)),
        ),
      ),
    );
  }
}

class _ReviewHint extends StatelessWidget {
  final IconData icon;
  final String message;
  const _ReviewHint({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F3F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E6DF)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF888780)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF888780)),
            ),
          ),
        ],
      ),
    );
  }
}
