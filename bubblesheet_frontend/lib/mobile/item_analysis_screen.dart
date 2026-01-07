import 'package:bubblesheet_frontend/services/item_analysis_cache_service.dart';
import 'package:bubblesheet_frontend/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exam_model.dart';
import '../models/grade_model.dart';
import '../services/grading_service.dart';
import '../providers/auth_provider.dart';

class ItemAnalysisScreen extends StatefulWidget {
  final ExamModel quiz;

  const ItemAnalysisScreen({
    Key? key,
    required this.quiz,
  }) : super(key: key);

  @override
  State<ItemAnalysisScreen> createState() => _ItemAnalysisScreenState();
}

class _ItemAnalysisScreenState extends State<ItemAnalysisScreen> {
  ItemAnalysisModel? _analysis;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    String quizId = widget.quiz.id;
    if (quizId.startsWith('ObjectId(')) {
      quizId = quizId.substring(9, quizId.length - 2);
    }

    try {
      final cached = ItemAnalysisCacheService.getCachedItemAnalysis(quizId);
      if (cached != null) {
        // ✅ Hiển thị cache ngay
        setState(() {
          _analysis = cached;
          _isLoading = false;
        });

        // ✅ BỎ check network - không cần thiết khi đã có cache
        // Fetch từ API ở background (nếu có mạng) để update cache
        final token = Provider.of<AuthProvider>(context, listen: false).token;
        if (token != null) {
          // Check network ở background, không block UI
          SyncService.hasNetworkConnection().then((hasNetwork) {
            if (hasNetwork && mounted) {
              // Fetch ở background
              GradingService.getItemAnalysis(quizId, token).then((analysis) async {
                if (analysis != null && mounted) {
                  await ItemAnalysisCacheService.cacheItemAnalysis(quizId, analysis);
                  if (mounted) {
                    setState(() {
                      _analysis = analysis;
                    });
                  }
                }
              }).catchError((e) {
                print('[ItemAnalysis] Error fetching fresh analysis: $e');
              });
            }
          });
        }
        return; // ✅ Return ngay
      }
    } catch (e) {
      print('[ItemAnalysis] Error loading cached analysis: $e');
    }

    // Chỉ fetch từ API nếu không có cache
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token != null) {
      final hasNetwork = await SyncService.hasNetworkConnection();
      if (hasNetwork) {
        try {
          final analysis = await GradingService.getItemAnalysis(quizId, token);
          if (analysis != null) {
            await ItemAnalysisCacheService.cacheItemAnalysis(quizId, analysis);
          }

          setState(() {
            _analysis = analysis;
            _isLoading = false;
          });
        } catch (e) {
          if (_analysis == null) {
            setState(() {
              _error = e.toString();
              _isLoading = false;
            });
          }
        }
      } else {
        if (_analysis == null) {
          setState(() {
            _error = 'No data. Please connect network.';
            _isLoading = false;
          });
        }
      }
    } else {
      if (_analysis == null) {
        setState(() {
          _error = 'Not authenticated';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Analysis'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalysis,
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
                        'Error loading analysis',
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
                        onPressed: _loadAnalysis,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _analysis == null || _analysis!.totalPapers == 0
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No data available',
                            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scan some papers to see analysis',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Statistics Summary
                          _buildStatisticsCard(_analysis!.statistics),
                          const SizedBox(height: 24),
                          // Items List
                          const Text(
                            'Question Analysis',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._analysis!.items.map((item) => _buildItemCard(item)),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildStatisticsCard(StatisticsModel stats) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overall Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('Min', stats.minScore.toStringAsFixed(1)),
                ),
                Expanded(
                  child: _buildStatItem('Max', stats.maxScore.toStringAsFixed(1)),
                ),
                Expanded(
                  child: _buildStatItem('Avg', stats.averageScore.toStringAsFixed(1)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('Avg %', '${stats.averagePercent.toStringAsFixed(1)}%'),
                ),
                Expanded(
                  child: _buildStatItem('Median', stats.medianScore.toStringAsFixed(1)),
                ),
                Expanded(
                  child: _buildStatItem('Std Dev', stats.stdDeviation.toStringAsFixed(2)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(ItemModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Q${item.questionNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Correct: ${item.correctAnswer}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                _getDifficultyIcon(item.correctPercent),
              ],
            ),
            const SizedBox(height: 16),
            // Progress bars
            _buildProgressBar(
              'Correct',
              item.correctPercent,
              item.correctCount,
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildProgressBar(
              'Incorrect',
              item.incorrectPercent,
              item.incorrectCount,
              Colors.red,
            ),
            const SizedBox(height: 8),
            _buildProgressBar(
              'Blank',
              item.blankPercent,
              item.blankCount,
              Colors.grey,
            ),
            const SizedBox(height: 12),
            // Counts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCountChip('Correct', item.correctCount, Colors.green),
                _buildCountChip('Wrong', item.incorrectCount, Colors.red),
                _buildCountChip('Blank', item.blankCount, Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(String label, double percent, int count, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percent / 100,
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            '${percent.toStringAsFixed(1)}% ($count)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getDifficultyIcon(double correctPercent) {
    if (correctPercent >= 80) {
      return Tooltip(
        message: 'Easy',
        child: Icon(Icons.sentiment_very_satisfied, color: Colors.green),
      );
    } else if (correctPercent >= 50) {
      return Tooltip(
        message: 'Medium',
        child: Icon(Icons.sentiment_neutral, color: Colors.orange),
      );
    } else {
      return Tooltip(
        message: 'Hard',
        child: Icon(Icons.sentiment_very_dissatisfied, color: Colors.red),
      );
    }
  }
}


