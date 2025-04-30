import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mentimeter_app/models/quiz.dart';
import 'package:mentimeter_app/models/question.dart';
import 'package:mentimeter_app/models/answer.dart';
import 'package:uuid/uuid.dart';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _quizzesCollection = 'quizzes';
  final String _questionsCollection = 'questions';
  final String _answersCollection = 'answers';

  // Quiz CRUD operations
  Future<bool> createQuiz(Quiz quiz) async {
    try {
      await _firestore.collection(_quizzesCollection).doc(quiz.id).set(quiz.toMap());
      return true;
    } catch (e) {
      print('Error creating quiz: $e');
      return false;
    }
  }

  Future<List<Quiz>> getQuizzesByAdmin(String adminId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_quizzesCollection)
          .where('adminId', isEqualTo: adminId)
          .get();
      
      return querySnapshot.docs
          .map((doc) => Quiz.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting quizzes: $e');
      return [];
    }
  }

  Future<Quiz?> getQuiz(String quizId) async {
    try {
      final doc = await _firestore.collection(_quizzesCollection).doc(quizId).get();
      if (!doc.exists) return null;
      return Quiz.fromMap(doc.data() ?? {});
    } catch (e) {
      print('Error getting quiz: $e');
      return null;
    }
  }

  Future<bool> updateQuiz(Quiz quiz) async {
    try {
      await _firestore.collection(_quizzesCollection).doc(quiz.id).update(quiz.toMap());
      return true;
    } catch (e) {
      print('Error updating quiz: $e');
      return false;
    }
  }

  Future<bool> deleteQuiz(String quizId) async {
    try {
      await _firestore.collection(_quizzesCollection).doc(quizId).delete();
      return true;
    } catch (e) {
      print('Error deleting quiz: $e');
      return false;
    }
  }

  // Question CRUD operations
  Future<Question> createQuestion({
    required String quizId,
    required String text,
    required int timeLimit,
    required List<Answer> answers,
    required String correctAnswerId,
    int points = 100,
  }) async {
    final questionId = const Uuid().v4();
    
    // Update all answers with the new questionId
    final updatedAnswers = answers.map((answer) => 
      Answer(
        id: answer.id,
        questionId: questionId,
        text: answer.text,
        isCorrect: answer.isCorrect,
      )
    ).toList();
    
    final answerIds = updatedAnswers.map((a) => a.id).toList();

    final question = Question(
      id: questionId,
      quizId: quizId,
      text: text,
      timeLimit: timeLimit,
      answerIds: answerIds,
      correctAnswerId: correctAnswerId,
      points: points,
    );

    // Create question
    await _firestore
        .collection(_questionsCollection)
        .doc(questionId)
        .set(question.toMap());

    // Create answers
    for (var answer in updatedAnswers) {
      await _firestore
          .collection(_answersCollection)
          .doc(answer.id)
          .set(answer.toMap());
    }

    // Update quiz's questionIds
    final quiz = await getQuiz(quizId);
    if (quiz != null) {
      quiz.questionIds.add(questionId);
      await updateQuiz(quiz);
    }

    return question;
  }

  Future<List<Question>> getQuestionsByQuizId(String quizId) async {
    final snapshot = await _firestore
        .collection(_questionsCollection)
        .where('quizId', isEqualTo: quizId)
        .get();

    return snapshot.docs
        .map((doc) => Question.fromMap(doc.data()))
        .toList();
  }

  Future<Question> getQuestionById(String questionId) async {
    final doc =
        await _firestore.collection(_questionsCollection).doc(questionId).get();
    return Question.fromMap(doc.data()!);
  }

  Future<void> updateQuestion(Question question) async {
    await _firestore
        .collection(_questionsCollection)
        .doc(question.id)
        .update(question.toMap());
  }

  Future<void> deleteQuestion(String questionId) async {
    // Delete all answers associated with this question
    final answers = await getAnswersByQuestionId(questionId);
    for (var answer in answers) {
      await _firestore.collection(_answersCollection).doc(answer.id).delete();
    }
    await _firestore.collection(_questionsCollection).doc(questionId).delete();
  }

  // Answer operations
  Future<List<Answer>> getAnswersByQuestionId(String questionId) async {
    final snapshot = await _firestore
        .collection(_answersCollection)
        .where('questionId', isEqualTo: questionId)
        .get();

    return snapshot.docs
        .map((doc) => Answer.fromMap(doc.data()))
        .toList();
  }

  Future<Answer?> getAnswerById(String answerId) async {
    try {
      final doc = await _firestore
          .collection(_answersCollection)
          .doc(answerId)
          .get();
      
      if (!doc.exists) return null;
      return Answer.fromMap(doc.data() ?? {});
    } catch (e) {
      print('Error getting answer by ID: $e');
      return null;
    }
  }

  Future<void> updateAnswer(Answer answer) async {
    await _firestore
        .collection(_answersCollection)
        .doc(answer.id)
        .update(answer.toMap());
  }

  Future<void> createAnswer(Answer answer) async {
    await _firestore
        .collection(_answersCollection)
        .doc(answer.id)
        .set(answer.toMap());
  }

  Future<void> deleteAnswer(String answerId) async {
    await _firestore
        .collection(_answersCollection)
        .doc(answerId)
        .delete();
  }

  // Quiz control operations
  Future<void> startQuiz(String quizId) async {
    final quiz = await getQuiz(quizId);
    if (quiz != null) {
      quiz.isActive = true;
      await updateQuiz(quiz);
    }
  }

  Future<void> stopQuiz(String quizId) async {
    final quiz = await getQuiz(quizId);
    if (quiz != null) {
      quiz.isActive = false;
      await updateQuiz(quiz);
    }
  }
} 