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
          SnackBar(content: Text('Error loading question: ${e.toString()}')),
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
      // Check if at least one answer is marked as correct
      if (!_isCorrectAnswers.contains(true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please mark at least one answer as correct'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Check if there are at least 2 answer options
      if (_answerControllers.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need at least 2 answer options'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      setState(() => _isLoading = true);
      try {
        if (_isEditing) {
          // Update existing question
          // First, get existing answers to compare
          List<Answer> existingAnswers = await _quizService.getAnswersByQuestionId(_question!.id);
          
          // Create new answer objects with proper IDs
          final answers = List.generate(
            _answerControllers.length,
            (index) {
              // Check if this might be an existing answer we're updating
              if (index < existingAnswers.length) {
                // Update existing answer with new text and isCorrect value
                return Answer(
                  id: existingAnswers[index].id,
                  questionId: _question!.id,
                  text: _answerControllers[index].text,
                  isCorrect: _isCorrectAnswers[index],
                );
              } else {
                // This is a new answer
                return Answer(
                  id: const Uuid().v4(),
                  questionId: _question!.id,
                  text: _answerControllers[index].text,
                  isCorrect: _isCorrectAnswers[index],
                );
              }
            },
          );
          
          // Make sure at least one answer is marked as correct
          if (!answers.any((answer) => answer.isCorrect)) {
            // If no answer is marked as correct, make the first one correct
            answers[0] = Answer(
              id: answers[0].id,
              questionId: answers[0].questionId,
              text: answers[0].text,
              isCorrect: true,
            );
          }
          
          final correctAnswerId = answers
              .firstWhere((answer) => answer.isCorrect)
              .id;
              
          final updatedQuestion = Question(
            id: _question!.id,
            quizId: _question!.quizId,
            text: _textController.text,
            timeLimit: int.parse(_timeLimitController.text),
            answerIds: answers.map((a) => a.id).toList(),
            correctAnswerId: correctAnswerId,
            points: int.parse(_pointsController.text),
          );

          // Update question first
          await _quizService.updateQuestion(updatedQuestion);
          
          // If we have existing answers to delete (fewer answers now than before)
          if (existingAnswers.length > answers.length) {
            // Delete excess answers from Firestore
            for (int i = answers.length; i < existingAnswers.length; i++) {
              await _quizService.deleteAnswer(existingAnswers[i].id);
            }
          }
          
          // Create or update answers
          for (var answer in answers) {
            // Try to find if this answer already exists
            bool exists = false;
            for (var existingAnswer in existingAnswers) {
              if (existingAnswer.id == answer.id) {
                exists = true;
                break;
              }
            }
            
            if (exists) {
              // Update existing answer
              await _quizService.updateAnswer(answer);
            } else {
              // Create new answer
              await _quizService.createAnswer(answer);
            }
          }
        } else {
          // Create new question
          final answers = List.generate(
            _answerControllers.length,
            (index) => Answer(
              id: const Uuid().v4(),
              questionId: _question?.id ?? const Uuid().v4(),
              text: _answerControllers[index].text,
              isCorrect: _isCorrectAnswers[index],
            ),
          );

          // Make sure at least one answer is marked as correct
          if (!answers.any((answer) => answer.isCorrect)) {
            // If no answer is marked as correct, make the first one correct
            answers[0] = Answer(
              id: answers[0].id,
              questionId: answers[0].questionId,
              text: answers[0].text,
              isCorrect: true,
            );
          }

          final correctAnswerId = answers
              .firstWhere((answer) => answer.isCorrect)
              .id;
              
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
        print('Error saving question: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
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
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              if (_answerControllers.length > 2) {
                                setState(() {
                                  _answerControllers.removeAt(index);
                                  _isCorrectAnswers.removeAt(index);
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('You need at least 2 answers'),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Answer Option'),
                    onPressed: () {
                      setState(() {
                        _answerControllers.add(TextEditingController());
                        _isCorrectAnswers.add(false);
                      });
                    },
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