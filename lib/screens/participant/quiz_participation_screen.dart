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
        _currentQuestionIndex = widget.session.currentQuestionIndex;
      });
      await _loadCurrentAnswers();
      _startQuestionTimer();
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
    
    // Create a new timer that checks more frequently (every 2 seconds)
    _sessionCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      _checkForQuestionChange();
    });
  }
  
  Future<void> _checkForQuestionChange() async {
    try {
      final updatedSession = await _sessionService.getSessionById(widget.session.id);
      if (updatedSession == null || !updatedSession.isActive) {
        // Session ended
        if (mounted && !_quizCompleted) {
          setState(() {
            _quizCompleted = true;
          });
        }
        return;
      }
      
      // Vérifier si le timer a démarré dans la session
      if (updatedSession.timerStarted && (_questionTimer == null || !_questionTimer!.isActive)) {
        // Si le temps dans la session est plus petit, utiliser celui-ci car il est plus précis
        if (updatedSession.remainingTime > 0 && 
            (updatedSession.remainingTime < _remainingTime || _remainingTime <= 0)) {
          setState(() {
            _remainingTime = updatedSession.remainingTime;
          });
        }
        _startQuestionTimer();
      }
      
      // Si le temps restant est défini dans la session et est différent de notre valeur locale
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
  
  Widget _buildScoreSummary() {
    final totalPossibleScore = _questions.fold(0, (sum, question) => sum + question.points);
    final percentage = totalPossibleScore > 0 ? (_score / totalPossibleScore * 100).round() : 0;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.emoji_events,
            size: 80,
            color: Colors.amber,
          ),
          const SizedBox(height: 24),
          const Text(
            'Quiz Completed!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your Score: $_score / $totalPossibleScore',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$percentage% Correct',
            style: const TextStyle(
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Questions Answered: $_totalAnswered / ${_questions.length}',
            style: const TextStyle(
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Exit Session'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.quiz.title} - Live'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Quiz completed
    if (_quizCompleted) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.quiz.title} - Results'),
        ),
        body: _buildScoreSummary(),
      );
    }

    // Quiz ended or no questions
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.quiz.title} - Live'),
        ),
        body: const Center(
          child: Text(
            'Waiting for the next question...',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    // Display current question
    final currentQuestion = _questions[_currentQuestionIndex];
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.quiz.title} - Live'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                'Question ${_currentQuestionIndex + 1}/${_questions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timer display
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: _remainingTime < 10 ? Colors.red.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Time Remaining:',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    _formatTime(_remainingTime),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _remainingTime < 10 ? Colors.red : Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              currentQuestion.text,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Points: ${currentQuestion.points}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (_currentAnswers.isEmpty)
              const Center(
                child: Text('No answer options available', 
                  style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _currentAnswers.length,
                  itemBuilder: (context, index) {
                    final answer = _currentAnswers[index];
                    final isSelected = _selectedAnswerId == answer.id;
                    
                    // Determine colors based on answer status
                    Color? cardColor;
                    Widget? trailing;
                    
                    if (_hasAnswered && isSelected) {
                      // This is the selected answer
                      if (_isCorrect == true) {
                        // Correct answer
                        cardColor = Colors.green.shade100;
                        trailing = const Icon(Icons.check_circle, color: Colors.green);
                      } else {
                        // Incorrect answer
                        cardColor = Colors.red.shade100;
                        trailing = const Icon(Icons.cancel, color: Colors.red);
                      }
                    } else if (_hasAnswered && answer.isCorrect) {
                      // Show correct answer after user has answered
                      cardColor = Colors.green.shade50;
                      trailing = const Icon(Icons.check, color: Colors.green);
                    } else if (isSelected) {
                      // Selected but not submitted
                      cardColor = Colors.blue.shade100;
                      trailing = const Icon(Icons.radio_button_checked);
                    }
                    
                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          answer.text,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onTap: _hasAnswered || _remainingTime <= 0
                            ? null
                            : () => _submitAnswer(answer.id),
                        trailing: trailing,
                      ),
                    );
                  },
                ),
              ),
            if (_hasAnswered)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'Waiting for the next question...',
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            // Show current score
            if (_score > 0)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  'Current Score: $_score',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 