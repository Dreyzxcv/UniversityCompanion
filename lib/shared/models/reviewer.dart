import 'package:cloud_firestore/cloud_firestore.dart';

class Reviewer {
  final String id;
  final String title;
  final String sourceText;
  final String? subjectCode;
  final DateTime createdAt;
  final int questionCount;

  Reviewer({
    required this.id,
    required this.title,
    required this.sourceText,
    this.subjectCode,
    required this.createdAt,
    this.questionCount = 0,
  });

  factory Reviewer.fromMap(String id, Map<String, dynamic> map) {
    final ts = map['createdAt'];
    return Reviewer(
      id: id,
      title: map['title'] ?? '',
      sourceText: map['sourceText'] ?? '',
      subjectCode: map['subjectCode'] as String?,
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      questionCount: map['questionCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'sourceText': sourceText,
      'subjectCode': subjectCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'questionCount': questionCount,
    };
  }
}