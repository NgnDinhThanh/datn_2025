import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:bubblesheet_frontend/models/scanning_result.dart';
import 'package:bubblesheet_frontend/models/exam_model.dart';
import 'package:bubblesheet_frontend/models/answer_sheet_model.dart';
import 'package:bubblesheet_frontend/providers/scanning_provider.dart';
import 'package:bubblesheet_frontend/providers/auth_provider.dart';
import 'package:bubblesheet_frontend/mobile/scanning_screen.dart';

class ScanningResultScreen extends StatefulWidget {
  final ScanningResult result;
  final ExamModel quiz;
  final AnswerSheet answerSheet;
  final File? scannedImage;

  const ScanningResultScreen({
    Key? key,
    required this.result,
    required this.quiz,
    required this.answerSheet,
    this.scannedImage,
  }) : super(key: key);

  @override
  State<ScanningResultScreen> createState() => _ScanningResultScreenState();
}

class _ScanningResultScreenState extends State<ScanningResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Removed _isSaving and _isSaved - grades are auto-saved via queue + sync

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Removed _saveGrade() - grades are auto-saved via queue + sync in nativeScanAndGrade()

  /// Convert answer index (0-4) to letter (A-E)
  String _indexToLetter(dynamic answer) {
    if (answer == null || answer == -1) return '';
    
    int index;
    if (answer is int) {
      index = answer;
    } else if (answer is List && answer.isNotEmpty) {
      index = answer[0] is int ? answer[0] : -1;
    } else {
      return '';
    }
    
    if (index < 0 || index > 4) return '';
    return String.fromCharCode('A'.codeUnitAt(0) + index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text(
          'PAPER',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            final scanningProvider = Provider.of<ScanningProvider>(context, listen: false);
            scanningProvider.clearResults();
            Navigator.of(context).pop(true);
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'scan_another':
                  final scanningProvider = Provider.of<ScanningProvider>(context, listen: false);
                  scanningProvider.clearResults();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ScanningScreen(
                        quiz: widget.quiz,
                        answerSheet: widget.answerSheet,
                      ),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'scan_another',
                child: Row(
                  children: [
                    Icon(Icons.camera_alt),
                    SizedBox(width: 8),
                    Text('Scan Another'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with thumbnail and score
          _buildHeader(),
          
          // Tab bar
          Container(
            color: Colors.grey[100],
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2E7D32),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF2E7D32),
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'IMAGE'),
                Tab(text: 'QUESTIONS'),
                Tab(text: 'TAGS'),
              ],
            ),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildImageTab(),
                _buildQuestionsTab(),
                _buildTagsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    // Use info section (cropped ID area) if available, fallback to annotated image
    final thumbnailBase64 = widget.result.infoSectionBase64 ?? widget.result.annotatedImageBase64;
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Thumbnail - shows info section (student/quiz/class IDs)
          if (thumbnailBase64 != null)
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
                color: Colors.grey[100],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(thumbnailBase64),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey),
                ),
              ),
            ),
          const SizedBox(height: 12),
          
          // Score display
          Text(
            '${widget.result.score} / ${widget.result.totalQuestions} = ${widget.result.percentage.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _getScoreColor(widget.result.percentage),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageTab() {
    if (widget.result.annotatedImageBase64 == null ||
        widget.result.annotatedImageBase64!.isEmpty) {
      return const Center(
        child: Text('No annotated image available'),
      );
    }

    try {
      final bytes = base64Decode(widget.result.annotatedImageBase64!);
      return GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _FullscreenImageViewer(imageBytes: bytes),
            ),
          );
        },
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.memory(
              Uint8List.fromList(bytes),
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    } catch (e) {
      return const Center(
        child: Text('Could not display annotated image'),
      );
    }
  }

  Widget _buildQuestionsTab() {
    final correctAnswers = widget.result.correctAnswers ?? {};
    final studentAnswers = widget.result.answers;
    
    // Build list of questions
    final questions = <_QuestionRow>[];
    for (int i = 1; i <= widget.result.totalQuestions; i++) {
      final key = i.toString();
      final correctAns = correctAnswers[key];
      final studentAns = studentAnswers[key];
      
      final correctLetter = _indexToLetter(correctAns);
      final studentLetter = _indexToLetter(studentAns);
      
      // Check if multiple marks (student answered with list of multiple items)
      String studentResponse = studentLetter;
      if (studentAns is List && studentAns.length > 1) {
        studentResponse = studentAns.map((a) => _indexToLetter(a)).join('');
      }
      
      // Determine if correct
      bool isCorrect = false;
      bool isBlank = studentAns == null || studentAns == -1 || 
                     (studentAns is List && studentAns.isEmpty);
      
      if (!isBlank && correctAns != null) {
        if (studentAns is int && correctAns is int) {
          isCorrect = studentAns == correctAns;
        } else if (studentAns is List && studentAns.isNotEmpty) {
          isCorrect = studentAns[0] == correctAns;
        }
      }
      
      questions.add(_QuestionRow(
        number: i,
        primaryAnswer: correctLetter,
        studentResponse: studentResponse,
        pointsEarned: isCorrect ? 1 : 0,
        priPoints: 1,
        isCorrect: isCorrect,
        isBlank: isBlank,
      ));
    }

    return Column(
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 40, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(width: 70, child: Text('Primary\nAnswer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(width: 70, child: Text('Student\nResponse', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(width: 60, child: Text('Points\nEarned', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(width: 50, child: Text('Pri\nPoints', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Spacer(),
            ],
          ),
        ),
        
        // Questions list
        Expanded(
          child: ListView.builder(
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final q = questions[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${q.number}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        q.primaryAnswer,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        q.studentResponse.isEmpty ? '' : q.studentResponse,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: q.isBlank ? Colors.orange : Colors.black,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${q.pointsEarned}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${q.priPoints}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const Spacer(),
                    // Status icon
                    if (q.isBlank)
                      const Text('—', style: TextStyle(color: Colors.orange, fontSize: 18))
                    else if (q.isCorrect)
                      const Text('C', style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                      ))
                    else
                      const Text('X', style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                      )),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTagsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.label_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No tags available',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }
}

class _QuestionRow {
  final int number;
  final String primaryAnswer;
  final String studentResponse;
  final int pointsEarned;
  final int priPoints;
  final bool isCorrect;
  final bool isBlank;

  _QuestionRow({
    required this.number,
    required this.primaryAnswer,
    required this.studentResponse,
    required this.pointsEarned,
    required this.priPoints,
    required this.isCorrect,
    required this.isBlank,
  });
}

/// Full screen image viewer with zoom and pan
class _FullscreenImageViewer extends StatelessWidget {
  final Uint8List imageBytes;

  const _FullscreenImageViewer({
    required this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Annotated Image',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          panEnabled: true,
          scaleEnabled: true,
          child: Image.memory(
            imageBytes,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
