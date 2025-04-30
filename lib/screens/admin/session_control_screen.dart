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
  bool _quizStarted = false;
  
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
      
      // Don't start timer automatically - wait for user to press start button
      // Set initial remaining time without starting the timer
      if (_questions.isNotEmpty) {
        _remainingTime = _questions[_currentQuestionIndex].timeLimit;
      }
      
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
  
  Future<void> _startQuiz() async {
    if (_quizStarted) return; // Prevent starting twice
    
    try {
      // Set the quiz as started
      setState(() {
        _quizStarted = true;
        _timerStarted = true;
      });
      
      // Update the session in Firestore to indicate the timer has started
      await _sessionService.updateSessionTimerState(widget.session.id, true);
      
      // Start the timer for the first question
      _startQuestionTimer();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quiz started! Timer is now running.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting quiz: ${e.toString()}')),
      );
    }
  }
  
  Future<void> _resetSession() async {
    // Ask for confirmation before resetting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Session'),
        content: const Text(
          'Are you sure you want to reset this session? This will:'
          '\n- Return to the first question'
          '\n- Reset all timers'
          '\n- Allow participants to rejoin from the beginning'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Reset Session'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        _questionTimer?.cancel(); // Cancel current timer
        
        // Reset the session in Firestore
        await _sessionService.resetSession(widget.session.id);
        
        // Update local state
        setState(() {
          _currentQuestionIndex = 0;
          _timerStarted = false;
          _quizStarted = false;
          if (_questions.isNotEmpty) {
            _remainingTime = _questions[0].timeLimit;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session has been reset successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting session: ${e.toString()}')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Session: ${widget.quiz.title}'),
        backgroundColor: const Color(0xFF2D46B9),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _endSession,
          ),
        ],
      ),
      body: _isLoading
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF0F4FF), Colors.white],
                ),
              ),
              child: const Center(
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    color: Color(0xFF2D46B9),
                    strokeWidth: 5,
                  ),
                ),
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF0F4FF), Colors.white],
                ),
              ),
              child: Column(
                children: [
                  // Access code display
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D46B9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.numbers,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Access Code: ',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.session.accessCode,
                          style: const TextStyle(
                            fontSize: 24, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white),
                          onPressed: _copyAccessCode,
                          tooltip: 'Copy access code',
                        ),
                      ],
                    ),
                  ),
                  
                  // Participant count and start button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D46B9).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.people,
                                size: 20,
                                color: Color(0xFF2D46B9),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Participants: $_participantCount',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D46B9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            if (_quizStarted)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reset'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _resetSession,
                              ),
                            const SizedBox(width: 12),
                            if (!_quizStarted)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Start Quiz'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF26A69A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: _startQuiz,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Timer controls
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Switch(
                              value: _autoAdvance,
                              activeColor: const Color(0xFF2D46B9),
                              onChanged: (value) {
                                setState(() {
                                  _autoAdvance = value;
                                });
                              },
                            ),
                            const Text(
                              'Auto-advance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _remainingTime < 10
                                ? const Color(0xFFFFEBEE)
                                : const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _remainingTime < 10
                                  ? const Color(0xFFE53935)
                                  : const Color(0xFF2D46B9),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer,
                                size: 20,
                                color: _remainingTime < 10
                                    ? const Color(0xFFE53935)
                                    : const Color(0xFF2D46B9),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(_remainingTime),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _remainingTime < 10
                                      ? const Color(0xFFE53935)
                                      : const Color(0xFF2D46B9),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                iconSize: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Reset timer',
                                color: _remainingTime < 10
                                    ? const Color(0xFFE53935)
                                    : const Color(0xFF2D46B9),
                                onPressed: _resetTimer,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Current question display
                  Expanded(
                    child: _questions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.quiz,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No questions in this quiz',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFF757575),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2D46B9).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D46B9),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (_currentQuestionIndex < _questions.length)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      _questions[_currentQuestionIndex].text,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF212121),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                
                                // Display answer options in admin mode
                                if (_currentQuestionIndex < _questions.length)
                                  FutureBuilder(
                                    future: _quizService.getAnswersByQuestionId(_questions[_currentQuestionIndex].id),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(20.0),
                                            child: CircularProgressIndicator(
                                              color: Color(0xFF2D46B9),
                                            ),
                                          ),
                                        );
                                      }
                                      
                                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                        return Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5F5F5),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.info_outline, color: Color(0xFF757575)),
                                              SizedBox(width: 12),
                                              Text(
                                                'No answers available for this question',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Color(0xFF757575),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
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
                                              color: Color(0xFF424242),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ...List.generate(answers.length, (index) {
                                            final answer = answers[index];
                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 12),
                                              decoration: BoxDecoration(
                                                color: answer.isCorrect 
                                                    ? const Color(0xFFE8F5E9)
                                                    : Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: answer.isCorrect 
                                                      ? const Color(0xFF66BB6A)
                                                      : const Color(0xFFE0E0E0),
                                                  width: answer.isCorrect ? 2 : 1,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.03),
                                                    blurRadius: 5,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(16),
                                                child: Row(
                                                  children: [
                                                    // Letter indicator
                                                    Container(
                                                      width: 36,
                                                      height: 36,
                                                      decoration: BoxDecoration(
                                                        color: answer.isCorrect
                                                            ? const Color(0xFF66BB6A)
                                                            : const Color(0xFF42A5F5),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          String.fromCharCode(65 + index), // A, B, C, etc.
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Text(
                                                        answer.text,
                                                        style: TextStyle(
                                                          fontWeight: answer.isCorrect 
                                                              ? FontWeight.bold 
                                                              : FontWeight.normal,
                                                          fontSize: 16,
                                                          color: const Color(0xFF424242),
                                                        ),
                                                      ),
                                                    ),
                                                    if (answer.isCorrect)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 6,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF66BB6A).withOpacity(0.2),
                                                          borderRadius: BorderRadius.circular(20),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(
                                                              Icons.check_circle,
                                                              color: Color(0xFF66BB6A),
                                                              size: 16,
                                                            ),
                                                            const SizedBox(width: 4),
                                                            const Text(
                                                              'Correct',
                                                              style: TextStyle(
                                                                color: Color(0xFF66BB6A),
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _questions.isEmpty || _currentQuestionIndex >= _questions.length - 1
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D46B9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Next Question',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
    );
  }
} 