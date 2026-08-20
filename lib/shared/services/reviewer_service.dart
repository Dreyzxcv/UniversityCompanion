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
  ///
  /// [typeCounts] maps each [QuestionType] to the number of questions of
  /// that type to generate. Types with a count of 0 are ignored.
  Future<String> generateQuizFromText({
    required String title,
    required String sourceText,
    String? subjectCode,
    required int numQuestions,
    required Map<QuestionType, int> typeCounts,
  }) async {
    final questions = await _callGroq(
      sourceText: sourceText,
      typeCounts: typeCounts,
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
    required Map<QuestionType, int> typeCounts,
  }) async {
    if (groqApiKey == 'PASTE_YOUR_GROQ_KEY_HERE') {
      throw Exception(
        'Groq API key not set. Add your key from '
        'https://console.groq.com/keys to '
        'lib/shared/services/groq_config.dart',
      );
    }

    // Build a human-readable list of what the model should produce,
    // e.g. "- 5 multiple_choice\n- 3 identification\n- 2 true_or_false"
    final activeTypes = typeCounts.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));

    final typeBreakdown = activeTypes
        .map((e) => '  - ${e.value} ${questionTypeToString(e.key)}')
        .join('\n');

    final totalQuestions =
        activeTypes.fold<int>(0, (sum, e) => sum + e.value);

    // Per-type instructions for the model.
    const typeInstructions = '''
Question type rules:
- multiple_choice: Exactly 4 choices (key "choices"), only one correct. Include all 4 choices as plausible distractors drawn from the source material. Set "choices" to the list of 4 strings.
- identification: Short factual prompt with ONE clear, concise correct answer. Set "choices" to null.
- fill_in_the_blanks: A sentence with ONE blank represented by "___". The correct answer is the missing word or short phrase. Set "choices" to null.
- true_or_false: A declarative statement that is either completely true or false based on the source. Set "correct_answers" to ["true"] or ["false"] (lowercase). Set "choices" to ["True", "False"].
- enumeration: Ask the student to list multiple related items. Provide the FULL correct list in "correct_answers". Set "choices" to null.
''';

    final systemPrompt = '''
You are a strict JSON API. Respond with ONLY a single valid JSON object.
No prose, no explanation, no markdown formatting, no code fences.
The JSON object must have exactly this shape:
{
  "questions": [
    {
      "type": "multiple_choice" | "identification" | "fill_in_the_blanks" | "true_or_false" | "enumeration",
      "prompt": "string",
      "choices": ["string", ...] or null,
      "correct_answers": ["string"],
      "explanation": "string"
    }
  ]
}
''';

    final userPrompt = '''
You are a quiz generator for a university study app used by Philippine college students.

INSTRUCTIONS:
1. Read the reviewer content carefully and identify the key concepts, definitions, facts, and relationships worth testing.
2. Generate exactly $totalQuestions questions with this EXACT distribution:
$typeBreakdown

$typeInstructions

3. Base every question strictly on the provided reviewer content. Do not introduce outside facts.
4. Vary difficulty: mix recall-level and understanding-level questions.
5. For each question, include a one-sentence explanation referencing the source material.
6. If the content is too short for the requested number of good questions, generate fewer rather than padding with filler.
7. Write all questions and answers in the same language as the reviewer content.
8. Output the questions in the SAME ORDER as the distribution above (all multiple_choice first, then the next type, etc.).

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
        'model': 'openai/gpt-oss-120b',
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

    var raw =
        (choices.first['message']?['content'] as String?)?.trim() ?? '';
    if (raw.isEmpty) {
      throw Exception('Empty response from quiz generator.');
    }

    // Safety net: strip accidental ```json fences.
    raw = raw.replaceAll(RegExp(r'^```(json)?', multiLine: true), '');
    raw = raw.replaceAll(RegExp(r'```$', multiLine: true), '').trim();

    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    final rawQuestions = parsed['questions'] as List? ?? [];

    return rawQuestions
        .map((q) => QuizQuestion.fromMap(
              '',
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
        .map((snap) => snap.docs
            .map((d) => QuizAttempt.fromMap(d.id, d.data()))
            .toList());
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
    return snap.docs
        .map((d) => QuizQuestion.fromMap(d.id, d.data()))
        .toList();
  }
}