import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mentimeter_app/models/question.dart';
import 'package:mentimeter_app/models/quiz.dart';
import 'package:mentimeter_app/models/session.dart';
import 'package:mentimeter_app/services/quiz_service.dart';
import 'package:mentimeter_app/services/session_service.dart';

class SessionControlScreen extends StatefulWidget {
  final Session session;
  final Quiz quiz;

  const SessionControlScreen({
    super.key,
    required this.session,
    required this.quiz,
  });

  @override
  State<SessionControlScreen> createState() => _SessionControlScreenState();
}

class _SessionControlScreenState extends State<SessionControlScreen> {
  final _quizService = QuizService();
  final _sessionService = SessionService();
  
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  bool _isLoading = true;
  int _participantCount = 0;
  Timer? _questionTimer;
  int _remainingTime = 0;
  bool _autoAdvance = true;
  bool _timerStarted = false;
  
  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _startListeningToSession();
  }
  
  @override
  void dispose() {
    _questionTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      _questions = await _quizService.getQuestionsByQuizId(widget.quiz.id);
      setState(() {
        _currentQuestionIndex = widget.session.currentQuestionIndex;
      });
      
      // Démarrer le timer immédiatement après le chargement des questions
      _startQuestionTimer();
      
      // Enregistrer que nous avons démarré le timer
      _timerStarted = true;
      
      // Mettre à jour également la session pour signaler que le timer a été démarré
      await _sessionService.updateSessionTimerState(widget.session.id, true);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading questions: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _startQuestionTimer() {
    // Cancel any existing timer
    _questionTimer?.cancel();
    
    // If no questions or current index out of bounds, don't start timer
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) {
      return;
    }
    
    // Set initial remaining time from current question
    _remainingTime = _questions[_currentQuestionIndex].timeLimit;
    setState(() {});
    
    // Create a new timer
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
        
        // Mettre à jour le temps restant dans la session Firestore toutes les 5 secondes 
        // pour synchroniser tous les clients
        if (_remainingTime % 5 == 0 || _remainingTime <= 10) {
          _sessionService.updateSessionRemainingTime(
            widget.session.id, 
            _remainingTime
          );
        }
      } else {
        // Time's up!
        timer.cancel();
        if (_autoAdvance) {
          // Move to next question automatically if enabled
          _nextQuestion();
        }
      }
    });
  }
  
  void _startListeningToSession() {
    // In a real app, you would use Firestore streams to listen for session updates
    // For this example, we'll implement periodic polling
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      
      _updateParticipantCount();
      _startListeningToSession(); // Recursive call for polling
    });
  }
  
  Future<void> _updateParticipantCount() async {
    try {
      final updatedSession = await _sessionService.getSessionById(widget.session.id);
      if (updatedSession != null && mounted) {
        setState(() {
          _participantCount = updatedSession.participantIds.length;
        });
      }
    } catch (e) {
      print('Error updating participant count: $e');
    }
  }
  
  Future<void> _nextQuestion() async {
    if (_currentQuestionIndex >= _questions.length - 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is the last question!')),
      );
      return;
    }
    
    try {
      await _sessionService.moveToNextQuestion(widget.session.id);
      setState(() {
        _currentQuestionIndex++;
      });
      _startQuestionTimer(); // Restart timer for new question
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error moving to next question: ${e.toString()}')),
      );
    }
  }
  
  Future<void> _resetTimer() async {
    // Redémarrer le timer manuellement avec le temps complet
    if (_questions.isNotEmpty && _currentQuestionIndex < _questions.length) {
      _questionTimer?.cancel();
      
      setState(() {
        _remainingTime = _questions[_currentQuestionIndex].timeLimit;
      });
      
      // Mettre à jour le temps restant dans Firestore
      await _sessionService.updateSessionRemainingTime(
        widget.session.id,
        _remainingTime
      );
      
      _startQuestionTimer();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timer reset for current question')),
      );
    }
  }
  
  Future<void> _endSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session'),
        content: const Text('Are you sure you want to end this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        _questionTimer?.cancel(); // Cancel the timer when ending session
        await _sessionService.closeSession(widget.session.id);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error ending session: ${e.toString()}')),
          );
        }
      }
    }
  }
  
  void _copyAccessCode() {
    Clipboard.setData(ClipboardData(text: widget.session.accessCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Access code copied to clipboard')),
    );
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Session: ${widget.quiz.title}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _endSession,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Access code display
                Container(
                  color: Colors.blue.shade100,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Access Code: ',
                        style: TextStyle(fontSize: 18),
                      ),
                      Text(
                        widget.session.accessCode,
                        style: const TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: _copyAccessCode,
                      ),
                    ],
                  ),
                ),
                
                // Timer and participant count
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Colors.grey.shade100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Participants: $_participantCount',
                        style: const TextStyle(fontSize: 16),
                      ),
                      Row(
                        children: [
                          Switch(
                            value: _autoAdvance,
                            onChanged: (value) {
                              setState(() {
                                _autoAdvance = value;
                              });
                            },
                          ),
                          const Text('Auto-advance'),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'Time: ${_formatTime(_remainingTime)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _remainingTime < 10 ? Colors.red : Colors.black,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Reset timer',
                            onPressed: _resetTimer,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const Divider(),
                
                // Current question display
                Expanded(
                  child: _questions.isEmpty
                      ? const Center(
                          child: Text('No questions in this quiz'),
                        )
                      : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (_currentQuestionIndex < _questions.length)
                                  Text(
                                    _questions[_currentQuestionIndex].text,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                const SizedBox(height: 24),
                                // Affichage des options de réponse en mode administrateur
                                if (_currentQuestionIndex < _questions.length)
                                  FutureBuilder(
                                    future: _quizService.getAnswersByQuestionId(_questions[_currentQuestionIndex].id),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const Center(child: CircularProgressIndicator());
                                      }
                                      
                                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                        return const Text('No answers available for this question');
                                      }
                                      
                                      final answers = snapshot.data!;
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Answer options:',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...answers.map((answer) => Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                color: answer.isCorrect 
                                                    ? Colors.green.shade50 
                                                    : Colors.grey.shade50,
                                                border: Border.all(
                                                  color: answer.isCorrect 
                                                      ? Colors.green 
                                                      : Colors.grey.shade300,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      answer.text,
                                                      style: TextStyle(
                                                        fontWeight: answer.isCorrect 
                                                            ? FontWeight.bold 
                                                            : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ),
                                                  if (answer.isCorrect)
                                                    const Icon(Icons.check_circle, color: Colors.green),
                                                ],
                                              ),
                                            ),
                                          )).toList(),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton(
            onPressed: _nextQuestion,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Next Question'),
          ),
        ),
      ),
    );
  }
} 