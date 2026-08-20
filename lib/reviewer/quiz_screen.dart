import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/models/quiz_question.dart';
import '../shared/models/quiz_attempt.dart';
import '../shared/services/reviewer_service.dart';
import '../shared/theme/app_theme.dart';
import 'quiz_grading.dart';
import 'quiz_result_screen.dart';

class QuizScreen extends StatefulWidget {
  final String reviewerId;
  const QuizScreen({super.key, required this.reviewerId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final Map<String, List<String>> _answers = {};
  final _enumCtrl = TextEditingController();
  int _index = 0;
  bool _finishing = false;

  // Currently-tapped (but not yet confirmed) choice for multiple
  // choice and true/false question types.
  String? _selectedChoice;

  @override
  void dispose() {
    _enumCtrl.dispose();
    super.dispose();
  }

  /// Records the answer for the current question. If this is the last
  /// question, triggers grading + save instead of advancing the index.
  void _recordAnswer(
    String questionId,
    List<String> given,
    List<QuizQuestion> questions,
  ) {
    setState(() => _answers[questionId] = given);

    final isLast = _index == questions.length - 1;
    if (isLast) {
      _finish(questions);
    } else {
      setState(() {
        _index++;
        _enumCtrl.clear();
        _selectedChoice = null;
      });
    }
  }

  Future<void> _finish(List<QuizQuestion> questions) async {
    setState(() => _finishing = true);

    double totalScore = 0;
    for (final q in questions) {
      totalScore += gradeAnswer(q, _answers[q.id] ?? []);
    }

    final roundedScore = totalScore.round();

    final attempt = QuizAttempt(
      id: '',
      reviewerId: widget.reviewerId,
      takenAt: DateTime.now(),
      score: roundedScore,
      totalQuestions: questions.length,
      userAnswers: _answers,
    );

    await context.read<ReviewerService>().saveAttempt(attempt);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            attempt: attempt,
            questions: questions,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<ReviewerService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: StreamBuilder<List<QuizQuestion>>(
        stream: service.watchQuestions(widget.reviewerId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final questions = snapshot.data!;

          if (questions.isEmpty) {
            return const Center(
              child: Text('No questions generated.'),
            );
          }

          final q = questions[_index];

          if (_finishing) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: (_index + 1) / questions.length,
                  backgroundColor: AppColors.pillLavender,
                  color: AppColors.navyDark,
                ),
                const SizedBox(height: 8),
                Text(
                  'Question ${_index + 1} of ${questions.length}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  q.prompt,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _buildAnswerInput(q, questions),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnswerInput(
    QuizQuestion q,
    List<QuizQuestion> questions,
  ) {
    final isLast = _index == questions.length - 1;

    switch (q.type) {
      case QuestionType.multipleChoice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: (q.choices ?? []).map((choice) {
                  final selected = _selectedChoice == choice;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: selected
                        ? AppColors.pillLavender
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: selected
                            ? AppColors.navyDark
                            : AppColors.cardBorder,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        choice,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.navyDark
                              : AppColors.textDark,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.navyDark,
                            )
                          : const Icon(
                              Icons.circle_outlined,
                              color: AppColors.textMuted,
                            ),
                      onTap: () {
                        setState(() {
                          _selectedChoice = choice;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _selectedChoice == null
                  ? null
                  : () => _recordAnswer(
                        q.id,
                        [_selectedChoice!],
                        questions,
                      ),
              child: Text(isLast ? 'Finish' : 'Next'),
            ),
          ],
        );

      case QuestionType.identification:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _enumCtrl,
              decoration: const InputDecoration(
                labelText: 'Your answer',
              ),
              onSubmitted: (_) => _recordAnswer(
                q.id,
                [_enumCtrl.text],
                questions,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _recordAnswer(
                q.id,
                [_enumCtrl.text],
                questions,
              ),
              child: Text(isLast ? 'Finish' : 'Next'),
            ),
          ],
        );

      case QuestionType.enumeration:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Separate multiple answers with commas',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _enumCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Your answers',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final items = _enumCtrl.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                _recordAnswer(
                  q.id,
                  items,
                  questions,
                );
              },
              child: Text(isLast ? 'Finish' : 'Next'),
            ),
          ],
        );

      case QuestionType.trueOrFalse:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: ['True', 'False'].map((choice) {
                  final selected = _selectedChoice == choice;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: selected
                        ? AppColors.pillLavender
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: selected
                            ? AppColors.navyDark
                            : AppColors.cardBorder,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        choice,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.navyDark
                              : AppColors.textDark,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.navyDark,
                            )
                          : const Icon(
                              Icons.circle_outlined,
                              color: AppColors.textMuted,
                            ),
                      onTap: () {
                        setState(() {
                          _selectedChoice = choice;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _selectedChoice == null
                  ? null
                  : () => _recordAnswer(
                        q.id,
                        [_selectedChoice!],
                        questions,
                      ),
              child: Text(isLast ? 'Finish' : 'Next'),
            ),
          ],
        );

      case QuestionType.fillInTheBlanks:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _enumCtrl,
              decoration: const InputDecoration(
                labelText: 'Your answer',
              ),
              onSubmitted: (_) => _recordAnswer(
                q.id,
                [_enumCtrl.text],
                questions,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _recordAnswer(
                q.id,
                [_enumCtrl.text],
                questions,
              ),
              child: Text(isLast ? 'Finish' : 'Next'),
            ),
          ],
        );
    }
  }
}