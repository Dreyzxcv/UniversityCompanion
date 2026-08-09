import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../shared/models/reviewer.dart';
import '../shared/services/reviewer_service.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/empty_state.dart';
import 'add_reviewer_screen.dart';
import 'quiz_screen.dart';

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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reviewers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navyDark,
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
                        onTap: () => _openQuiz(context, reviewers[i]),
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
          bottom: MediaQuery.of(context).padding.bottom + 90,
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

  void _openQuiz(BuildContext context, Reviewer reviewer) {
    final reviewerService = context.read<ReviewerService>();
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
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ReviewerCard({
    required this.reviewer,
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
            child: Row(
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
          ),
        ),
      ),
    );
  }
}