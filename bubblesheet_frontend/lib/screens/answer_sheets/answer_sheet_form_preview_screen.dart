import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../../providers/answer_sheet_form_provider.dart';
import '../../providers/answer_sheet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/answer_sheet_service.dart';
import 'package:go_router/go_router.dart';

class AnswerSheetFormPreviewScreen extends StatefulWidget {
  const AnswerSheetFormPreviewScreen({Key? key}) : super(key: key);

  @override
  State<AnswerSheetFormPreviewScreen> createState() => _AnswerSheetFormPreviewScreenState();
}

class _AnswerSheetFormPreviewScreenState extends State<AnswerSheetFormPreviewScreen> {
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

  @override
  void initState() {
    super.initState();
    // Generate preview when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generatePreview(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final formProvider = Provider.of<AnswerSheetFormProvider>(context);
    final answerSheetProvider = Provider.of<AnswerSheetProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 5 of 5: Preview & Publish'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - Form details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Sheet Name: ${formProvider.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('Headers:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...formProvider.headers.where((h) => h.enabled).map((h) => Text('${h.label} (${h.width})')),
                    const SizedBox(height: 16),
                    Text('Student ID: ${formProvider.studentIdLabel} (${formProvider.studentIdDigits} digits)'),
                    Text('Class ID: ${formProvider.classIdLabel} (${formProvider.classIdDigits} digits)'),
                    Text('Exam ID: ${formProvider.examIdLabel} (${formProvider.examIdDigits} digits)'),
                    const SizedBox(height: 16),
                    Text('Questions: ${formProvider.numQuestions} x ${formProvider.numOptions} options'),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isGeneratingPreview ? null : () => _generatePreview(context),
                      icon: _isGeneratingPreview 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                      label: Text(_isGeneratingPreview ? 'Generating Preview...' : 'Refresh Preview'),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            context.go('/answer-sheets/create/question/');
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Publish Answer Sheet'),
                                content: const Text('Are you sure you want to publish this form? Once published, no further changes may be made to this custom form.'),
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
                                await answerSheetProvider.createAnswerSheet(
                                  context,
                                  formProvider.toApiJson()
                                );
                                Navigator.of(context).pop(); // Đóng loading
                                formProvider.reset();
                                context.go('/answer-sheets');
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Answer sheet created!')));
                              } catch (e) {
                                Navigator.of(context).pop(); // Đóng loading
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            }
                          },
                          icon: const Icon(Icons.publish),
                          label: const Text('Publish'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Right side - Preview
              if (_previewImage != null) ...[
                const SizedBox(width: 24),
                Container(
                  width: 400,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Preview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Image.memory(
                          _previewImage!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 