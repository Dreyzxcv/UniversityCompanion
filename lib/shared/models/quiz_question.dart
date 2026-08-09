enum QuestionType { multipleChoice, identification, enumeration }

QuestionType questionTypeFromString(String s) {
  switch (s) {
    case 'multiple_choice':
      return QuestionType.multipleChoice;
    case 'enumeration':
      return QuestionType.enumeration;
    default:
      return QuestionType.identification;
  }
}

class QuizQuestion {
  final String id;
  final QuestionType type;
  final String prompt;
  final List<String>? choices;
  final List<String> correctAnswers;
  final String explanation;

  QuizQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    this.choices,
    required this.correctAnswers,
    required this.explanation,
  });

  factory QuizQuestion.fromMap(String id, Map<String, dynamic> map) {
    return QuizQuestion(
      id: id,
      type: questionTypeFromString(map['type'] ?? 'identification'),
      prompt: map['prompt'] ?? '',
      choices: (map['choices'] as List?)?.map((e) => e.toString()).toList(),
      correctAnswers: (map['correct_answers'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      explanation: map['explanation'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name == 'multipleChoice'
          ? 'multiple_choice'
          : type.name,
      'prompt': prompt,
      'choices': choices,
      'correct_answers': correctAnswers,
      'explanation': explanation,
    };
  }
}