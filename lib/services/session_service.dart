import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mentimeter_app/models/session.dart';
import 'package:uuid/uuid.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _sessionsCollection = 'sessions';

  // Generate a random 6-digit access code
  String _generateAccessCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Check if an access code already exists
  Future<bool> _isAccessCodeUnique(String code) async {
    final querySnapshot = await _firestore
        .collection(_sessionsCollection)
        .where('accessCode', isEqualTo: code)
        .where('isActive', isEqualTo: true)
        .get();
    
    return querySnapshot.docs.isEmpty;
  }

  // Create a new session with a unique access code
  Future<Session> createSession({
    required String quizId,
    required String adminId,
  }) async {
    try {
      final sessionId = const Uuid().v4();
      String accessCode;
      
      // Generate a unique access code
      do {
        accessCode = _generateAccessCode();
      } while (!(await _isAccessCodeUnique(accessCode)));

      final session = Session(
        id: sessionId,
        quizId: quizId,
        adminId: adminId,
        accessCode: accessCode,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .set(session.toMap());
      
      return session;
    } catch (e) {
      print('Error creating session: $e');
      rethrow;
    }
  }

  // Get a session by ID
  Future<Session?> getSessionById(String sessionId) async {
    try {
      final doc = await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .get();
      
      if (!doc.exists) return null;
      return Session.fromMap(doc.data() ?? {});
    } catch (e) {
      print('Error getting session: $e');
      return null;
    }
  }

  // Get a session by access code
  Future<Session?> getSessionByAccessCode(String accessCode) async {
    try {
      final querySnapshot = await _firestore
          .collection(_sessionsCollection)
          .where('accessCode', isEqualTo: accessCode)
          .where('isActive', isEqualTo: true)
          .get();
      
      if (querySnapshot.docs.isEmpty) return null;
      return Session.fromMap(querySnapshot.docs.first.data());
    } catch (e) {
      print('Error getting session by access code: $e');
      return null;
    }
  }

  // Get all active sessions for an admin
  Future<List<Session>> getActiveSessionsByAdmin(String adminId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_sessionsCollection)
          .where('adminId', isEqualTo: adminId)
          .where('isActive', isEqualTo: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => Session.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting active sessions: $e');
      return [];
    }
  }

  // Close a session
  Future<bool> closeSession(String sessionId) async {
    try {
      await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .update({'isActive': false});
      return true;
    } catch (e) {
      print('Error closing session: $e');
      return false;
    }
  }

  // Add a participant to a session
  Future<bool> addParticipant(String sessionId, String participantId) async {
    try {
      final session = await getSessionById(sessionId);
      if (session == null) return false;
      
      if (!session.participantIds.contains(participantId)) {
        final updatedParticipants = [...session.participantIds, participantId];
        await _firestore
            .collection(_sessionsCollection)
            .doc(sessionId)
            .update({'participantIds': updatedParticipants});
      }
      return true;
    } catch (e) {
      print('Error adding participant: $e');
      return false;
    }
  }

  // Move to the next question in the session
  Future<bool> moveToNextQuestion(String sessionId) async {
    try {
      final session = await getSessionById(sessionId);
      if (session == null) return false;
      
      await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .update({
            'currentQuestionIndex': session.currentQuestionIndex + 1,
            'timerStarted': true,
          });
      return true;
    } catch (e) {
      print('Error moving to next question: $e');
      return false;
    }
  }

  // Mettre à jour l'état du timer dans la session
  Future<bool> updateSessionTimerState(String sessionId, bool timerStarted) async {
    try {
      await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .update({
            'timerStarted': timerStarted,
          });
      return true;
    } catch (e) {
      print('Error updating timer state: $e');
      return false;
    }
  }
  
  // Mettre à jour le temps restant dans la session
  Future<bool> updateSessionRemainingTime(String sessionId, int remainingTime) async {
    try {
      await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .update({
            'remainingTime': remainingTime,
          });
      return true;
    } catch (e) {
      print('Error updating remaining time: $e');
      return false;
    }
  }
  
  // Reset a session to its initial state
  Future<bool> resetSession(String sessionId) async {
    try {
      await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .update({
            'currentQuestionIndex': 0,
            'timerStarted': false,
            'remainingTime': 0,
          });
      return true;
    } catch (e) {
      print('Error resetting session: $e');
      return false;
    }
  }
} 