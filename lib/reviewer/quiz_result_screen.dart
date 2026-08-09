import 'package:flutter/material.dart';
import '../shared/models/quiz_question.dart';
import '../shared/models/quiz_attempt.dart';
import '../shared/theme/app_theme.dart';
import 'quiz_grading.dart';

class QuizResultScreen extends StatelessWidget {
  final QuizAttempt attempt;
  final List<QuizQuestion> questions;

  const QuizResultScreen({
    super.key,
    required this.attempt,
    required this.questions,
  });

  @override
  Widget build(BuildContext context) {
    final pct = attempt.percentage;
    final color = pct >= 75
        ? AppColors.excellent
        : pct >= 50
            ? AppColors.passingWarn
            : AppColors.overdue;

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Results')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                Text(
                  '${attempt.score} / ${attempt.totalQuestions}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Review',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark),
          ),
          const SizedBox(height: 12),
          ...questions.map((q) => _QuestionReviewCard(
                question: q,
                given: attempt.userAnswers[q.id] ?? [],
              )),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _QuestionReviewCard extends StatelessWidget {
  final QuizQuestion question;
  final List<String> given;

  const _QuestionReviewCard({required this.question, required this.given});

  @override
  Widget build(BuildContext context) {
    final score = gradeAnswer(question, given);
    final isCorrect = score >= 1.0;
    final isPartial = score > 0 && score < 1.0;

    final statusColor = isCorrect
        ? AppColors.excellent
        : isPartial
            ? AppColors.passingWarn
            : AppColors.overdue;
    final statusIcon = isCorrect
        ? Icons.check_circle_rounded
        : isPartial
            ? Icons.adjust_rounded
            : Icons.cancel_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question.prompt,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Your answer: ${given.isEmpty ? '(no answer)' : given.join(', ')}',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            'Correct answer: ${question.correctAnswers.join(', ')}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
          if (question.explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.pillLavender.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                question.explanation,
                style: const TextStyle(fontSize: 12, color: AppColors.textDark, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}