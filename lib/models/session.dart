import 'package:cloud_firestore/cloud_firestore.dart';

class Session {
  final String id;
  final String quizId;
  final String adminId;
  final String accessCode;
  final DateTime createdAt;
  final bool isActive;
  final int currentQuestionIndex;
  final List<String> participantIds;
  final bool timerStarted;
  final int remainingTime;

  Session({
    required this.id,
    required this.quizId,
    required this.adminId,
    required this.accessCode,
    required this.createdAt,
    this.isActive = true,
    this.currentQuestionIndex = 0,
    this.participantIds = const [],
    this.timerStarted = false,
    this.remainingTime = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quizId': quizId,
      'adminId': adminId,
      'accessCode': accessCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'currentQuestionIndex': currentQuestionIndex,
      'participantIds': participantIds,
      'timerStarted': timerStarted,
      'remainingTime': remainingTime,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] ?? '',
      quizId: map['quizId'] ?? '',
      adminId: map['adminId'] ?? '',
      accessCode: map['accessCode'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
      currentQuestionIndex: map['currentQuestionIndex'] ?? 0,
      participantIds: List<String>.from(map['participantIds'] ?? []),
      timerStarted: map['timerStarted'] ?? false,
      remainingTime: map['remainingTime'] ?? 0,
    );
  }
} 