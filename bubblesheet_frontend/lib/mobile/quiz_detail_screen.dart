import 'package:bubblesheet_frontend/services/answer_key_cache_service.dart';
import 'package:bubblesheet_frontend/services/grade_cache_service.dart';
import 'package:bubblesheet_frontend/services/grading_result_queue_service.dart';
import 'package:bubblesheet_frontend/services/item_analysis_cache_service.dart';
import 'package:bubblesheet_frontend/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../models/exam_model.dart';
import '../providers/class_provider.dart';
import '../providers/answer_sheet_provider.dart';
import '../providers/auth_provider.dart';
import '../services/grading_service.dart';
import '../models/grade_model.dart';
import 'scanning_screen.dart';
import 'review_papers_screen.dart';
import 'item_analysis_screen.dart';

class QuizDetailScreen extends StatefulWidget {
  final ExamModel quiz;

  const QuizDetailScreen({Key? key, required this.quiz}) : super(key: key);

  @override
  State<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends State<QuizDetailScreen> {
  bool _hasAnswerKey = false;
  int _papersCount = 0;
  bool _isLoadingGrading = true;

  void _printAnswerSheet(BuildContext context, String filePdf) async {
    if (filePdf.isEmpty) return;
    final uri = Uri.parse(filePdf);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open PDF file.')));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGradingStatus();
    });
  }

  Future<void> _checkGradingStatus() async {
    String quizId = widget.quiz.id;
    if (quizId.startsWith('ObjectId(')) {
      quizId = quizId.substring(9, quizId.length - 2);
    }

    setState(() {
      _isLoadingGrading = true;
    });

    bool hasKey = AnswerKeyCacheService.hasAnswerKey(quizId);
    int papersCount = 0;
    try {
      final cachedCount = GradeCacheService.getCacheGradesCount(quizId);
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
          print('[QuizDetail] Error parsing pending result: $e');
          return false;
        }
      }).length;
      papersCount = cachedCount + pendingCount;
    } catch (e) {
      print('[QuizDetail] Error checking cached/pending grades: $e');
      papersCount = 0;
    }

    setState(() {
      _hasAnswerKey = hasKey;
      _papersCount = papersCount;
      _isLoadingGrading = false;
    });

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token != null) {
      final hasNetwork = await SyncService.hasNetworkConnection();
      if (hasNetwork) {
        try {
          // Check answer key từ API
          final hasKeyFromApi = await GradingService.checkAnswerKey(
            quizId,
            token,
          );

          // Get grades từ API
          final grades = await GradingService.getGradesForQuiz(quizId, token);
          await GradeCacheService.cacheGradesForQuiz(quizId, grades);

          // Update pending count
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

          if (mounted) {
            setState(() {
              _hasAnswerKey = hasKeyFromApi;
              _papersCount = grades.length + pendingCount;
            });
          }
        } catch (e) {
          print('[QuizDetail] Error fetching latest data: $e');
          // Không cần xử lý lỗi vì đã có cache data
        }
      }
    }
  }

  Future<ItemAnalysisModel?> _getItemAnalysis() async {
    String quizId = widget.quiz.id;
    if (quizId.startsWith('ObjectId(')) {
      quizId = quizId.substring(9, quizId.length - 2);
    }

    try {
      final cached = ItemAnalysisCacheService.getCachedItemAnalysis(quizId);
      if (cached != null) {
        return cached; // ✅ Return ngay nếu có cache
      }
    } catch (e) {
      print('[QuizDetail] Error loading cached item analysis: $e');
    }

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token != null) {
      final hasNetwork = await SyncService.hasNetworkConnection();
      if (hasNetwork) {
        try {
          final analysis = await GradingService.getItemAnalysis(quizId, token);
          if (analysis != null) {
            await ItemAnalysisCacheService.cacheItemAnalysis(quizId, analysis);
          }
          return analysis;
        } catch (e) {
          print('[QuizDetail] Error fetching item analysis: $e');
          return null;
        }
      }
    }

    return null;
  }

  void _showPrintOptions(BuildContext context, String filePdf) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Chia sẻ link PDF'),
                onTap: () {
                  Share.share(filePdf);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy link'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: filePdf));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã copy link PDF!')),
                  );
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isEnabled,
    bool isDetailsTab = true,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(
          icon,
          color: isDetailsTab
              ? (isEnabled ? Colors.white : Colors.grey)
              : Colors.white,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: isDetailsTab
                ? (isEnabled ? Colors.white : Colors.grey)
                : Colors.white,
            fontSize: 18,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDetailsTab
              ? (isEnabled ? const Color(0xFF2E7D32) : Colors.grey.shade300)
              : const Color(0xFF2E7D32),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 18),
        ),
        onPressed: isEnabled ? onPressed : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classProvider = Provider.of<ClassProvider>(context);
    final answerSheetProvider = Provider.of<AnswerSheetProvider>(context);

    // Nếu danh sách class hoặc answer sheet rỗng, tự động fetch
    if (classProvider.classes.isEmpty) {
      Future.microtask(
        () => Provider.of<ClassProvider>(
          context,
          listen: false,
        ).fetchClasses(context),
      );
    }
    if (answerSheetProvider.answerSheets.isEmpty) {
      Future.microtask(
        () => Provider.of<AnswerSheetProvider>(
          context,
          listen: false,
        ).fetchAnswerSheets(context),
      );
    }

    // Nếu đang loading dữ liệu, show loading indicator
    if (classProvider.isLoading || answerSheetProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final classCodeToName = Provider.of<ClassProvider>(context).classCodeToName;
    String normalizeId(String id) {
      if (id.startsWith('ObjectId(')) {
        return id.substring(9, id.length - 2);
      }
      return id;
    }

    final quizAnswerSheetId = normalizeId(widget.quiz.answersheet);
    final answerSheetList = answerSheetProvider.answerSheets
        .where((a) => a.id == quizAnswerSheetId)
        .toList();
    final answerSheet = answerSheetList.isNotEmpty
        ? answerSheetList.first
        : null;
    final answerSheetName = answerSheet?.name ?? widget.quiz.answersheet;
    final numQuestions = answerSheet?.numQuestions?.toString() ?? '--';
    final filePdf = answerSheet?.filePdf ?? '';

    // Determine button states
    final canScan = _hasAnswerKey && answerSheet != null;
    final canReview = _papersCount > 0;
    final canAnalyze = _papersCount > 0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Quiz Menu',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
              letterSpacing: 2,
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Color(0xFF2E7D32),
            labelColor: Color(0xFF2E7D32),
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            tabs: [
              Tab(text: 'DETAILS'),
              Tab(text: 'STATISTICS'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // DETAILS TAB
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Name',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    Text(
                      widget.quiz.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF2E7D32)),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Classes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    widget.quiz.class_codes
                                        .map(
                                          (code) =>
                                              classCodeToName[code] ?? code,
                                        )
                                        .join(', '),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Answer Sheet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    answerSheetName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (filePdf.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.print,
                                      color: Color(0xFF2E7D32),
                                    ),
                                    tooltip: 'Print Answer Sheet',
                                    onPressed: () =>
                                        _showPrintOptions(context, filePdf),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'Date',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  widget.quiz.date,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'Papers',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  _isLoadingGrading
                                      ? '...'
                                      : _papersCount.toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'Questions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  numQuestions,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          _buildButton(
                            icon: Icons.camera_alt,
                            label: 'SCAN PAPERS',
                            onPressed: canScan
                                ? () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ScanningScreen(
                                          quiz: widget.quiz,
                                          answerSheet: answerSheet!,
                                        ),
                                      ),
                                    );
                                    // Refresh grading status sau khi quay về
                                    if (mounted) {
                                      _checkGradingStatus();
                                    }
                                  }
                                : null,
                            isEnabled: canScan,
                            isDetailsTab: true,
                          ),
                          const SizedBox(height: 8),
                          _buildButton(
                            icon: Icons.image_search,
                            label: 'REVIEW PAPERS',
                            onPressed: canReview
                                ? () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ReviewPapersScreen(
                                          quiz: widget.quiz,
                                        ),
                                      ),
                                    );
                                    // ✅ Refresh grading status sau khi quay về từ ReviewPapersScreen
                                    if (mounted) {
                                      _checkGradingStatus();
                                    }
                                  }
                                : null,
                            isEnabled: canReview,
                            isDetailsTab: true,
                          ),
                          const SizedBox(height: 8),
                          _buildButton(
                            icon: Icons.bar_chart,
                            label: 'ITEM ANALYSIS',
                            onPressed: canAnalyze
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ItemAnalysisScreen(
                                          quiz: widget.quiz,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            isEnabled: canAnalyze,
                            isDetailsTab: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // STATISTICS TAB
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF2E7D32)),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Center(
                              child: Text(
                                'Score Percent',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FutureBuilder<ItemAnalysisModel?>(
                              future: _getItemAnalysis(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                if (snapshot.hasError || !snapshot.hasData) {
                                  return Column(
                                    children: [
                                      _buildStatRow('Min. Score', '--', '--'),
                                      _buildStatRow('Max. Score', '--', '--'),
                                      _buildStatRow('Average', '--', '--'),
                                      _buildStatRow('Median', '--', '--'),
                                      _buildStatRow(
                                        'Std. Deviation',
                                        '--',
                                        '--',
                                      ),
                                    ],
                                  );
                                }
                                final stats = snapshot.data!.statistics;
                                return Column(
                                  children: [
                                    _buildStatRow(
                                      'Min. Score',
                                      stats.minScore.toStringAsFixed(1),
                                      '',
                                    ),
                                    _buildStatRow(
                                      'Max. Score',
                                      stats.maxScore.toStringAsFixed(1),
                                      '',
                                    ),
                                    _buildStatRow(
                                      'Average',
                                      stats.averageScore.toStringAsFixed(1),
                                      '',
                                    ),
                                    _buildStatRow(
                                      'Median',
                                      stats.medianScore.toStringAsFixed(1),
                                      '',
                                    ),
                                    _buildStatRow(
                                      'Std. Deviation',
                                      stats.stdDeviation.toStringAsFixed(2),
                                      '',
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          _buildButton(
                            icon: Icons.camera_alt,
                            label: 'SCAN PAPERS',
                            onPressed: canScan
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ScanningScreen(
                                          quiz: widget.quiz,
                                          answerSheet: answerSheet!,
                                        ),
                                      ),
                                    ).then((_) {
                                      // Refresh grading status after scanning
                                      _checkGradingStatus();
                                    });
                                  }
                                : null,
                            isEnabled: canScan,
                            isDetailsTab: false,
                          ),
                          const SizedBox(height: 8),
                          _buildButton(
                            icon: Icons.image_search,
                            label: 'REVIEW PAPERS',
                            onPressed: canReview
                                ? () async {
                                    // ✅ Pass callback để refresh khi quay lại
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ReviewPapersScreen(
                                          quiz: widget.quiz,
                                        ),
                                      ),
                                    );
                                    // ✅ Refresh grading status sau khi quay về từ ReviewPapersScreen
                                    if (mounted) {
                                      _checkGradingStatus();
                                    }
                                  }
                                : null,
                            isEnabled: canReview,
                            isDetailsTab: false,
                          ),
                          const SizedBox(height: 8),
                          _buildButton(
                            icon: Icons.bar_chart,
                            label: 'ITEM ANALYSIS',
                            onPressed: canAnalyze
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ItemAnalysisScreen(
                                          quiz: widget.quiz,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            isEnabled: canAnalyze,
                            isDetailsTab: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildStatRow(String label, String score, String percent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          Row(
            children: [
              Text(
                score,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 24),
              Text(
                percent,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
