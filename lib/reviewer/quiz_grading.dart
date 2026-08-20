import '../shared/models/quiz_question.dart';

String _normalize(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');

/// Returns a score between 0.0 and 1.0 for a single question given the
/// student's answer(s).
///
/// - Multiple choice / identification / fill in the blanks / true or false:
///   all-or-nothing exact match (after normalization).
/// - Enumeration: partial credit — one point per matched item, divided by
///   the total number of correct items.
double gradeAnswer(QuizQuestion q, List<String> given) {
  final correctNormalized = q.correctAnswers.map(_normalize).toSet();

  switch (q.type) {
    case QuestionType.enumeration:
      if (correctNormalized.isEmpty) return 0;
      final givenNormalized = given.map(_normalize).toSet();
      final matched = givenNormalized.intersection(correctNormalized).length;
      return matched / correctNormalized.length;

    case QuestionType.trueOrFalse:
      // Accepts "true"/"false" or "t"/"f" or full sentences containing them.
      if (given.isEmpty) return 0;
      final raw = _normalize(given.first);
      final answer = raw.startsWith('t')
          ? 'true'
          : raw.startsWith('f')
              ? 'false'
              : raw;
      return correctNormalized.contains(answer) ? 1.0 : 0.0;

    case QuestionType.multipleChoice:
    case QuestionType.identification:
    case QuestionType.fillInTheBlanks:
      if (given.isEmpty) return 0;
      return correctNormalized.contains(_normalize(given.first)) ? 1.0 : 0.0;
  }
}