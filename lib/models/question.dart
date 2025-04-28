import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  final String id;
  final String quizId;
  final String text;
  final int timeLimit; // in seconds
  final List<String> answerIds;
  final String correctAnswerId;
  final int points;

  Question({
    required this.id,
    required this.quizId,
    required this.text,
    required this.timeLimit,
    required this.answerIds,
    required this.correctAnswerId,
    this.points = 100,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quizId': quizId,
      'text': text,
      'timeLimit': timeLimit,
      'answerIds': answerIds,
      'correctAnswerId': correctAnswerId,
      'points': points,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] ?? '',
      quizId: map['quizId'] ?? '',
      text: map['text'] ?? '',
      timeLimit: map['timeLimit'] ?? 30,
      answerIds: List<String>.from(map['answerIds'] ?? []),
      correctAnswerId: map['correctAnswerId'] ?? '',
      points: map['points'] ?? 100,
    );
  }
} 