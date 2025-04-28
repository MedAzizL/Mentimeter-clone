import 'package:flutter/material.dart';
import 'package:mentimeter_app/models/quiz.dart';
import 'package:mentimeter_app/screens/admin/quiz_detail_screen.dart';
import 'package:mentimeter_app/services/auth_service.dart';
import 'package:mentimeter_app/services/quiz_service.dart';
import 'package:uuid/uuid.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _quizService = QuizService();
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
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createQuiz() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const CreateQuizDialog(),
    );

    if (result != null) {
      try {
        await _quizService.createQuiz(Quiz(
          id: const Uuid().v4(),
          title: result['title']!,
          description: result['description']!,
          adminId: _authService.currentUser!.uid,
          createdAt: DateTime.now(),
          questionIds: [],
          isActive: false,
        ));
        await _loadQuizzes();
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
        title: const Text('My Quizzes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadQuizzes,
              child: _quizzes.isEmpty
                  ? const Center(
                      child: Text('No quizzes yet. Create your first quiz!'),
                    )
                  : ListView.builder(
                      itemCount: _quizzes.length,
                      itemBuilder: (context, index) {
                        final quiz = _quizzes[index];
                        return QuizCard(
                          quiz: quiz,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    QuizDetailScreen(quizId: quiz.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createQuiz,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class QuizCard extends StatelessWidget {
  final Quiz quiz;
  final VoidCallback onTap;

  const QuizCard({
    super.key,
    required this.quiz,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(quiz.title),
        subtitle: Text(quiz.description),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              quiz.isActive ? Icons.play_circle : Icons.pause_circle,
              color: quiz.isActive ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text('${quiz.questionIds.length} questions'),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class CreateQuizDialog extends StatefulWidget {
  const CreateQuizDialog({super.key});

  @override
  State<CreateQuizDialog> createState() => _CreateQuizDialogState();
}

class _CreateQuizDialogState extends State<CreateQuizDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Quiz'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'title': _titleController.text,
                'description': _descriptionController.text,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
} 