import 'package:cloud_firestore/cloud_firestore.dart';

class Quiz {
  final String id;
  final String title;
  final String description;
  final String adminId;
  final DateTime createdAt;
  final List<String> questionIds;
  bool isActive;

  Quiz({
    required this.id,
    required this.title,
    required this.description,
    required this.adminId,
    required this.createdAt,
    required this.questionIds,
    this.isActive = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'adminId': adminId,
      'createdAt': Timestamp.fromDate(createdAt),
      'questionIds': questionIds,
      'isActive': isActive,
    };
  }

  factory Quiz.fromMap(Map<String, dynamic> map) {
    return Quiz(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      adminId: map['adminId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      questionIds: List<String>.from(map['questionIds'] ?? []),
      isActive: map['isActive'] ?? false,
    );
  }
} 