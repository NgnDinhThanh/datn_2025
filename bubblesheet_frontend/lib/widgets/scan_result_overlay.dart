import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:bubblesheet_frontend/models/scanning_result.dart';
import 'package:bubblesheet_frontend/models/exam_model.dart';

/// ZipGrade-style overlay card shown after scanning in continuous mode
class ScanResultOverlay extends StatelessWidget {
  final ScanningResult result;
  final ExamModel quiz;
  final VoidCallback onDismiss; // Called when ERASE PAPER is tapped
  final VoidCallback? onChangeStudent;
  final VoidCallback onReviewPaper;

  const ScanResultOverlay({
    Key? key,
    required this.result,
    required this.quiz,
    required this.onDismiss,
    this.onChangeStudent,
    required this.onReviewPaper,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.0),
      child: SafeArea(
        child: Stack(
          children: [
            // Background - NO dismiss on tap (only ERASE PAPER dismisses)
            Positioned.fill(
              child: Container(),
            ),
            // Card content - full width, positioned at center
            Center(
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  width: double.infinity, // Full width
                  child: Card(
                    elevation: 8,
                    color: Colors.grey.withOpacity(0.9), // Semi-transparent grey
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      // Header with cropped info section (student ID, quiz ID, class ID - like ZipGrade)
                      if (result.infoSectionBase64 != null || result.warpedImageBase64 != null || result.annotatedImageBase64 != null)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: Container(
                            height: 100,
                            width: double.infinity,
                            color: Colors.white,
                            child: Image.memory(
                              base64Decode(result.infoSectionBase64 ?? result.warpedImageBase64 ?? result.annotatedImageBase64!),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image,
                                size: 48,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      
                      // Info content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Quiz Name
                            _buildInfoRow('Quiz Name', quiz.name),
                            const SizedBox(height: 4),
                            
                            // Student ID
                            _buildInfoRow('ID', result.studentId.isNotEmpty 
                                ? result.studentId 
                                : 'N/A'),
                            const SizedBox(height: 12),
                            
                            // Score - large and prominent
                            Center(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  children: [
                                    TextSpan(text: 'Score '),
                                    TextSpan(
                                      text: '${result.score} / ${result.totalQuestions}',
                                      style: TextStyle(
                                        color: _getScoreColor(result.percentage),
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' = ${result.percentage.toStringAsFixed(0)} %',
                                      style: TextStyle(
                                        color: _getScoreColor(result.percentage),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            // Multiple marks and blank counts
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStatChip(
                                  'Mult. Marks',
                                  result.multipleMarks.toString(),
                                  result.multipleMarks > 0 ? Colors.orange : Colors.grey,
                                ),
                                const SizedBox(width: 24),
                                _buildStatChip(
                                  'Blank',
                                  result.blankCount.toString(),
                                  result.blankCount > 0 ? Colors.orange : Colors.grey,
                                ),
                              ],
                            ),
                            
                          ],
                        ),
                      ),
                      
                      // Action buttons
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          children: [
                            if (onChangeStudent != null) ...[
                              Expanded(
                                child: _ActionButton(
                                  label: 'CHANGE\nSTUDENT',
                                  onPressed: onChangeStudent!,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            // ERASE PAPER - dismisses and discards
                            Expanded(
                              child: _ActionButton(
                                label: 'ERASE\nPAPER',
                                onPressed: onDismiss,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // REVIEW PAPER - go to result screen
                            Expanded(
                              child: _ActionButton(
                                label: 'REVIEW\nPAPER',
                                onPressed: onReviewPaper,
                                isPrimary: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? const Color(0xFF2E7D32) : Colors.grey[300],
        foregroundColor: isPrimary ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

