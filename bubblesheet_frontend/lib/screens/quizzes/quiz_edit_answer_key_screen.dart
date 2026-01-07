import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/exam_provider.dart';
import '../../services/answer_key_service.dart';

class QuizEditAnswerKeyScreen extends StatefulWidget {
  final String quizId;
  const QuizEditAnswerKeyScreen({
    required this.quizId,
    Key? key,
  }) : super(key: key);

  @override
  State<QuizEditAnswerKeyScreen> createState() => _QuizEditAnswerKeyScreenState();
}

class _QuizEditAnswerKeyScreenState extends State<QuizEditAnswerKeyScreen> {
  PlatformFile? _answerFile;
  final TextEditingController _numVersionsController = TextEditingController();
  bool _isGenerating = false;
  String? _error;
  List<Map<String, dynamic>>? _generatedKeys;
  late String quizName;
  late int quizIdDigits;
  late int numQuestions;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuizData();
  }

  Future<void> _loadQuizData() async {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final quiz = examProvider.exams.firstWhere((e) => e.id == widget.quizId);
    setState(() {
      quizName = quiz.name;
      quizIdDigits = 3; // Or fetch from quiz config
      numQuestions = 50; // Or fetch from quiz config
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _numVersionsController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _error = null);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _answerFile = result.files.first;
      });
    }
  }

  Future<void> _generateKeys() async {
    if (_answerFile == null) {
      setState(() => _error = 'Please upload an answer bank file.');
      return;
    }

    final numVersions = int.tryParse(_numVersionsController.text.trim());
    if (numVersions == null || numVersions <= 0) {
      setState(() => _error = 'Please enter a valid number of versions.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
      _generatedKeys = null;
    });

    try {
      final result = await AnswerKeyService.generateAnswerKeys(
        context: context,
        quizId: widget.quizId,
        numVersions: numVersions,
        answerFile: _answerFile!,
      );

      if (result['success']) {
        // Parse response data
        final data = result['data'];
        setState(() {
          _generatedKeys = List<Map<String, dynamic>>.from(data['versions']);
        });
      } else {
        setState(() => _error = result['error']);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Answer Keys for $quizName'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text('Upload Answer Bank File', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _pickFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Choose File'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_answerFile?.name ?? 'No file selected', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Number of Versions', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _numVersionsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter number of versions',
                  ),
                  enabled: !_isGenerating,
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generateKeys,
                      icon: _isGenerating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.shuffle),
                      label: Text(_isGenerating ? 'Generating...' : 'Generate Answer Keys'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () {
                        context.go('/quizzes/${widget.quizId}');
                      },
                      child: const Text('Back to Quiz Detail'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (_generatedKeys != null) ...[
                  const Divider(),
                  Text('Generated Answer Keys', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: _generatedKeys!.length,
                      itemBuilder: (context, i) {
                        final version = _generatedKeys![i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text('Version ${version['version_code']}'),
                            subtitle: Text(
                              version['questions']
                                  .map((q) => '${q['order']}: ${q['answer']}')
                                  .join(', '),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await AnswerKeyService.downloadAllAnswerKeysExcel(context, widget.quizId);
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Download All'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}