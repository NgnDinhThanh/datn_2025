import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/exam_provider.dart';
import '../../providers/answer_sheet_provider.dart';
import '../../providers/class_provider.dart';
import '../../models/exam_model.dart';

class QuizFormDialog extends StatefulWidget {
  final ExamModel? quiz;
  final bool showDelete;

  const QuizFormDialog({Key? key, this.quiz, this.showDelete = false})
    : super(key: key);

  @override
  State<QuizFormDialog> createState() => _QuizFormDialogState();
}

class _QuizFormDialogState extends State<QuizFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dateController;
  String? _selectedAnswerSheetId;
  DateTime? _selectedDate;
  Set<String> _selectedClassCodes = {};
  bool _isSaving = false;
  bool _isDeleting = false;

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
    Future.microtask(() async {
      final answerSheetProvider = Provider.of<AnswerSheetProvider>(
        context,
        listen: false,
      );
      if (answerSheetProvider.answerSheets.isEmpty) {
        await answerSheetProvider.fetchAnswerSheets(context);
      }
      final classProvider = Provider.of<ClassProvider>(context, listen: false);
      if (classProvider.classes.isEmpty) {
        await classProvider.fetchClasses(context);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an answer sheet.')),
      );
      return;
    }
    if (_selectedClassCodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one class.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final data = {
      'name': _nameController.text.trim(),
      'answersheet': _selectedAnswerSheetId,
      'date':
          _selectedDate?.toIso8601String().substring(0, 10) ??
          DateTime.now().toIso8601String().substring(0, 10),
      'class_codes': _selectedClassCodes.toList(),
    };
    String? quizId;

    try {
      if (widget.quiz == null) {
        quizId = await examProvider.addExam(context, data);
      } else {
        quizId = await examProvider.updateExam(context, widget.quiz!.id, data);
      }

      if (quizId != null && mounted) {
        Navigator.of(context).pop(quizId);
      }
    } catch (e) {
      // Xử lý lỗi
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving quiz: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _confirmAndDelete() async {
    if (widget.quiz == null) return;
    if (_isSaving || _isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quiz?'),
        content: const Text('This will delete the quiz and cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await context.read<ExamProvider>().deleteExam(context, widget.quiz!.id);
      if (!mounted) return;
      Navigator.of(context).pop('deleted');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting quiz: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final answerSheetProvider = Provider.of<AnswerSheetProvider>(context);
    final classProvider = Provider.of<ClassProvider>(context);
    final isEdit = widget.quiz != null;
    final canDelete = isEdit && widget.showDelete;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Text(
                widget.quiz == null
                    ? 'New Quiz'
                    : 'Edit Quiz: ${widget.quiz!.name}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Center(
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 8,
                  ),
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
                            decoration: const InputDecoration(
                              labelText: 'Quiz Name',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Quiz name required'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            value: _selectedAnswerSheetId,
                            decoration: const InputDecoration(
                              labelText: 'Answer Sheet',
                              border: OutlineInputBorder(),
                            ),
                            isExpanded: true,
                            items: answerSheetProvider.answerSheets.isEmpty
                                ? [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text('Loading...'),
                                    ),
                                  ]
                                : answerSheetProvider.answerSheets
                                      .map(
                                        (sheet) => DropdownMenuItem(
                                          value: sheet.id,
                                          child: Text(sheet.name),
                                        ),
                                      )
                                      .toList(),
                            // Mobile: khi EDIT quiz thì không cho đổi answer sheet
                            onChanged: isEdit
                                ? null
                                : (value) {
                                    setState(
                                      () => _selectedAnswerSheetId = value,
                                    );
                                  },
                            validator: (value) => value == null
                                ? 'Please select an answer sheet'
                                : null,
                          ),
                          if (isEdit) ...[
                            const SizedBox(height: 8),
                            Text(
                              'On mobile, Answer Sheet cannot be changed when editing a quiz.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
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
                            validator: (value) => value == null || value.isEmpty
                                ? 'Please select a date'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Classes:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(
                            height: 180,
                            child: ListView(
                              shrinkWrap: true,
                              children: classProvider.classes
                                  .map(
                                    (c) => CheckboxListTile(
                                      value: _selectedClassCodes.contains(
                                        c.class_code,
                                      ),
                                      title: Text(c.class_name),
                                      onChanged: (selected) {
                                        setState(() {
                                          if (selected == true) {
                                            _selectedClassCodes.add(
                                              c.class_code,
                                            );
                                          } else {
                                            _selectedClassCodes.remove(
                                              c.class_code,
                                            );
                                          }
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 32),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 360;
                              final isBusy = _isSaving || _isDeleting;

                              final saveButton = SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: isBusy ? null : _saveQuiz,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Save'),
                                ),
                              );

                              final deleteButton = canDelete
                                  ? SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: isBusy
                                            ? null
                                            : _confirmAndDelete,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          minimumSize: const Size.fromHeight(
                                            48,
                                          ),
                                        ),
                                        child: _isDeleting
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text('Delete'),
                                      ),
                                    )
                                  : const SizedBox.shrink();

                              final cancelButton = SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: isBusy
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              );

                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    saveButton,
                                    if (canDelete) ...[
                                      const SizedBox(height: 12),
                                      deleteButton,
                                    ],
                                    const SizedBox(height: 12),
                                    cancelButton,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: saveButton),
                                  const SizedBox(width: 12),
                                  if (canDelete) ...[
                                    Expanded(child: deleteButton),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(child: cancelButton),
                                ],
                              );
                            },
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
