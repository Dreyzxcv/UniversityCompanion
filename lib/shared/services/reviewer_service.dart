import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'groq_config.dart';
import '../models/reviewer.dart';
import '../models/quiz_question.dart';
import '../models/quiz_attempt.dart';

class ReviewerService {
  final FirebaseFirestore _db;
  final String uid;

  ReviewerService({required this.uid, FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reviewers =>
      _db.collection('users').doc(uid).collection('reviewers');

  CollectionReference<Map<String, dynamic>> _questions(String reviewerId) =>
      _reviewers.doc(reviewerId).collection('questions');

  CollectionReference<Map<String, dynamic>> get _attempts =>
      _db.collection('users').doc(uid).collection('quizAttempts');

  // ---------------- Reviewers ----------------

  Stream<List<Reviewer>> watchReviewers() {
    return _reviewers.orderBy('createdAt', descending: true).snapshots().map(
          (snap) =>
              snap.docs.map((d) => Reviewer.fromMap(d.id, d.data())).toList(),
        );
  }

  Stream<List<QuizQuestion>> watchQuestions(String reviewerId) {
    return _questions(reviewerId).snapshots().map(
          (snap) => snap.docs
              .map((d) => QuizQuestion.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  /// Generates a quiz from [sourceText] via Groq (Llama 3.3 70B), saves the
  /// reviewer + its questions to Firestore, and returns the new reviewer id.
  Future<String> generateQuizFromText({
    required String title,
    required String sourceText,
    String? subjectCode,
    int numQuestions = 10,
    int numMcq = 5,
    int numIdentification = 3,
    int numEnumeration = 2,
  }) async {
    final questions = await _callGroq(
      sourceText: sourceText,
      numQuestions: numQuestions,
      numMcq: numMcq,
      numIdentification: numIdentification,
      numEnumeration: numEnumeration,
    );

    final reviewerRef = await _reviewers.add(
      Reviewer(
        id: '',
        title: title,
        sourceText: sourceText,
        subjectCode: subjectCode,
        createdAt: DateTime.now(),
        questionCount: questions.length,
      ).toMap(),
    );

    final batch = _db.batch();
    for (final q in questions) {
      final qRef = _questions(reviewerRef.id).doc();
      batch.set(qRef, q.toMap());
    }
    await batch.commit();

    return reviewerRef.id;
  }

  static const _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  Future<List<QuizQuestion>> _callGroq({
    required String sourceText,
    required int numQuestions,
    required int numMcq,
    required int numIdentification,
    required int numEnumeration,
  }) async {
    if (groqApiKey == 'PASTE_YOUR_GROQ_KEY_HERE') {
      throw Exception(
        'Groq API key not set. Add your key from '
        'https://console.groq.com/keys to '
        'lib/shared/services/groq_config.dart',
      );
    }

    final systemPrompt = '''
You are a strict JSON API. Respond with ONLY a single valid JSON object.
No prose, no explanation, no markdown formatting, no code fences.
The JSON object must have exactly this shape:
{
  "questions": [
    {
      "type": "multiple_choice" | "identification" | "enumeration",
      "prompt": "string",
      "choices": ["string", "string", "string", "string"] or null (only for multiple_choice),
      "correct_answers": ["string"],
      "explanation": "string"
    }
  ]
}
''';

    final userPrompt = '''
You are a quiz generator for a university study app used by Philippine college students. Your job is to convert a student's reviewer/notes into a structured practice quiz.

INSTRUCTIONS:
1. Read the reviewer content carefully and identify the key concepts, definitions, facts, and relationships worth testing.
2. Generate exactly $numQuestions questions total, distributed across these types:
  - Multiple choice ($numMcq questions): 4 plausible choices, only ONE correct. Wrong choices must be genuinely plausible, drawn from related concepts in the material.
  - Identification ($numIdentification questions): a short factual prompt with one clear, concise correct answer.
  - Enumeration ($numEnumeration questions): ask the student to list multiple related items. Provide the FULL correct list.
3. Base every question strictly on the provided reviewer content. Do not introduce outside facts.
4. Vary difficulty: mix recall-level and understanding-level questions.
5. For each question, include a one-sentence explanation referencing the source material.
6. If the content is too short for $numQuestions good questions, generate fewer rather than padding with filler.
7. Write all questions and answers in the same language as the reviewer content.

Reviewer content:
$sourceText
''';

    final response = await http.post(
      Uri.parse(_groqEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $groqApiKey',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'response_format': {'type': 'json_object'},
        'temperature': 0.4,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Groq request failed (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = body['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Empty response from quiz generator.');
    }

    var raw = (choices.first['message']?['content'] as String?)?.trim() ?? '';
    if (raw.isEmpty) {
      throw Exception('Empty response from quiz generator.');
    }

    // Safety net: strip accidental ```json fences even though the model
    // was told not to include them.
    raw = raw.replaceAll(RegExp(r'^```(json)?', multiLine: true), '');
    raw = raw.replaceAll(RegExp(r'```$', multiLine: true), '').trim();

    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    final rawQuestions = parsed['questions'] as List? ?? [];

    return rawQuestions
        .map((q) => QuizQuestion.fromMap(
              '', // id assigned when written to Firestore
              q as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<void> deleteReviewer(String reviewerId) async {
    final questionsSnap = await _questions(reviewerId).get();
    final batch = _db.batch();
    for (final doc in questionsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_reviewers.doc(reviewerId));
    await batch.commit();
  }

  // ---------------- Attempts ----------------

  Future<void> saveAttempt(QuizAttempt attempt) {
    return _attempts.add(attempt.toMap());
  }

  Stream<List<QuizAttempt>> watchAttempts(String reviewerId) {
    return _attempts
        .where('reviewerId', isEqualTo: reviewerId)
        .orderBy('takenAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => QuizAttempt.fromMap(d.id, d.data())).toList());
  }

  Future<QuizAttempt?> getLatestAttempt(String reviewerId) async {
    final snap = await _attempts
        .where('reviewerId', isEqualTo: reviewerId)
        .orderBy('takenAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return QuizAttempt.fromMap(doc.id, doc.data());
  }

  Future<List<QuizQuestion>> getQuestionsOnce(String reviewerId) async {
    final snap = await _questions(reviewerId).get();
    return snap.docs.map((d) => QuizQuestion.fromMap(d.id, d.data())).toList();
  }
}