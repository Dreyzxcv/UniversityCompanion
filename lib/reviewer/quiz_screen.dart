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

  // Shuffled snapshot of questions for this attempt — loaded once.
  List<QuizQuestion>? _shuffledQuestions;

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
        // Restore previously saved answer for the next question if any
        _restoreAnswerForIndex(_index, questions);
      });
    }
  }

  /// Goes back to the previous question, restoring the previously saved answer.
  void _goBack(List<QuizQuestion> questions) {
    if (_index == 0) return;
    setState(() {
      _index--;
      _enumCtrl.clear();
      _selectedChoice = null;
      _restoreAnswerForIndex(_index, questions);
    });
  }

  /// Restores the saved answer for the question at [index] into the
  /// appropriate input controller / selected choice.
  void _restoreAnswerForIndex(int index, List<QuizQuestion> questions) {
    final q = questions[index];
    final saved = _answers[q.id];
    if (saved == null || saved.isEmpty) return;

    switch (q.type) {
      case QuestionType.multipleChoice:
      case QuestionType.trueOrFalse:
        _selectedChoice = saved.first;
      case QuestionType.identification:
      case QuestionType.fillInTheBlanks:
        _enumCtrl.text = saved.first;
      case QuestionType.enumeration:
        _enumCtrl.text = saved.join(', ');
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

          final rawQuestions = snapshot.data!;

          if (rawQuestions.isEmpty) {
            return const Center(
              child: Text('No questions generated.'),
            );
          }

          // Shuffle once when we first receive the questions.
          // After that, reuse the same shuffled list so the order
          // doesn't change mid-attempt when the stream re-emits.
          if (_shuffledQuestions == null) {
            _shuffledQuestions = List<QuizQuestion>.from(rawQuestions)
              ..shuffle();
          }

          final questions = _shuffledQuestions!;
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
            _NavButtons(
              index: _index,
              isLast: isLast,
              canNext: _selectedChoice != null,
              onBack: () => _goBack(questions),
              onNext: () => _recordAnswer(q.id, [_selectedChoice!], questions),
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
            _NavButtons(
              index: _index,
              isLast: isLast,
              canNext: true,
              onBack: () => _goBack(questions),
              onNext: () => _recordAnswer(q.id, [_enumCtrl.text], questions),
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
            _NavButtons(
              index: _index,
              isLast: isLast,
              canNext: true,
              onBack: () => _goBack(questions),
              onNext: () {
                final items = _enumCtrl.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                _recordAnswer(q.id, items, questions);
              },
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
            _NavButtons(
              index: _index,
              isLast: isLast,
              canNext: _selectedChoice != null,
              onBack: () => _goBack(questions),
              onNext: () => _recordAnswer(q.id, [_selectedChoice!], questions),
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

class _NavButtons extends StatelessWidget {
  final int index;
  final bool isLast;
  final bool canNext;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _NavButtons({
    required this.index,
    required this.isLast,
    required this.canNext,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (index > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: onBack,
              child: const Text('Back'),
            ),
          ),
        if (index > 0) const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: canNext ? onNext : null,
            child: Text(isLast ? 'Finish' : 'Next'),
          ),
        ),
      ],
    );
  }
}