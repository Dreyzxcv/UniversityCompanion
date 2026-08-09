import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../shared/models/reviewer.dart';
import '../shared/services/reviewer_service.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/models/quiz_attempt.dart';
import 'add_reviewer_screen.dart';
import 'quiz_screen.dart';
import 'quiz_result_screen.dart';

class ReviewerListScreen extends StatelessWidget {
  const ReviewerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ReviewerService>();

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reviewers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Reviewer>>(
                stream: service.watchReviewers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final reviewers = snapshot.data ?? [];
                  if (reviewers.isEmpty) {
                    return EmptyState(
                      icon: Icons.auto_awesome_rounded,
                      title: 'No reviewers yet',
                      message:
                          'Paste your notes and generate a practice quiz to start reviewing.',
                      ctaLabel: 'New Reviewer',
                      onCta: () => _openAddReviewer(context),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                    itemCount: reviewers.length,
                    itemBuilder: (context, i) {
                      return _ReviewerCard(
                        reviewer: reviewers[i],
                        service: service,
                        onTap: () => _handleTap(context, service, reviewers[i]),
                        onDelete: () =>
                            _confirmDelete(context, service, reviewers[i]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom,
        ),
        child: FloatingActionButton(
          onPressed: () => _openAddReviewer(context),
          backgroundColor: AppColors.navyDark,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  // Navigator.push creates a new route in the Overlay as a SIBLING of
  // this screen's subtree, not a descendant — so providers set above
  // MainShell (in AuthGate) are NOT visible to pushed routes by default.
  // We capture the service instance here, while `context` still has
  // access to it, and re-supply it via Provider.value to the pushed
  // route so AddReviewerScreen/QuizScreen can read it.
  void _openAddReviewer(BuildContext context) {
    final reviewerService = context.read<ReviewerService>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Provider<ReviewerService>.value(
          value: reviewerService,
          child: const AddReviewerScreen(),
        ),
      ),
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    ReviewerService reviewerService,
    Reviewer reviewer,
  ) async {
    final latest = await reviewerService.getLatestAttempt(reviewer.id);
    if (!context.mounted) return;

    if (latest == null) {
      _openQuiz(context, reviewerService, reviewer);
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Last attempt: ${latest.score}/${latest.totalQuestions} '
                '(${latest.percentage.toStringAsFixed(0)}%)',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_outlined, color: AppColors.navyDark),
              title: const Text('View Last Result'),
              onTap: () => Navigator.pop(ctx, 'view'),
            ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded, color: AppColors.navyMid),
              title: const Text('Retake Quiz'),
              onTap: () => Navigator.pop(ctx, 'retake'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted || choice == null) return;

    if (choice == 'view') {
      final questions = await reviewerService.getQuestionsOnce(reviewer.id);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Provider<ReviewerService>.value(
            value: reviewerService,
            child: QuizResultScreen(attempt: latest, questions: questions),
          ),
        ),
      );
    } else if (choice == 'retake') {
      _openQuiz(context, reviewerService, reviewer);
    }
  }

  void _openQuiz(
    BuildContext context,
    ReviewerService reviewerService,
    Reviewer reviewer,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Provider<ReviewerService>.value(
          value: reviewerService,
          child: QuizScreen(reviewerId: reviewer.id),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ReviewerService service,
    Reviewer reviewer,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete reviewer?'),
        content: Text(
          'This will permanently delete "${reviewer.title}" and its questions. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.overdue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await service.deleteReviewer(reviewer.id);
    }
  }
}

class _ReviewerCard extends StatelessWidget {
  final Reviewer reviewer;
  final ReviewerService service;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ReviewerCard({
    required this.reviewer,
    required this.service,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(reviewer.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // deletion handled via dialog + stream update
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.overdue,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.pillLavender,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: AppColors.navyDark),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reviewer.title.isEmpty ? 'Untitled Reviewer' : reviewer.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (reviewer.subjectCode != null &&
                                  reviewer.subjectCode!.isNotEmpty) ...[
                                Text(
                                  reviewer.subjectCode!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600),
                                ),
                                const Text(' · ',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ],
                              Text(
                                '${reviewer.questionCount} question${reviewer.questionCount == 1 ? '' : 's'}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                              const Text(' · ',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              Text(
                                DateFormat('MMM d').format(reviewer.createdAt),
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ],
                ),
                StreamBuilder<List<QuizAttempt>>(
                  stream: service.watchAttempts(reviewer.id),
                  builder: (context, snapshot) {
                    final attempts = snapshot.data ?? const [];
                    if (attempts.isEmpty) return const SizedBox.shrink();
                    final latest = attempts.first; // already ordered desc
                    final pct = latest.percentage;
                    final color = pct >= 75
                        ? AppColors.excellent
                        : pct >= 50
                            ? AppColors.passingWarn
                            : AppColors.overdue;
                    return Padding(
                      padding: const EdgeInsets.only(top: 10, left: 58),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Last: ${latest.score}/${latest.totalQuestions} · ${pct.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (attempts.length > 1) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${attempts.length} attempts',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}