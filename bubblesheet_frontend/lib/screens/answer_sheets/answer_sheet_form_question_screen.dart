import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/answer_sheet_form_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/answer_sheet_service.dart';
import 'package:go_router/go_router.dart';
import '../../providers/answer_sheet_provider.dart';

class AnswerSheetFormQuestionScreen extends StatefulWidget {
  const AnswerSheetFormQuestionScreen({Key? key}) : super(key: key);

  @override
  State<AnswerSheetFormQuestionScreen> createState() => _AnswerSheetFormQuestionScreenState();
}

class _AnswerSheetFormQuestionScreenState extends State<AnswerSheetFormQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _optionLabels = ['A', 'B', 'C', 'D', 'E'];
  Uint8List? _previewImage;
  bool _isGeneratingPreview = false;

  Future<void> _generatePreview(BuildContext context) async {
    final formProvider = Provider.of<AnswerSheetFormProvider>(context, listen: false);
    final token = Provider.of<AuthProvider>(context, listen: false).token;

    setState(() {
      _isGeneratingPreview = true;
    });

    try {
      final previewBytes = await AnswerSheetService.generatePreview(
          formProvider.toApiJson(),
          token
      );
      setState(() {
        _previewImage = previewBytes;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating preview: $e')),
      );
    } finally {
      setState(() {
        _isGeneratingPreview = false;
      });
    }
  }

  Future<void> _publishSheet(BuildContext context) async {
    final formProvider = Provider.of<AnswerSheetFormProvider>(context, listen: false);
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish Answer Sheet'),
        content: const Text('Are you sure you want to publish this form?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        await AnswerSheetService.createAnswerSheet(
            formProvider.toApiJson(),
            token
        );
        // Fetch lại danh sách answer sheet trước khi chuyển route
        await Provider.of<AnswerSheetProvider>(context, listen: false).fetchAnswerSheets(context);
        Navigator.of(context).pop(); // Đóng loading
        formProvider.reset();
        context.go('/answer-sheets');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Answer sheet created!')));
      } catch (e) {
        Navigator.of(context).pop(); // Đóng loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formProvider = Provider.of<AnswerSheetFormProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 4 of 5: Define Questions'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cột trái: cấu hình và danh sách câu hỏi (cuộn)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sheet Name: ${formProvider.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Number of Questions:'),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: formProvider.numQuestions,
                          items: List.generate(100, (i) => i + 1)
                              .map((q) => DropdownMenuItem(value: q, child: Text('$q')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              formProvider.setNumQuestions(val);
                              // Cập nhật danh sách câu hỏi
                              final newQuestions = List.generate(val, (i) =>
                                  QuestionField(
                                    number: i + 1,
                                    type: 'Internal Label',
                                    labels: _optionLabels.take(formProvider.numOptions).join(),
                                  )
                              );
                              formProvider.setQuestions(newQuestions);
                            }
                          },
                        ),
                        const SizedBox(width: 24),
                        const Text('Number of Options:'),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: formProvider.numOptions,
                          items: List.generate(5, (i) => i + 2)
                              .map((o) => DropdownMenuItem(value: o, child: Text('$o')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              formProvider.setNumOptions(val);
                              // Cập nhật nhãn đáp án cho từng câu
                              final updatedQuestions = formProvider.questions.map((q) =>
                                  QuestionField(
                                    number: q.number,
                                    type: q.type,
                                    labels: _optionLabels.take(val).join(),
                                  )
                              ).toList();
                              formProvider.setQuestions(updatedQuestions);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Questions List:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // Danh sách câu hỏi (cuộn)
                    Expanded(
                      child: ListView.builder(
                        itemCount: formProvider.questions.length,
                        itemBuilder: (context, i) {
                          final q = formProvider.questions[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            child: ListTile(
                              title: Text('Question ${q.number}'),
                              subtitle: Text('Options: ${q.labels}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: formProvider.questions.length > 1
                                    ? () {
                                  final newList = List<QuestionField>.from(formProvider.questions);
                                  newList.removeAt(i);
                                  // Đánh lại số thứ tự
                                  for (int j = 0; j < newList.length; j++) {
                                    newList[j] = QuestionField(
                                      number: j + 1,
                                      type: newList[j].type,
                                      labels: newList[j].labels,
                                    );
                                  }
                                  formProvider.setQuestions(newList);
                                  formProvider.setNumQuestions(newList.length); // Giảm số lượng câu hỏi
                                }
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isGeneratingPreview ? null : () => _generatePreview(context),
                      icon: _isGeneratingPreview
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.preview),
                      label: Text(_isGeneratingPreview ? 'Generating Preview...' : 'Generate Preview'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _publishSheet(context),
                          icon: const Icon(Icons.publish),
                          label: const Text('Publish'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // Cột phải: preview
              Expanded(
                flex: 3,
                child: Container(
                  height: 600,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _previewImage != null
                      ? Image.memory(_previewImage!, fit: BoxFit.contain)
                      : const Center(child: Text('No preview')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 