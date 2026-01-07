import 'dart:convert';
import 'package:bubblesheet_frontend/services/grade_cache_service.dart';
import 'package:bubblesheet_frontend/services/grading_result_queue_service.dart';
import 'package:bubblesheet_frontend/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../models/exam_model.dart';
import '../models/grade_model.dart';
import '../services/grading_service.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'package:flutter/scheduler.dart';

class ReviewPapersScreen extends StatefulWidget {
  final ExamModel quiz;

  const ReviewPapersScreen({Key? key, required this.quiz}) : super(key: key);

  @override
  State<ReviewPapersScreen> createState() => _ReviewPapersScreenState();
}

class _ReviewPapersScreenState extends State<ReviewPapersScreen> {
  List<GradeModel> _grades = [];
  bool _isLoading = true;
  String? _error;
  int _lastPendingCount = 0; // Track pending count để refresh khi có thay đổi
  bool _isLoadingGrades = false; // Flag để tránh gọi _loadGrades() nhiều lần cùng lúc

  @override
  void initState() {
    super.initState();
    _loadGrades();
    _lastPendingCount = _getPendingCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Update pending count
    final currentPendingCount = _getPendingCount();
    // ✅ Nếu pending count thay đổi, refresh ngay
    if (currentPendingCount != _lastPendingCount && !_isLoadingGrades) {
      _lastPendingCount = currentPendingCount;
      _loadGrades();
    } else {
      _lastPendingCount = currentPendingCount;
    }
  }

  int _getPendingCount() {
    String quizId = widget.quiz.id;
    if (quizId.startsWith('ObjectId(')) {
      quizId = quizId.substring(9, quizId.length - 2);
    }
    final pendingResults = GradingResultQueueService.getPendingResults();
    return pendingResults.where((item) {
      try {
        final dataRaw = item['data'];
        if (dataRaw == null) return false;
        final data = Map<String, dynamic>.from(dataRaw as Map);
        final itemQuizId = data['quizId']?.toString() ?? data['quiz_id']?.toString();
        return itemQuizId == quizId;
      } catch (e) {
        return false;
      }
    }).length;
  }

  Future<void> _loadGrades() async {
    // ✅ Tránh gọi nhiều lần cùng lúc
    if (_isLoadingGrades) {
      print('[ReviewPapers] _loadGrades() already in progress, skipping...');
      return;
    }
    
    _isLoadingGrades = true;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    String quizId = widget.quiz.id;
    if (quizId.startsWith('ObjectId(')) {
      quizId = quizId.substring(9, quizId.length - 2);
    }

    try {
      final cachedGrades = GradeCacheService.getCachedGradesForQuiz(quizId);
      final allGrades = <GradeModel>[];
      
      // Thêm cached grades
      if (cachedGrades != null && cachedGrades.isNotEmpty) {
        allGrades.addAll(cachedGrades);
      }

      // ✅ Lấy pending results và convert thành GradeModel
      final pendingResults = GradingResultQueueService.getPendingResults();
      print('[ReviewPapers] Total pending results: ${pendingResults.length}');
      final pendingForQuiz = pendingResults.where((item) {
        try {
          final dataRaw = item['data'];
          if (dataRaw == null) return false;
          final data = Map<String, dynamic>.from(dataRaw as Map);
          final itemQuizId =
              data['quizId']?.toString() ?? data['quiz_id']?.toString();
          return itemQuizId == quizId;
        } catch (e) {
          return false;
        }
      }).toList();
      print('[ReviewPapers] Pending results for quiz $quizId: ${pendingForQuiz.length}');

      // Convert pending results thành GradeModel
      int mergedCount = 0;
      int skippedCount = 0;
      for (var pendingItem in pendingForQuiz) {
        try {
          final dataRaw = pendingItem['data'];
          if (dataRaw == null) continue;
          final data = Map<String, dynamic>.from(dataRaw as Map);
          
          // ✅ Normalize values để so sánh đúng (null -> empty string)
          final studentId = (data['studentId']?.toString() ?? data['student_id']?.toString() ?? '').trim();
          final classId = (data['classId']?.toString() ?? data['class_id']?.toString() ?? '').trim();
          final versionCode = (data['versionCode']?.toString() ?? data['version_code']?.toString() ?? '').trim();
          
          // ✅ Check duplicate với normalized values
          final alreadyExists = allGrades.any((g) {
            final gStudentId = (g.studentId ?? '').trim();
            final gClassCode = (g.classCode ?? '').trim();
            final gVersionCode = (g.versionCode ?? '').trim();
            
            return gStudentId == studentId && 
                   gClassCode == classId &&
                   gVersionCode == versionCode;
          });
          
          if (!alreadyExists) {
            // Tạo GradeModel từ pending result
            allGrades.add(GradeModel(
              id: pendingItem['id']?.toString() ?? 'pending_${DateTime.now().millisecondsSinceEpoch}',
              classCode: classId.isEmpty ? '' : classId,
              examId: quizId,
              studentId: studentId.isEmpty ? '' : studentId,
              score: data['score'] != null ? (data['score'] is int ? data['score'].toDouble() : data['score']) : null,
              percentage: data['percentage'] != null ? (data['percentage'] is int ? data['percentage'].toDouble() : data['percentage']) : null,
              answers: data['answers'] is Map ? Map<String, dynamic>.from(data['answers']) : {},
              scannedImage: data['scannedImage']?.toString() ?? data['scanned_image']?.toString(),
              annotatedImage: data['annotatedImage']?.toString() ?? data['annotated_image']?.toString(),
              scannedAt: data['scannedAt'] != null ? DateTime.tryParse(data['scannedAt'].toString()) : 
                        (data['scanned_at'] != null ? DateTime.tryParse(data['scanned_at'].toString()) : DateTime.now()),
              versionCode: versionCode.isEmpty ? null : versionCode,
              answersheetId: data['answersheetId']?.toString() ?? data['answersheet_id']?.toString(),
            ));
            mergedCount++;
            print('[ReviewPapers] Merged pending result: studentId=$studentId, classId=$classId, versionCode=$versionCode');
          } else {
            skippedCount++;
            print('[ReviewPapers] Skipped duplicate pending result: studentId=$studentId, classId=$classId, versionCode=$versionCode');
          }
        } catch (e) {
          print('[ReviewPapers] Error converting pending result to GradeModel: $e');
        }
      }
      print('[ReviewPapers] Merge summary: merged=$mergedCount, skipped=$skippedCount');

      // ✅ Luôn set grades (dù empty hay không) và set loading = false
      print('[ReviewPapers] Total grades after merge (offline): ${allGrades.length} (cached: ${cachedGrades?.length ?? 0}, pending: ${pendingForQuiz.length})');
      if (mounted) {
        setState(() {
          _grades = allGrades;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[ReviewPapers] Error loading cached grades: $e');
      // ✅ Vẫn set loading = false khi có lỗi
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } finally {
      _isLoadingGrades = false;
    }

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token != null) {
      final hasNetwork = await SyncService.hasNetworkConnection();
      if (hasNetwork) {
        try {
          final grades = await GradingService.getGradesForQuiz(quizId, token);
          await GradeCacheService.cacheGradesForQuiz(quizId, grades);

          // ✅ Merge với pending results sau khi fetch từ API
          final allGradesFromApi = <GradeModel>[];
          allGradesFromApi.addAll(grades);

          // Lấy pending results và merge vào
          final pendingResults = GradingResultQueueService.getPendingResults();
          final pendingForQuiz = pendingResults.where((item) {
            try {
              final dataRaw = item['data'];
              if (dataRaw == null) return false;
              final data = Map<String, dynamic>.from(dataRaw as Map);
              final itemQuizId =
                  data['quizId']?.toString() ?? data['quiz_id']?.toString();
              return itemQuizId == quizId;
            } catch (e) {
              return false;
            }
          }).toList();

          // Convert pending results thành GradeModel và merge
          int mergedCount = 0;
          int skippedCount = 0;
          for (var pendingItem in pendingForQuiz) {
            try {
              final dataRaw = pendingItem['data'];
              if (dataRaw == null) continue;
              final data = Map<String, dynamic>.from(dataRaw as Map);
              
              // ✅ Normalize values để so sánh đúng (null -> empty string)
              final studentId = (data['studentId']?.toString() ?? data['student_id']?.toString() ?? '').trim();
              final classId = (data['classId']?.toString() ?? data['class_id']?.toString() ?? '').trim();
              final versionCode = (data['versionCode']?.toString() ?? data['version_code']?.toString() ?? '').trim();
              
              // ✅ Check duplicate với normalized values
              final alreadyExists = allGradesFromApi.any((g) {
                final gStudentId = (g.studentId ?? '').trim();
                final gClassCode = (g.classCode ?? '').trim();
                final gVersionCode = (g.versionCode ?? '').trim();
                
                return gStudentId == studentId && 
                       gClassCode == classId &&
                       gVersionCode == versionCode;
              });
              
              if (!alreadyExists) {
                allGradesFromApi.add(GradeModel(
                  id: pendingItem['id']?.toString() ?? 'pending_${DateTime.now().millisecondsSinceEpoch}',
                  classCode: classId.isEmpty ? '' : classId,
                  examId: quizId,
                  studentId: studentId.isEmpty ? '' : studentId,
                  score: data['score'] != null ? (data['score'] is int ? data['score'].toDouble() : data['score']) : null,
                  percentage: data['percentage'] != null ? (data['percentage'] is int ? data['percentage'].toDouble() : data['percentage']) : null,
                  answers: data['answers'] is Map ? Map<String, dynamic>.from(data['answers']) : {},
                  scannedImage: data['scannedImage']?.toString() ?? data['scanned_image']?.toString(),
                  annotatedImage: data['annotatedImage']?.toString() ?? data['annotated_image']?.toString(),
                  scannedAt: data['scannedAt'] != null ? DateTime.tryParse(data['scannedAt'].toString()) : 
                            (data['scanned_at'] != null ? DateTime.tryParse(data['scanned_at'].toString()) : DateTime.now()),
                  versionCode: versionCode.isEmpty ? null : versionCode,
                  answersheetId: data['answersheetId']?.toString() ?? data['answersheet_id']?.toString(),
                ));
                mergedCount++;
                print('[ReviewPapers] Merged pending result (online): studentId=$studentId, classId=$classId, versionCode=$versionCode');
              } else {
                skippedCount++;
                print('[ReviewPapers] Skipped duplicate pending result (online): studentId=$studentId, classId=$classId, versionCode=$versionCode');
              }
            } catch (e) {
              print('[ReviewPapers] Error converting pending result to GradeModel: $e');
            }
          }
          print('[ReviewPapers] Merge summary (online): merged=$mergedCount, skipped=$skippedCount');

          print('[ReviewPapers] Total grades after merge (online): ${allGradesFromApi.length} (from API: ${grades.length}, pending: ${pendingForQuiz.length})');
          if (mounted) {
            setState(() {
              _grades = allGradesFromApi; // ✅ Dùng merged grades
              _isLoading = false;
            });
          }
        } catch (e) {
          if (mounted) {
            if (_grades.isEmpty) {
              setState(() {
                _error = e.toString();
                _isLoading = false;
              });
            }
          }
        } finally {
          _isLoadingGrades = false;
        }
      } else {
        if (mounted) {
          if (_grades.isEmpty) {
            setState(() {
              _error = 'No data. Please connect network.';
              _isLoading = false;
            });
          }
        }
        _isLoadingGrades = false;
      }
    } else {
      if (mounted) {
        if (_grades.isEmpty) {
          setState(() {
            _error = 'Not authenticated';
            _isLoading = false;
          });
        }
      }
      _isLoadingGrades = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Check và refresh khi có pending results mới (khi quay lại screen)
    // Chỉ check một lần mỗi frame để tránh refresh quá nhiều
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isLoadingGrades) return;
      final pendingCount = _getPendingCount();
      if (pendingCount != _lastPendingCount) {
        _lastPendingCount = pendingCount;
        _loadGrades(); // Refresh để hiển thị papers mới
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Papers'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGrades,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading papers',
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadGrades,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _grades.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No papers found',
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan some papers to see them here',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Summary card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        'Total Papers',
                        _grades.length.toString(),
                        Icons.description,
                      ),
                      _buildSummaryItem(
                        'Avg Score',
                        _grades.isNotEmpty
                            ? (_grades
                                          .map((g) => g.score ?? 0)
                                          .reduce((a, b) => a + b) /
                                      _grades.length)
                                  .toStringAsFixed(1)
                            : '0.0',
                        Icons.bar_chart,
                      ),
                      _buildSummaryItem(
                        'Avg %',
                        _grades.isNotEmpty
                            ? (_grades
                                              .map((g) => g.percentage ?? 0)
                                              .reduce((a, b) => a + b) /
                                          _grades.length)
                                      .toStringAsFixed(1) +
                                  '%'
                            : '0%',
                        Icons.percent,
                      ),
                    ],
                  ),
                ),
                // Papers list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _grades.length,
                    itemBuilder: (context, index) {
                      final grade = _grades[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: _getScoreColor(
                              grade.percentage ?? 0,
                            ),
                            child: Text(
                              '${grade.percentage?.toStringAsFixed(0) ?? 0}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            'Student ID: ${grade.studentId}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.class_,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Class: ${grade.classCode}',
                                      style: TextStyle(color: Colors.grey[600]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (grade.versionCode != null) ...[
                                    const SizedBox(width: 16),
                                    Icon(
                                      Icons.code,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Version: ${grade.versionCode}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Score: ${grade.score?.toStringAsFixed(1) ?? 0}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (grade.scannedAt != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDateTime(grade.scannedAt!),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
                          ),
                          onTap: () {
                            _showPaperDetail(grade);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF2E7D32), size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showPaperDetail(GradeModel grade) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Paper Details',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailRow('Student ID', grade.studentId),
                _buildDetailRow('Class Code', grade.classCode),
                if (grade.versionCode != null)
                  _buildDetailRow('Version Code', grade.versionCode!),
                _buildDetailRow(
                  'Score',
                  '${grade.score?.toStringAsFixed(1) ?? 0}',
                ),
                _buildDetailRow(
                  'Percentage',
                  '${grade.percentage?.toStringAsFixed(1) ?? 0}%',
                ),
                if (grade.scannedAt != null)
                  _buildDetailRow(
                    'Scanned At',
                    _formatDateTime(grade.scannedAt!),
                  ),
                if (grade.annotatedImage != null &&
                    grade.annotatedImage!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Annotated Image',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildAnnotatedImage(grade.annotatedImage!),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Answers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (grade.answers.isEmpty)
                  const Text(
                    'No answers recorded',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: grade.answers.entries.map((entry) {
                      return Chip(
                        label: Text('Q${entry.key}: ${entry.value}'),
                        backgroundColor: Colors.grey[100],
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnotatedImage(String imagePath) {
    // Check if it's a URL or base64
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      // It's a URL - load from server
      return FutureBuilder<String?>(
        future: _loadImageFromServer(imagePath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Text(
              'Could not load image',
              style: TextStyle(color: Colors.red),
            );
          }
          return _buildImageFromBase64(snapshot.data!);
        },
      );
    } else if (imagePath.startsWith('data:image') || imagePath.length > 100) {
      // It's base64
      String base64Data = imagePath;
      if (imagePath.startsWith('data:image')) {
        base64Data = imagePath.split(',')[1];
      }
      return _buildImageFromBase64(base64Data);
    } else {
      // It's a file path - construct full URL
      String fullUrl = imagePath;
      if (!imagePath.startsWith('http')) {
        // Construct full URL from baseUrl
        final baseUrl = ApiService.baseUrl.replaceAll('/api', '');
        fullUrl = '$baseUrl$imagePath';
      }
      return FutureBuilder<String?>(
        future: _loadImageFromServer(fullUrl),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Text(
              'Could not load image',
              style: TextStyle(color: Colors.red),
            );
          }
          return _buildImageFromBase64(snapshot.data!);
        },
      );
    }
  }

  Future<String?> _loadImageFromServer(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        return base64Encode(bytes);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Widget _buildImageFromBase64(String base64String) {
    try {
      final bytes = base64Decode(base64String);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(bytes, fit: BoxFit.contain),
      );
    } catch (e) {
      return const Text(
        'Could not display image',
        style: TextStyle(color: Colors.red),
      );
    }
  }
}
