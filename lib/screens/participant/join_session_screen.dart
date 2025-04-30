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
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text('Join Quiz Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF3949AB),
        elevation: 4,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
              onPressed: _openAdminInNewWindow,
              tooltip: 'Open admin panel in new window',
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFF0F4FF),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo/Icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D46B9).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.groups_rounded,
                              size: 40,
                              color: Color(0xFF2D46B9),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Join a Quiz Session',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D46B9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enter the session code and your name to participate',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _accessCodeController,
                            decoration: InputDecoration(
                              labelText: 'Access Code',
                              hintText: 'Enter the 6-digit code',
                              prefixIcon: const Icon(Icons.numbers, color: Color(0xFF2D46B9)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF2D46B9), width: 2),
                              ),
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
                            decoration: InputDecoration(
                              labelText: 'Your Name',
                              hintText: 'Enter your name',
                              prefixIcon: const Icon(Icons.person, color: Color(0xFF2D46B9)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF2D46B9), width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _findSession,
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: const Color(0xFF2D46B9),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Find Session',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading || _currentSession == null ? null : _joinSession,
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: _currentSession == null 
                                        ? Colors.grey.shade400 
                                        : const Color(0xFF4CAF50),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Join Session',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_currentSession != null && _currentQuiz != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 24.0),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Quiz Found',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                          Text(
                                            _currentQuiz!.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 