import 'package:flutter/material.dart';
import 'package:mentimeter_app/models/quiz.dart';
import 'package:mentimeter_app/models/session.dart';
import 'package:mentimeter_app/screens/admin/session_control_screen.dart';
import 'package:mentimeter_app/services/auth_service.dart';
import 'package:mentimeter_app/services/quiz_service.dart';
import 'package:mentimeter_app/services/session_service.dart';

class StartSessionScreen extends StatefulWidget {
  const StartSessionScreen({super.key});

  @override
  State<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends State<StartSessionScreen> {
  final _quizService = QuizService();
  final _sessionService = SessionService();
  final _authService = AuthService();
  
  List<Quiz> _quizzes = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }
  
  Future<void> _loadQuizzes() async {
    setState(() => _isLoading = true);
    try {
      final adminId = _authService.currentUser!.uid;
      _quizzes = await _quizService.getQuizzesByAdmin(adminId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading quizzes: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _startSession(Quiz quiz) async {
    setState(() => _isLoading = true);
    try {
      final adminId = _authService.currentUser!.uid;
      final session = await _sessionService.createSession(
        quizId: quiz.id,
        adminId: adminId,
      );
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionControlScreen(session: session, quiz: quiz),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting session: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Quiz Session'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _quizzes.isEmpty
              ? const Center(
                  child: Text('No quizzes available. Create quizzes first.'),
                )
              : ListView.builder(
                  itemCount: _quizzes.length,
                  itemBuilder: (context, index) {
                    final quiz = _quizzes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(quiz.title),
                        subtitle: Text('${quiz.questionIds.length} questions'),
                        trailing: ElevatedButton(
                          onPressed: () => _startSession(quiz),
                          child: const Text('Start Session'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
} 