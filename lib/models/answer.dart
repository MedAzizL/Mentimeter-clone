class Answer {
  final String id;
  final String questionId;
  final String text;
  final bool isCorrect;

  Answer({
    required this.id,
    required this.questionId,
    required this.text,
    this.isCorrect = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionId': questionId,
      'text': text,
      'isCorrect': isCorrect,
    };
  }

  factory Answer.fromMap(Map<String, dynamic> map) {
    return Answer(
      id: map['id'] ?? '',
      questionId: map['questionId'] ?? '',
      text: map['text'] ?? '',
      isCorrect: map['isCorrect'] ?? false,
    );
  }
} 