import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mentimeter_app/models/quiz.dart';
import 'package:mentimeter_app/models/session.dart';
import 'package:mentimeter_app/screens/participant/quiz_participation_screen.dart';
import 'package:mentimeter_app/services/auth_service.dart';
import 'package:mentimeter_app/services/quiz_service.dart';
import 'package:mentimeter_app/services/session_service.dart';

class JoinSessionScreen extends StatefulWidget {
  const JoinSessionScreen({super.key});

  @override
  State<JoinSessionScreen> createState() => _JoinSessionScreenState();
}

class _JoinSessionScreenState extends State<JoinSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accessCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _sessionService = SessionService();
  final _quizService = QuizService();
  final _authService = AuthService();
  
  bool _isLoading = false;
  Session? _currentSession;
  Quiz? _currentQuiz;
  
  @override
  void dispose() {
    _accessCodeController.dispose();
    _nameController.dispose();
    super.dispose();
  }
  
  Future<void> _findSession() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final accessCode = _accessCodeController.text.trim();
      final session = await _sessionService.getSessionByAccessCode(accessCode);
      
      if (session == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid access code or session not active')),
          );
        }
        setState(() {
          _isLoading = false;
          _currentSession = null;
          _currentQuiz = null;
        });
        return;
      }
      
      final quiz = await _quizService.getQuiz(session.quizId);
      if (quiz == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quiz not found')),
          );
        }
        setState(() {
          _isLoading = false;
          _currentSession = null;
          _currentQuiz = null;
        });
        return;
      }
      
      setState(() {
        _isLoading = false;
        _currentSession = session;
        _currentQuiz = quiz;
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error finding session: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _joinSession() async {
    if (_currentSession == null || _currentQuiz == null) {
      await _findSession();
      if (_currentSession == null || _currentQuiz == null) return;
    }
    
    setState(() => _isLoading = true);
    try {
      // Add participant to session
      String participantId = _authService.currentUser?.uid ?? _nameController.text;
      await _sessionService.addParticipant(_currentSession!.id, participantId);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QuizParticipationScreen(
              session: _currentSession!,
              quiz: _currentQuiz!,
              participantName: _nameController.text,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining session: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _openAdminInNewWindow() async {
    // Launch the admin URL in a new window/tab
    final adminUrl = 'http://localhost:57252/#/admin/start_session';
    if (await canLaunchUrl(Uri.parse(adminUrl))) {
      await launchUrl(
        Uri.parse(adminUrl),
        mode: LaunchMode.externalApplication,
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open admin window')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Quiz Session'),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: _openAdminInNewWindow,
            tooltip: 'Open admin panel in new window',
          ),
        ],
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter Session Code',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _accessCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Access Code',
                      hintText: 'Enter the 6-digit code',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an access code';
                      }
                      if (value.length != 6) {
                        return 'Access code must be 6 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Name',
                      hintText: 'Enter your name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _findSession,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Find Session'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading || _currentSession == null ? null : _joinSession,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.green,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : const Text('Join Session'),
                        ),
                      ),
                    ],
                  ),
                  if (_currentSession != null && _currentQuiz != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: Text(
                        'Found quiz: ${_currentQuiz!.title}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 