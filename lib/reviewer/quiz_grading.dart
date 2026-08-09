import '../shared/models/quiz_question.dart';

String _normalize(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');

/// Returns a score between 0.0 and 1.0 for a single question given the
/// student's answer(s). MCQ/identification are all-or-nothing;
/// enumeration gives partial credit per matched item.
double gradeAnswer(QuizQuestion q, List<String> given) {
  final correctNormalized = q.correctAnswers.map(_normalize).toSet();

  if (q.type == QuestionType.enumeration) {
    if (correctNormalized.isEmpty) return 0;
    final givenNormalized = given.map(_normalize).toSet();
    final matched = givenNormalized.intersection(correctNormalized).length;
    return matched / correctNormalized.length;
  }

  // multiple choice / identification: exact match on the single answer
  if (given.isEmpty) return 0;
  return correctNormalized.contains(_normalize(given.first)) ? 1.0 : 0.0;
}