enum QuestionType {
  multipleChoice,
  identification,
  enumeration,
  trueOrFalse,
  fillInTheBlanks,
}

QuestionType questionTypeFromString(String s) {
  switch (s) {
    case 'multiple_choice':
      return QuestionType.multipleChoice;
    case 'enumeration':
      return QuestionType.enumeration;
    case 'true_or_false':
      return QuestionType.trueOrFalse;
    case 'fill_in_the_blanks':
      return QuestionType.fillInTheBlanks;
    default:
      return QuestionType.identification;
  }
}

String questionTypeToString(QuestionType t) {
  switch (t) {
    case QuestionType.multipleChoice:
      return 'multiple_choice';
    case QuestionType.enumeration:
      return 'enumeration';
    case QuestionType.trueOrFalse:
      return 'true_or_false';
    case QuestionType.fillInTheBlanks:
      return 'fill_in_the_blanks';
    case QuestionType.identification:
      return 'identification';
  }
}

extension QuestionTypeX on QuestionType {
  String get label {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.identification:
        return 'Identification';
      case QuestionType.enumeration:
        return 'Enumeration';
      case QuestionType.trueOrFalse:
        return 'True or False';
      case QuestionType.fillInTheBlanks:
        return 'Fill in the Blanks';
    }
  }

  String get shortLabel {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'MCQ';
      case QuestionType.identification:
        return 'Ident.';
      case QuestionType.enumeration:
        return 'Enum.';
      case QuestionType.trueOrFalse:
        return 'T/F';
      case QuestionType.fillInTheBlanks:
        return 'Fill';
    }
  }

  String get description {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'Pick the correct answer from 4 choices';
      case QuestionType.identification:
        return 'Write the correct word or phrase';
      case QuestionType.enumeration:
        return 'List all correct items';
      case QuestionType.trueOrFalse:
        return 'Decide if the statement is True or False';
      case QuestionType.fillInTheBlanks:
        return 'Complete the sentence with the missing word';
    }
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
      'type': questionTypeToString(type),
      'prompt': prompt,
      'choices': choices,
      'correct_answers': correctAnswers,
      'explanation': explanation,
    };
  }
}