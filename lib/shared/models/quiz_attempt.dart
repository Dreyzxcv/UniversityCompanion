import 'package:cloud_firestore/cloud_firestore.dart';

class QuizAttempt {
  final String id;
  final String reviewerId;
  final DateTime takenAt;
  final int score;
  final int totalQuestions;
  final Map<String, List<String>> userAnswers; // questionId -> given answer(s)

  QuizAttempt({
    required this.id,
    required this.reviewerId,
    required this.takenAt,
    required this.score,
    required this.totalQuestions,
    required this.userAnswers,
  });

  double get percentage =>
      totalQuestions == 0 ? 0 : (score / totalQuestions) * 100;

  factory QuizAttempt.fromMap(String id, Map<String, dynamic> map) {
    final ts = map['takenAt'];
    final rawAnswers = Map<String, dynamic>.from(map['userAnswers'] ?? {});
    return QuizAttempt(
      id: id,
      reviewerId: map['reviewerId'] ?? '',
      takenAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      score: map['score'] ?? 0,
      totalQuestions: map['totalQuestions'] ?? 0,
      userAnswers: rawAnswers.map(
        (k, v) => MapEntry(k, (v as List).map((e) => e.toString()).toList()),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reviewerId': reviewerId,
      'takenAt': Timestamp.fromDate(takenAt),
      'score': score,
      'totalQuestions': totalQuestions,
      'userAnswers': userAnswers,
    };
  }
}