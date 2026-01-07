import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/exam_provider.dart';
import '../../providers/answer_sheet_provider.dart';
import '../../providers/class_provider.dart';
import '../../models/exam_model.dart';


class QuizFormScreen extends StatefulWidget {
  final ExamModel? quiz; // null nếu là tạo mới, có giá trị nếu là sửa

  const QuizFormScreen({Key? key, this.quiz}) : super(key: key);

  @override
  State<QuizFormScreen> createState() => _QuizFormScreenState();
}

class _QuizFormScreenState extends State<QuizFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dateController;
  String? _selectedAnswerSheetId;
  DateTime? _selectedDate;
  Set<String> _selectedClassCodes = {};

  @override
  void initState() {
    super.initState();
    final quiz = widget.quiz;
    _nameController = TextEditingController(text: quiz?.name ?? '');
    _selectedAnswerSheetId = quiz?.answersheet;
    _selectedDate = quiz != null && quiz.date.isNotEmpty
        ? DateTime.tryParse(quiz.date)
        : DateTime.now();
    _dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(_selectedDate ?? DateTime.now()),
    );
    _selectedClassCodes = quiz != null
        ? Set<String>.from(quiz.class_codes)
        : {};
    // Fetch answer sheets & classes nếu chưa có
    Future.microtask(() {
      final answerSheetProvider = Provider.of<AnswerSheetProvider>(context, listen: false);
      if (answerSheetProvider.answerSheets.isEmpty) {
        answerSheetProvider.fetchAnswerSheets(context);
      }
      final classProvider = Provider.of<ClassProvider>(context, listen: false);
      if (classProvider.classes.isEmpty) {
        classProvider.fetchClasses(context);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveQuiz() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAnswerSheetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an answer sheet.')));
      return;
    }
    if (_selectedClassCodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one class.')));
      return;
    }
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final data = {
      'name': _nameController.text.trim(),
      'answersheet': _selectedAnswerSheetId,
      'date': _selectedDate?.toIso8601String().substring(0, 10) ?? DateTime.now().toIso8601String().substring(0, 10),
      'class_codes': _selectedClassCodes.toList(),
    };
    String? quizId;
    String? oldAnswerSheetId = widget.quiz?.answersheet;
    if (widget.quiz == null) {
      quizId = await examProvider.addExam(context, data);
    } else {
      quizId = await examProvider.updateExam(context, widget.quiz!.id, data);
    }
    if (quizId != null && mounted) {
      if (widget.quiz != null && oldAnswerSheetId != _selectedAnswerSheetId) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Answer Sheet Changed'),
            content: const Text('You have changed the answer sheet. Please generate new answer keys for this quiz!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/quizzes/$quizId/edit-answer-keys');
                },
                child: const Text('Generate Answer Key'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/quizzes/$quizId');
                },
                child: const Text('Back to Quiz Detail'),
              ),
            ],
          ),
        );
      } else {
        context.go('/quizzes/$quizId');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final answerSheetProvider = Provider.of<AnswerSheetProvider>(context);
    final classProvider = Provider.of<ClassProvider>(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Text(
                widget.quiz == null ? 'Add New Quiz' : 'Edit Quiz: ${widget.quiz!.name}',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Center(
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Quiz Name'),
                            validator: (value) => value == null || value.trim().isEmpty ? 'Quiz name required' : null,
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            value: _selectedAnswerSheetId,
                            decoration: const InputDecoration(labelText: 'Answer Sheet'),
                            items: answerSheetProvider.answerSheets
                                .map((sheet) => DropdownMenuItem(
                                      value: sheet.id,
                                      child: Text(sheet.name),
                                    ))
                                .toList(),
                            onChanged: (value) => setState(() => _selectedAnswerSheetId = value),
                            validator: (value) => value == null ? 'Please select an answer sheet' : null,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _dateController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Date',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_today),
                                onPressed: _pickDate,
                              ),
                            ),
                            onTap: _pickDate,
                            validator: (value) => value == null || value.isEmpty ? 'Please select a date' : null,
                          ),
                          const SizedBox(height: 20),
                          const Text('Classes:', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(
                            height: 180,
                            child: ListView(
                              shrinkWrap: true,
                              children: classProvider.classes.map((c) => CheckboxListTile(
                                    value: _selectedClassCodes.contains(c.class_code),
                                    title: Text(c.class_name),
                                    onChanged: (selected) {
                                      setState(() {
                                        if (selected == true) {
                                          _selectedClassCodes.add(c.class_code);
                                        } else {
                                          _selectedClassCodes.remove(c.class_code);
                                        }
                                      });
                                    },
                                  )).toList(),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: _saveQuiz,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                child: const Text('Save Quiz'),
                              ),
                              const SizedBox(width: 24),
                              OutlinedButton(
                                onPressed: () {
                                  if (widget.quiz != null) {
                                    context.go('/quizzes/${widget.quiz!.id}');
                                  } else {
                                    context.go('/quizzes');
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}