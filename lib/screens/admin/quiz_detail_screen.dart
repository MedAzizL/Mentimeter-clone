import 'package:flutter/material.dart';
import 'package:mentimeter_app/models/question.dart';
import 'package:mentimeter_app/models/quiz.dart';
import 'package:mentimeter_app/screens/admin/question_detail_screen.dart';
import 'package:mentimeter_app/services/quiz_service.dart';

class QuizDetailScreen extends StatefulWidget {
  final String quizId;

  const QuizDetailScreen({
    super.key,
    required this.quizId,
  });

  @override
  State<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends State<QuizDetailScreen> {
  final _quizService = QuizService();
  Quiz? _quiz;
  List<Question> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuizAndQuestions();
  }

  Future<void> _loadQuizAndQuestions() async {
    setState(() => _isLoading = true);
    try {
      _quiz = await _quizService.getQuiz(widget.quizId);
      _questions = await _quizService.getQuestionsByQuizId(widget.quizId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleQuizStatus() async {
    if (_quiz == null) return;

    try {
      if (_quiz!.isActive) {
        await _quizService.stopQuiz(_quiz!.id);
      } else {
        await _quizService.startQuiz(_quiz!.id);
      }
      await _loadQuizAndQuestions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _deleteQuiz() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quiz'),
        content: const Text('Are you sure you want to delete this quiz?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _quizService.deleteQuiz(_quiz!.id);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_quiz?.title ?? 'Loading...'),
        actions: [
          IconButton(
            icon: Icon(_quiz?.isActive ?? false
                ? Icons.stop_circle
                : Icons.play_circle),
            onPressed: _toggleQuizStatus,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteQuiz,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadQuizAndQuestions,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _quiz?.description ?? '',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: _questions.isEmpty
                        ? const Center(
                            child: Text('No questions yet. Add your first question!'),
                          )
                        : ListView.builder(
                            itemCount: _questions.length,
                            itemBuilder: (context, index) {
                              final question = _questions[index];
                              return QuestionCard(
                                question: question,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => QuestionDetailScreen(
                                        questionId: question.id,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuestionDetailScreen(
                quizId: widget.quizId,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class QuestionCard extends StatelessWidget {
  final Question question;
  final VoidCallback onTap;

  const QuestionCard({
    super.key,
    required this.question,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(question.text),
        subtitle: Text('Time limit: ${question.timeLimit} seconds'),
        trailing: Text('${question.points} points'),
        onTap: onTap,
      ),
    );
  }
} 