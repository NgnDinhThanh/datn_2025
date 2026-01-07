import 'package:bubblesheet_frontend/mobile/quiz_detail_screen.dart';
import 'package:bubblesheet_frontend/mobile/quiz_form_dialog.dart';
import 'package:bubblesheet_frontend/models/exam_model.dart';
import 'package:bubblesheet_frontend/providers/class_provider.dart';
import 'package:bubblesheet_frontend/providers/exam_provider.dart';
import 'package:bubblesheet_frontend/providers/auth_provider.dart';
import 'package:bubblesheet_frontend/services/grade_cache_service.dart';
import 'package:bubblesheet_frontend/services/grading_result_queue_service.dart';
import 'package:bubblesheet_frontend/services/grading_service.dart';
import 'package:bubblesheet_frontend/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class QuizzesScreen extends StatefulWidget {
  const QuizzesScreen({Key? key}) : super(key: key);

  @override
  State<QuizzesScreen> createState() => _QuizzesScreenState();
}

class _QuizzesScreenState extends State<QuizzesScreen> {
  String _search = '';
  String _sortKey = 'Date';
  final List<String> _sortOptions = ['Date', 'Name'];
  Map<String, int> _papersCountCache = {}; // Cache papers count for each quiz

  @override
  void initState() {
    super.initState();
    ApiService.setContext(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExamsAndPapersCount();
    });
  }

  Future<void> _loadExamsAndPapersCount() async {
    await Provider.of<ExamProvider>(context, listen: false).fetchExams(context);
    _loadPapersCounts();
  }

  Future<void> _loadPapersCounts() async {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    final Map<String, int> newCache = {};

    for (var exam in examProvider.exams) {
      try {
        String quizId = exam.id;
        if (quizId.startsWith('ObjectId(')) {
          quizId = quizId.substring(9, quizId.length - 2);
        }

        // Load từ cache
        final cachedCount = GradeCacheService.getCacheGradesCount(quizId);

        // Đếm pending results cho quiz này
        final pendingResults = GradingResultQueueService.getPendingResults();
        final pendingCount = pendingResults.where((item) {
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
        }).length;

        newCache[exam.id] = cachedCount + pendingCount;
      } catch (e) {
        newCache[exam.id] = 0;
      }
    }

    if (mounted) {
      setState(() {
        _papersCountCache = newCache;
      });
    }

    final hasNetwork = await SyncService.hasNetworkConnection();
    if (hasNetwork && token != null) {
      for (var exam in examProvider.exams) {
        try {
          String quizId = exam.id;
          if (quizId.startsWith('ObjectId(')) {
            quizId = quizId.substring(9, quizId.length - 2);
          }

          final grades = await GradingService.getGradesForQuiz(quizId, token);
          await GradeCacheService.cacheGradesForQuiz(quizId, grades);

          // Đếm lại pending results
          final pendingResults = GradingResultQueueService.getPendingResults();
          final pendingCount = pendingResults.where((item) {
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
          }).length;

          newCache[exam.id] = grades.length + pendingCount;
        } catch (e) {
          // Giữ nguyên giá trị từ cache nếu API fail
          print('[QuizzScreen] Error loading papers count for ${exam.id}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _papersCountCache = newCache;
        });
      }
    }
  }

  List<ExamModel> _filterAndSort(List<ExamModel> exams) {
    List<ExamModel> filtered = exams;
    // Search
    if (_search.isNotEmpty) {
      filtered = filtered
          .where(
            (s) =>
                s.date.toLowerCase().contains(_search.toLowerCase()) ||
                s.name.toLowerCase().contains(_search.toLowerCase()),
          )
          .toList();
    }
    // Sort
    switch (_sortKey) {
      case 'Date':
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'Name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final classProvider = Provider.of<ClassProvider>(context);
    if (classProvider.classes.isEmpty) {
      Future.microtask(
        () => Provider.of<ClassProvider>(
          context,
          listen: false,
        ).fetchClasses(context),
      );
    }
    if (classProvider.isLoading || classProvider.classes.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final classCodeToName = {
      for (var c in classProvider.classes) c.class_code: c.class_name,
    };
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0, // Hide default AppBar
      ),
      body: Column(
        children: [
          // Custom Header
          Container(
            padding: const EdgeInsets.only(
              top: 16,
              bottom: 16,
              left: 16,
              right: 16,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF2E7D32), // ZipGrade green
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'QUIZZES',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage quizzes',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search and Sort Row
                    Row(
                      children: [
                        // Sort Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2E7D32)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortKey,
                              items: _sortOptions
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(
                                        'Sort\n$e',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _sortKey = v ?? 'Date'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Search Field
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Search',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (v) => setState(() => _search = v),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Consumer<ExamProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.error != null) {
                  return Center(
                    child: Text(
                      'Error: ${provider.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                final exams = _filterAndSort(provider.exams);
                if (exams.isEmpty) {
                  return const Center(child: Text('No quizzes found.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: exams.length,
                  itemBuilder: (context, i) {
                    final s = exams[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                s.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              'Papers: ${_papersCountCache[s.id] ?? 0}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              s.class_codes
                                  .map((code) => classCodeToName[code] ?? code)
                                  .join(', '),
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(s.date, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF2E7D32),
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuizDetailScreen(quiz: s),
                            ),
                          );
                          // Refresh papers count after returning from quiz detail
                          if (mounted) {
                            _loadPapersCounts();
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(context: context, builder: (_) => const QuizFormDialog());
        },
        backgroundColor: const Color(0xFF2E7D32),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'NEW QUIZ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
