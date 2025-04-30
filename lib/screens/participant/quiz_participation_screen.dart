import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mentimeter_app/models/answer.dart';
import 'package:mentimeter_app/models/question.dart';
import 'package:mentimeter_app/models/quiz.dart';
import 'package:mentimeter_app/models/session.dart';
import 'package:mentimeter_app/services/quiz_service.dart';
import 'package:mentimeter_app/services/session_service.dart';

class QuizParticipationScreen extends StatefulWidget {
  final Session session;
  final Quiz quiz;
  final String participantName;

  const QuizParticipationScreen({
    super.key,
    required this.session,
    required this.quiz,
    required this.participantName,
  });

  @override
  State<QuizParticipationScreen> createState() =>
      _QuizParticipationScreenState();
}

class _QuizParticipationScreenState extends State<QuizParticipationScreen> {
  final _quizService = QuizService();
  final _sessionService = SessionService();
  
  late Session _session; // Local mutable copy of the session
  
  List<Question> _questions = [];
  List<Answer> _currentAnswers = [];
  int _currentQuestionIndex = 0;
  bool _isLoading = true;
  bool _hasAnswered = false;
  String? _selectedAnswerId;
  bool? _isCorrect;
  int _score = 0; // Total score
  int _totalAnswered = 0; // Number of questions answered
  bool _quizCompleted = false; // Flag to show quiz completed screen
  int _remainingTime = 0; // Remaining time for current question
  Timer? _questionTimer; // Timer to track question time
  Timer? _sessionCheckTimer; // Timer to check for session updates

  @override
  void initState() {
    super.initState();
    // Create a local copy of the session that we can modify
    _session = widget.session;
    _loadQuestions();
    _startListeningToSession();
  }
  
  @override
  void dispose() {
    _questionTimer?.cancel();
    _sessionCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      _questions = await _quizService.getQuestionsByQuizId(widget.quiz.id);
      setState(() {
        _currentQuestionIndex = _session.currentQuestionIndex;
      });
      await _loadCurrentAnswers();
      
      // Only start timer if the session timer has already started
      if (_session.timerStarted) {
      _startQuestionTimer();
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
    _questionTimer?.cancel();
    
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length || _hasAnswered) {
      return;
    }
    
    // Set initial time from the current question
    _remainingTime = _questions[_currentQuestionIndex].timeLimit;
    setState(() {});
    
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        // Time's up - if user hasn't answered, show a message
        timer.cancel();
        if (!_hasAnswered && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Time\'s up! Waiting for next question...'),
              backgroundColor: Colors.orange,
            )
          );
        }
      }
    });
  }
  
  Future<void> _loadCurrentAnswers() async {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) {
      setState(() {
        _currentAnswers = [];
        // Check if the quiz is completed
        if (_totalAnswered > 0 && _currentQuestionIndex >= _questions.length) {
          _quizCompleted = true;
        }
      });
      return;
    }
    
    try {
      final currentQuestion = _questions[_currentQuestionIndex];
      print('Loading answers for question: ${currentQuestion.id}');
      print('Question has ${currentQuestion.answerIds.length} answer IDs: ${currentQuestion.answerIds}');
      
      _currentAnswers = await _quizService.getAnswersByQuestionId(currentQuestion.id);
      print('Loaded ${_currentAnswers.length} answers for question ${currentQuestion.id}');
      
      // If no answers found but question has answerIds, try to fetch each answer by ID
      if (_currentAnswers.isEmpty && currentQuestion.answerIds.isNotEmpty) {
        print('No answers found using questionId, trying to load by answer IDs');
        List<Answer> answers = [];
        for (var answerId in currentQuestion.answerIds) {
          try {
            final answer = await _quizService.getAnswerById(answerId);
            if (answer != null) {
              answers.add(answer);
            }
          } catch (e) {
            print('Error loading answer $answerId: $e');
          }
        }
        _currentAnswers = answers;
        print('Loaded ${_currentAnswers.length} answers by ID');
      }
      
      setState(() {
        _hasAnswered = false;
        _selectedAnswerId = null;
        _isCorrect = null;
      });
      
      // Start the timer for the new question
      _startQuestionTimer();
    } catch (e) {
      print('Error loading answers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading answers: ${e.toString()}')),
        );
      }
    }
  }
  
  void _startListeningToSession() {
    // Cancel existing timer if any
    _sessionCheckTimer?.cancel();
    
    // Create a new timer that checks more frequently (every 1 second)
    _sessionCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      _checkForQuestionChange();
    });
  }
  
  Future<void> _checkForQuestionChange() async {
    try {
      final updatedSession = await _sessionService.getSessionById(_session.id);
      print('Session check: timerStarted=${updatedSession?.timerStarted}, local timerStarted=${_session.timerStarted}'); 
      
      if (updatedSession == null || !updatedSession.isActive) {
        // Session ended
        if (mounted && !_quizCompleted) {
          setState(() {
            _quizCompleted = true;
          });
        }
        return;
      }
      
      // Check if the timer has started in the session
      if (updatedSession.timerStarted && !_session.timerStarted) {
        print('Quiz just started! Updating local state');
        // Quiz has just started - update local session state
        setState(() {
          _session = updatedSession;
        });
        await _loadCurrentAnswers();
        _startQuestionTimer();
      } else if (updatedSession.timerStarted && (_questionTimer == null || !_questionTimer!.isActive)) {
        // If the time in the session is smaller, use it as it's more precise
        if (updatedSession.remainingTime > 0 && 
            (updatedSession.remainingTime < _remainingTime || _remainingTime <= 0)) {
          setState(() {
            _remainingTime = updatedSession.remainingTime;
          });
        }
        _startQuestionTimer();
      }
      
      // If remaining time is defined in the session and different from our local value
      if (updatedSession.remainingTime > 0 && 
          (updatedSession.remainingTime - _remainingTime).abs() > 3) {
        setState(() {
          _remainingTime = updatedSession.remainingTime;
        });
      }
      
      if (updatedSession.currentQuestionIndex != _currentQuestionIndex) {
        // Question changed - cancel current timer
        _questionTimer?.cancel();
        
        setState(() {
          _currentQuestionIndex = updatedSession.currentQuestionIndex;
          // Update the session too
          _session = updatedSession;
        });
        await _loadCurrentAnswers();
      }
    } catch (e) {
      print('Error checking for question change: $e');
    }
  }
  
  Future<void> _submitAnswer(String answerId) async {
    if (_hasAnswered) return;
    
    // Cancel the timer when user submits an answer
    _questionTimer?.cancel();
    
    // Find the selected answer to check if it's correct
    final selectedAnswer = _currentAnswers.firstWhere(
      (answer) => answer.id == answerId,
      orElse: () => Answer(id: '', questionId: '', text: ''),
    );
    
    setState(() {
      _selectedAnswerId = answerId;
      _hasAnswered = true;
      _isCorrect = selectedAnswer.isCorrect;
      _totalAnswered++;
      
      // Update score if answer is correct
      if (selectedAnswer.isCorrect) {
        final points = _questions.isNotEmpty && _currentQuestionIndex < _questions.length 
            ? _questions[_currentQuestionIndex].points 
            : 0;
        _score += points;
      }
    });
    
    // Show feedback toast
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedAnswer.isCorrect 
              ? 'Correct! +${_questions[_currentQuestionIndex].points} points' 
              : 'Incorrect answer',
        ),
        backgroundColor: selectedAnswer.isCorrect ? Colors.green : Colors.red,
      ),
    );
    
    // In a real app, you would store the participant's answer in Firestore
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF2D46B9),
          foregroundColor: Colors.white,
          title: Text('${widget.quiz.title} - Live'),
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  color: Color(0xFF2D46B9),
                  strokeWidth: 6,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Loading quiz...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF424242),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Quiz completed
    if (_quizCompleted) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF2D46B9),
          foregroundColor: Colors.white,
          title: Text('${widget.quiz.title} - Results'),
          elevation: 0,
        ),
        body: _buildScoreSummary(),
      );
    }

    // Quiz ended or no questions
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF2D46B9),
          foregroundColor: Colors.white,
          title: Text('${widget.quiz.title} - Live'),
          elevation: 0,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF0F4FF), Colors.white],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.hourglass_empty_rounded,
                  size: 80,
                  color: Color(0xFF2D46B9),
                ),
                SizedBox(height: 24),
                Text(
            'Waiting for the next question...',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D46B9),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'The presenter will move to the next question soon',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Quiz not started yet
    if (!_session.timerStarted) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF2D46B9),
          foregroundColor: Colors.white,
          title: Text('${widget.quiz.title} - Live'),
          elevation: 0,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF0F4FF), Colors.white],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D46B9).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.timer_outlined,
                    size: 80,
                    color: Color(0xFF2D46B9),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Waiting for the presenter to start the quiz...',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D46B9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Get ready! The quiz will begin soon.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF666666),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D46B9).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person,
                        size: 18,
                        color: Color(0xFF2D46B9),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'You joined as: ${widget.participantName}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2D46B9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Display current question
    final currentQuestion = _questions[_currentQuestionIndex];
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D46B9),
        foregroundColor: Colors.white,
        title: Text('${widget.quiz.title} - Live'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'Q${_currentQuestionIndex + 1}/${_questions.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0F4FF), Colors.white],
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timer display
            Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                  color: _remainingTime < 10
                      ? const Color(0xFFFFEBEE)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Row(
                      children: [
                        Icon(
                          Icons.timer,
                          color: _remainingTime < 10 
                              ? const Color(0xFFE53935)
                              : const Color(0xFF2D46B9),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                  const Text(
                    'Time Remaining:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _remainingTime < 10
                            ? const Color(0xFFE53935)
                            : const Color(0xFF2D46B9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                    _formatTime(_remainingTime),
                        style: const TextStyle(
                          fontSize: 18,
                      fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Question display
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                  ),
                ],
              ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Text(
              currentQuestion.text,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars,
                            size: 16,
                            color: Color(0xFF2D46B9),
                          ),
                          const SizedBox(width: 4),
            Text(
              'Points: ${currentQuestion.points}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2D46B9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Answers section
              if (_currentAnswers.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No answer options available',
                      style: TextStyle(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF757575),
                      ),
                    ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _currentAnswers.length,
                  itemBuilder: (context, index) {
                    final answer = _currentAnswers[index];
                    final isSelected = _selectedAnswerId == answer.id;
                    
                      // Color palette for answers
                      final List<Color> answerColors = [
                        const Color(0xFF42A5F5), // Blue
                        const Color(0xFF66BB6A), // Green
                        const Color(0xFFFFCA28), // Amber
                        const Color(0xFFEF5350), // Red
                        const Color(0xFF9575CD), // Purple
                        const Color(0xFF4DD0E1), // Cyan
                        const Color(0xFFFF7043), // Deep Orange
                        const Color(0xFF7E57C2), // Deep Purple
                      ];
                      
                      Color cardBgColor = Colors.white;
                      Color cardBorderColor = const Color(0xFFEEEEEE);
                      Widget? trailingWidget;
                    
                    if (_hasAnswered && isSelected) {
                      // This is the selected answer
                      if (_isCorrect == true) {
                        // Correct answer
                          cardBgColor = const Color(0xFFE8F5E9);
                          cardBorderColor = const Color(0xFF66BB6A);
                          trailingWidget = Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF66BB6A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 18),
                          );
                      } else {
                        // Incorrect answer
                          cardBgColor = const Color(0xFFFFEBEE);
                          cardBorderColor = const Color(0xFFE53935);
                          trailingWidget = Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53935),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                          );
                      }
                    } else if (_hasAnswered && answer.isCorrect) {
                      // Show correct answer after user has answered
                        cardBgColor = const Color(0xFFE8F5E9).withOpacity(0.5);
                        cardBorderColor = const Color(0xFF66BB6A);
                        trailingWidget = Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF66BB6A).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Color(0xFF388E3C), size: 18),
                        );
                    } else if (isSelected) {
                      // Selected but not submitted
                        cardBgColor = const Color(0xFFE3F2FD);
                        cardBorderColor = const Color(0xFF2D46B9);
                        trailingWidget = Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2D46B9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 18),
                        );
                      }
                      
                      return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: cardBorderColor,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                        onTap: _hasAnswered || _remainingTime <= 0
                            ? null
                            : () => _submitAnswer(answer.id),
                            borderRadius: BorderRadius.circular(12),
                            splashColor: answerColors[index % answerColors.length].withOpacity(0.1),
                            highlightColor: answerColors[index % answerColors.length].withOpacity(0.05),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // Letter/number indicator
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _hasAnswered || isSelected
                                          ? cardBorderColor
                                          : answerColors[index % answerColors.length],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        String.fromCharCode(65 + index), // A, B, C, etc.
                                        style: TextStyle(
                                          color: _hasAnswered || isSelected 
                                              ? (_isCorrect == true ? Colors.white : Colors.white)
                                              : Colors.white,
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
                                        fontSize: 18,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: const Color(0xFF424242),
                                      ),
                                    ),
                                  ),
                                  if (trailingWidget != null) trailingWidget,
                                ],
                              ),
                            ),
                          ),
                      ),
                    );
                  },
                ),
              ),
                
              // Waiting for next question or score display
            if (_hasAnswered)
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isCorrect == true ? Icons.check_circle : Icons.info_outline,
                        color: _isCorrect == true ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                    'Waiting for the next question...',
                    style: TextStyle(
                      fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF616161),
                        ),
                      ),
                    ],
                  ),
                ),
                
              // Score display
              if (_score > 0)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D46B9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 12),
                      Text(
                  'Current Score: $_score',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildScoreSummary() {
    final totalPossibleScore = _questions.fold(0, (sum, question) => sum + question.points);
    final percentage = totalPossibleScore > 0 ? (_score / totalPossibleScore * 100).round() : 0;
    
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0F4FF), Colors.white],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Trophy with confetti animation effect
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D46B9).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    size: 80,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Quiz Completed!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D46B9),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: 300,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_score',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D46B9),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '/ $totalPossibleScore',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: percentage > 70 
                          ? const Color(0xFFE8F5E9)
                          : percentage > 40
                              ? const Color(0xFFFFF8E1)
                              : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$percentage% Correct',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: percentage > 70 
                            ? const Color(0xFF388E3C)
                            : percentage > 40
                                ? const Color(0xFFF57F17)
                                : const Color(0xFFD32F2F),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Questions Answered: $_totalAnswered / ${_questions.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF616161),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D46B9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 3,
              ),
              child: const Text(
                'Exit Session',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 