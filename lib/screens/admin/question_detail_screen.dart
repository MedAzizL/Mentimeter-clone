import 'package:flutter/material.dart';
import 'package:mentimeter_app/models/answer.dart';
import 'package:mentimeter_app/models/question.dart';
import 'package:mentimeter_app/services/quiz_service.dart';
import 'package:uuid/uuid.dart';

class QuestionDetailScreen extends StatefulWidget {
  final String? questionId;
  final String? quizId;

  const QuestionDetailScreen({
    super.key,
    this.questionId,
    this.quizId,
  }) : assert(questionId != null || quizId != null);

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  final _quizService = QuizService();
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _timeLimitController = TextEditingController();
  final _pointsController = TextEditingController();
  final List<TextEditingController> _answerControllers = [];
  final List<bool> _isCorrectAnswers = [];
  Question? _question;
  bool _isLoading = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.questionId != null) {
      _loadQuestion();
    } else {
      _initializeNewQuestion();
    }
  }

  Future<void> _loadQuestion() async {
    setState(() => _isLoading = true);
    try {
      _question = await _quizService.getQuestionById(widget.questionId!);
      final answers = await _quizService.getAnswersByQuestionId(widget.questionId!);
      
      _textController.text = _question!.text;
      _timeLimitController.text = _question!.timeLimit.toString();
      _pointsController.text = _question!.points.toString();

      for (var answer in answers) {
        _answerControllers.add(TextEditingController(text: answer.text));
        _isCorrectAnswers.add(answer.isCorrect);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isEditing = true;
        });
      }
    }
  }

  void _initializeNewQuestion() {
    _textController.text = '';
    _timeLimitController.text = '30';
    _pointsController.text = '100';
    
    // Initialize with 4 empty answers
    for (int i = 0; i < 4; i++) {
      _answerControllers.add(TextEditingController());
      _isCorrectAnswers.add(false);
    }
    
    setState(() {
      _isLoading = false;
      _isEditing = false;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _timeLimitController.dispose();
    _pointsController.dispose();
    for (var controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveQuestion() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final answers = List.generate(
          _answerControllers.length,
          (index) => Answer(
            id: const Uuid().v4(),
            questionId: _question?.id ?? '',
            text: _answerControllers[index].text,
            isCorrect: _isCorrectAnswers[index],
          ),
        );

        final correctAnswerId = answers
            .firstWhere((answer) => answer.isCorrect)
            .id;

        if (_isEditing) {
          // Update existing question
          final updatedQuestion = Question(
            id: _question!.id,
            quizId: _question!.quizId,
            text: _textController.text,
            timeLimit: int.parse(_timeLimitController.text),
            answerIds: answers.map((a) => a.id).toList(),
            correctAnswerId: correctAnswerId,
            points: int.parse(_pointsController.text),
          );

          await _quizService.updateQuestion(updatedQuestion);
          for (var answer in answers) {
            await _quizService.updateAnswer(answer);
          }
        } else {
          // Create new question
          await _quizService.createQuestion(
            quizId: widget.quizId!,
            text: _textController.text,
            timeLimit: int.parse(_timeLimitController.text),
            answers: answers,
            correctAnswerId: correctAnswerId,
            points: int.parse(_pointsController.text),
          );
        }

        if (mounted) {
          Navigator.pop(context);
        }
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Question' : 'New Question'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: 'Question Text',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the question text';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _timeLimitController,
                          decoration: const InputDecoration(
                            labelText: 'Time Limit (seconds)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter time limit';
                            }
                            final number = int.tryParse(value);
                            if (number == null || number <= 0) {
                              return 'Please enter a valid time limit';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _pointsController,
                          decoration: const InputDecoration(
                            labelText: 'Points',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter points';
                            }
                            final number = int.tryParse(value);
                            if (number == null || number <= 0) {
                              return 'Please enter valid points';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Answers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(
                    _answerControllers.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _answerControllers[index],
                              decoration: InputDecoration(
                                labelText: 'Answer ${index + 1}',
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter answer text';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Checkbox(
                            value: _isCorrectAnswers[index],
                            onChanged: (value) {
                              setState(() {
                                // Uncheck all other answers
                                for (int i = 0;
                                    i < _isCorrectAnswers.length;
                                    i++) {
                                  _isCorrectAnswers[i] = false;
                                }
                                _isCorrectAnswers[index] = value!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveQuestion,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : Text(_isEditing ? 'Update Question' : 'Create Question'),
                  ),
                ],
              ),
            ),
    );
  }
} 