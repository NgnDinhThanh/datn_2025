import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/exam_provider.dart';
import '../../models/exam_model.dart';
import '../../providers/class_provider.dart';
import '../../providers/answer_sheet_provider.dart';
import '../../providers/answer_key_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/grading_service.dart';
import '../../models/grade_model.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class QuizDetailScreen extends StatefulWidget {
  final String quizId;
  const QuizDetailScreen({required this.quizId, Key? key}) : super(key: key);

  @override
  State<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends State<QuizDetailScreen> {
  int? _selectedVersionIndex;
  
  // State for grades and analysis
  List<GradeModel> _grades = [];
  ItemAnalysisModel? _itemAnalysis;
  bool _isLoadingGrades = false;
  bool _isLoadingAnalysis = false;
  String? _errorGrades;
  String? _errorAnalysis;
  Map<String, String> _studentNameCache = {}; // studentId -> name
  Set<String> _selectedGradeIds = {}; // For checkbox selection
  
  // Pagination for grades table
  int _currentPage = 0;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadAnswerKeys();
      _reloadAnswerSheets();
      _loadGrades();
      _loadItemAnalysis();
      _loadStudentNames();
    });
  }

  Future<void> _reloadAnswerKeys() async {
    final answerKeyProvider = Provider.of<AnswerKeyProvider>(context, listen: false);
    await answerKeyProvider.fetchAnswerKeys(context, widget.quizId);
    setState(() {});
  }

  Future<void> _reloadAnswerSheets() async {
    final answerSheetProvider = Provider.of<AnswerSheetProvider>(context, listen: false);
    await answerSheetProvider.fetchAnswerSheets(context);
  }

  Future<void> _loadGrades() async {
    setState(() {
      _isLoadingGrades = true;
      _errorGrades = null;
    });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) {
        throw Exception('No authentication token');
      }
      final grades = await GradingService.getGradesForQuiz(widget.quizId, token);
      setState(() {
        _grades = grades;
        _isLoadingGrades = false;
      });
    } catch (e) {
      setState(() {
        _errorGrades = e.toString();
        _isLoadingGrades = false;
      });
      print('[QuizDetail] Error loading grades: $e');
    }
  }

  Future<void> _loadItemAnalysis() async {
    setState(() {
      _isLoadingAnalysis = true;
      _errorAnalysis = null;
    });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) {
        throw Exception('No authentication token');
      }
      final analysis = await GradingService.getItemAnalysis(widget.quizId, token);
      setState(() {
        _itemAnalysis = analysis;
        _isLoadingAnalysis = false;
      });
    } catch (e) {
      setState(() {
        _errorAnalysis = e.toString();
        _isLoadingAnalysis = false;
      });
      print('[QuizDetail] Error loading item analysis: $e');
    }
  }

  Future<void> _loadStudentNames() async {
    try {
      final studentProvider = Provider.of<StudentProvider>(context, listen: false);
      if (studentProvider.students.isEmpty) {
        await studentProvider.fetchStudents(context);
      }
      final cache = <String, String>{};
      for (var student in studentProvider.students) {
        cache[student.studentId] = '${student.firstName} ${student.lastName}';
      }
      setState(() {
        _studentNameCache = cache;
      });
    } catch (e) {
      print('[QuizDetail] Error loading student names: $e');
    }
  }

  String _getStudentName(String studentId) {
    return _studentNameCache[studentId] ?? studentId;
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final formatter = DateFormat('yyyy/MM/dd hh:mma', 'en_US');
    return formatter.format(dateTime).toLowerCase();
  }

  // Calculate score distribution for chart
  Map<String, int> _calculateScoreDistribution() {
    final distribution = <String, int>{};
    
    // Create 20 bins (0-5%, 5-10%, ..., 95-100%)
    for (int i = 0; i < 20; i++) {
      final minPercent = i * 5.0;
      final maxPercent = (i + 1) * 5.0;
      final label = '${minPercent.toStringAsFixed(1)}%-${maxPercent.toStringAsFixed(1)}%';
      distribution[label] = 0;
    }
    
    // Count grades in each bin
    for (var grade in _grades) {
      final percent = grade.percentage ?? 0.0;
      if (percent < 0) continue;
      
      int binIndex = (percent / 5.0).floor();
      if (binIndex >= 20) binIndex = 19; // Cap at 100%
      
      final minPercent = binIndex * 5.0;
      final maxPercent = (binIndex + 1) * 5.0;
      final label = '${minPercent.toStringAsFixed(1)}%-${maxPercent.toStringAsFixed(1)}%';
      distribution[label] = (distribution[label] ?? 0) + 1;
    }
    
    return distribution;
  }

  // Get max count for chart scaling
  int _getMaxCount() {
    final distribution = _calculateScoreDistribution();
    if (distribution.isEmpty) return 1;
    final max = distribution.values.reduce((a, b) => a > b ? a : b);
    return max > 0 ? max : 1;
  }

  // Build score distribution chart
  Widget _buildScoreDistributionChart() {
    final distribution = _calculateScoreDistribution();
    final maxCount = _getMaxCount();
    final entries = distribution.entries.toList();
    
    // Only show non-zero bins to make chart cleaner
    final nonZeroEntries = entries.where((e) => e.value > 0).toList();
    
    if (nonZeroEntries.isEmpty) {
      return const Center(
        child: Text('No data to display', style: TextStyle(color: Colors.grey)),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxCount.toDouble() * 1.1, // Add 10% padding
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.teal,
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = entries[group.x.toInt()].key;
              final value = rod.toY.toInt();
              return BarTooltipItem(
                '$label\n$value papers',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < entries.length) {
                  final label = entries[index].key;
                  // Show only every 4th label to avoid crowding
                  if (index % 4 == 0 || index == entries.length - 1) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Transform.rotate(
                        angle: -0.5, // Rotate labels
                        child: Text(
                          label.split('-')[0], // Show only start percentage
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    );
                  }
                }
                return const Text('');
              },
              reservedSize: 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value % 10 == 0 || value == meta.max) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.grey.withOpacity(0.3)),
            left: BorderSide(color: Colors.grey.withOpacity(0.3)),
          ),
        ),
        barGroups: entries.asMap().entries.map((entry) {
          final index = entry.key;
          final value = entry.value.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value.toDouble(),
                color: Colors.teal,
                width: 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // Get paginated grades
  List<GradeModel> _getPaginatedGrades() {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _grades.length);
    return _grades.sublist(startIndex, endIndex);
  }

  int _getTotalPages() {
    return (_grades.length / _itemsPerPage).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final examProvider = Provider.of<ExamProvider>(context);
    final classProvider = Provider.of<ClassProvider>(context, listen: false);
    final answerSheetProvider = Provider.of<AnswerSheetProvider>(context, listen: true);
    final answerKeyProvider = Provider.of<AnswerKeyProvider>(context, listen: true);

    final quizList = examProvider.exams.where((e) => e.id == widget.quizId);
    final ExamModel? quiz = quizList.isNotEmpty ? quizList.first : null;
    if (quiz == null) {
      return Scaffold(
        body: const Center(child: Text('Quiz not found')),
      );
    }

    // Lấy tên lớp và answer sheet
    final classNames = quiz.class_codes
        .map((code) {
      final classObj = classProvider.classes.where((c) => c.class_code == code);
      return classObj.isNotEmpty ? classObj.first.class_name : code;
    })
        .join(', ');
    String answerSheetName = 'Unknown';
    String debugAnswerSheetIds = '';
    if (answerSheetProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (answerSheetProvider.answerSheets.isEmpty) {
      answerSheetName = 'No answer sheets loaded';
    } else {
      final answerSheetObj = answerSheetProvider.answerSheets.where((a) => a.id == quiz.answersheet);
      debugAnswerSheetIds = answerSheetProvider.answerSheets.map((a) => a.id).join(', ');
      answerSheetName = answerSheetObj.isNotEmpty ? answerSheetObj.first.name : 'Unknown';
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header lớn giống ZipGrade
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Quiz: ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                            Text(quiz.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('Class: ', style: TextStyle(fontSize: 20, color: Colors.grey[700])),
                            Text(classNames, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Row các block chính
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Block Quiz Details (thu nhỏ)
                  Flexible(
                    flex: 2,
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Row tiêu đề và icon edit
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('QUIZ DETAILS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                                                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.teal),
                                  tooltip: 'Edit Quiz',
                                  onPressed: () {
                                    context.go('/quizzes/${quiz.id}/edit');
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Table(
                              columnWidths: const {
                                0: IntrinsicColumnWidth(),
                                1: FlexColumnWidth(),
                              },
                              children: [
                                TableRow(children: [
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Text('Name:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Text(quiz.name),
                                  ),
                                ]),
                                TableRow(children: [
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Text('Answer Sheet:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(answerSheetName),
                                        if (answerSheetName == 'Unknown' && debugAnswerSheetIds.isNotEmpty)
                                          Text('Debug ids: ' + debugAnswerSheetIds, style: const TextStyle(fontSize: 10, color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ]),
                                TableRow(children: [
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Text('Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Text(quiz.date),
                                  ),
                                ]),
                                TableRow(children: [
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Text('Class:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Text(classNames),
                                  ),
                                ]),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Block Score Distribution
                  Flexible(
                    flex: 3,
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('SCORE DISTRIBUTION', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                                const SizedBox(width: 8),
                                Icon(Icons.bar_chart, color: Colors.teal, size: 18),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_grades.isEmpty)
                              Container(
                                height: 180,
                                alignment: Alignment.center,
                                child: const Text('No data available', style: TextStyle(color: Colors.grey)),
                              )
                            else
                              SizedBox(
                                height: 180,
                                child: Builder(
                                  builder: (context) {
                                    try {
                                      return _buildScoreDistributionChart();
                                    } catch (e) {
                                      print('[QuizDetail] Chart error: $e');
                                      return Center(
                                        child: Text('Chart error: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
                                      );
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Row các block phụ
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Block Answer Key
                  Flexible(
                    flex: 2,
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('ANSWER KEY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                                const SizedBox(width: 8),
                                Icon(Icons.key, color: Colors.teal, size: 18),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (answerKeyProvider.isLoading)
                              const CircularProgressIndicator(),
                            if (answerKeyProvider.error != null)
                              Text('Error: ${answerKeyProvider.error}', style: const TextStyle(color: Colors.red)),
                            if (!answerKeyProvider.isLoading && answerKeyProvider.error == null)
                              ...[
                                if (answerKeyProvider.answerKeys.isEmpty)
                                  const Text('No answer keys found.'),
                                if (answerKeyProvider.answerKeys.isNotEmpty)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Number of Versions: ${answerKeyProvider.answerKeys.first.numVersions}'),
                                      const SizedBox(height: 8),
                                      Text('Version Codes:'),
                                      Wrap(
                                        spacing: 8,
                                        children: List.generate(
                                          answerKeyProvider.answerKeys.first.versions.length,
                                          (i) {
                                            final v = answerKeyProvider.answerKeys.first.versions[i];
                                            return GestureDetector(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    final questions = v['questions'] as List;
                                                    return AlertDialog(
                                                      title: Text('Answers for Version: ${v['version_code']}'),
                                                      content: SizedBox(
                                                        width: 300,
                                                        child: ListView.builder(
                                                          shrinkWrap: true,
                                                          itemCount: questions.length,
                                                          itemBuilder: (context, j) {
                                                            final q = questions[j];
                                                            return ListTile(
                                                              dense: true,
                                                              title: Text('Q${q['order']}: ${q['answer']}'),
                                                              subtitle: Text('Question code: ${q['question_code']}'),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.of(context).pop(),
                                                          child: const Text('Close'),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                              child: Chip(
                                                label: Text(v['version_code']?.toString() ?? ''),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                context.go('/quizzes/${quiz.id}/edit-answer-keys');
                              },
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Edit Answer Keys'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Block Graded Papers
                  Flexible(
                    flex: 3,
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text('GRADED PAPERS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                                    const SizedBox(width: 8),
                                    Icon(Icons.assignment_turned_in, color: Colors.teal, size: 18),
                                  ],
                                ),
                                if (_selectedGradeIds.isNotEmpty)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      // TODO: Implement delete selected
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Delete selected feature coming soon')),
                                      );
                                    },
                                    icon: const Icon(Icons.delete, size: 16),
                                    label: Text('Delete (${_selectedGradeIds.length})'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[300],
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_isLoadingGrades)
                              const Center(child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(),
                              ))
                            else if (_errorGrades != null)
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Text('Error: $_errorGrades', style: const TextStyle(color: Colors.red)),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: _loadGrades,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            else if (_grades.isEmpty)
                              Container(
                                height: 80,
                                alignment: Alignment.center,
                                child: const Text('No graded papers yet', style: TextStyle(color: Colors.grey)),
                              )
                            else
                              SizedBox(
                                height: 400, // Fixed height instead of Expanded
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: SingleChildScrollView(
                                          child: DataTable(
                                            columns: const [
                                              DataColumn(label: SizedBox(width: 40, child: Text(''))), // Checkbox
                                              DataColumn(label: Text('ID')),
                                              DataColumn(label: Text('Name')),
                                              DataColumn(label: Text('Pts'), numeric: true),
                                              DataColumn(label: Text('%'), numeric: true),
                                              DataColumn(label: Text('Key')),
                                              DataColumn(label: Text('Time')),
                                            ],
                                            rows: _getPaginatedGrades().map((grade) {
                                              final isSelected = _selectedGradeIds.contains(grade.id);
                                              return DataRow(
                                                selected: isSelected,
                                                cells: [
                                                  DataCell(
                                                    Checkbox(
                                                      value: isSelected,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          if (value == true) {
                                                            _selectedGradeIds.add(grade.id);
                                                          } else {
                                                            _selectedGradeIds.remove(grade.id);
                                                          }
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  DataCell(Text(grade.studentId)),
                                                  DataCell(Text(_getStudentName(grade.studentId))),
                                                  DataCell(Text(grade.score?.toStringAsFixed(0) ?? '0')),
                                                  DataCell(Text('${(grade.percentage ?? 0).toStringAsFixed(1)}%')),
                                                  DataCell(Text(grade.versionCode ?? 'N/A')),
                                                  DataCell(Text(_formatDateTime(grade.scannedAt))),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Pagination controls
                                    if (_getTotalPages() > 1)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.chevron_left),
                                              onPressed: _currentPage > 0
                                                  ? () {
                                                      setState(() {
                                                        _currentPage--;
                                                      });
                                                    }
                                                  : null,
                                            ),
                                            Text(
                                              'Page ${_currentPage + 1} of ${_getTotalPages()} (${_grades.length} total)',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.chevron_right),
                                              onPressed: _currentPage < _getTotalPages() - 1
                                                  ? () {
                                                      setState(() {
                                                        _currentPage++;
                                                      });
                                                    }
                                                  : null,
                                            ),
                                          ],
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
                ],
              ),
              const SizedBox(height: 20),
              // Block Quiz Statistics (giữ nguyên)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('QUIZ STATISTICS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                          const SizedBox(width: 8),
                          Icon(Icons.analytics, color: Colors.teal, size: 18),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text('PDF'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[200]),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.table_chart, size: 18),
                            label: const Text('CSV'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[200]),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.grid_on, size: 18),
                            label: const Text('Excel'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[200]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isLoadingAnalysis)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ))
                      else if (_errorAnalysis != null)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text('Error: $_errorAnalysis', style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _loadItemAnalysis,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        Table(
                          columnWidths: const {
                            0: IntrinsicColumnWidth(),
                            1: FlexColumnWidth(),
                          },
                          children: [
                            TableRow(children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text('Number of Papers:', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(_itemAnalysis?.totalPapers.toString() ?? '0'),
                              ),
                            ]),
                            TableRow(children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text('Number of Questions:', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(_itemAnalysis?.numQuestions.toString() ?? '0'),
                              ),
                            ]),
                            TableRow(children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text('Possible Points:', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(_itemAnalysis?.numQuestions.toString() ?? '0'),
                              ),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Table(
                          columnWidths: const {
                            0: IntrinsicColumnWidth(),
                            1: FlexColumnWidth(),
                            2: IntrinsicColumnWidth(),
                            3: FlexColumnWidth(),
                          },
                          children: [
                            TableRow(children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text('Minimum', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(_itemAnalysis?.statistics.minScore.toStringAsFixed(1) ?? '0'),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text('Maximum', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(_itemAnalysis?.statistics.maxScore.toStringAsFixed(1) ?? '0'),
                              ),
                            ]),
                            TableRow(children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text('Average', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(_itemAnalysis?.statistics.averageScore.toStringAsFixed(1) ?? '0'),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text('Median', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(_itemAnalysis?.statistics.medianScore.toStringAsFixed(1) ?? '0'),
                              ),
                            ]),
                            TableRow(children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text('Std. Dev.', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(_itemAnalysis?.statistics.stdDeviation.toStringAsFixed(2) ?? '0.00'),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text('', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text(''),
                              ),
                            ]),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Block Item Analysis
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'ITEM ANALYSIS',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                          if (_itemAnalysis != null && _grades.isNotEmpty)
                            Text(
                              ' - Primary Key ${_grades.first.versionCode ?? 'N/A'} - ${_itemAnalysis!.totalPapers} papers',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingAnalysis)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ))
                      else if (_errorAnalysis != null)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text('Error: $_errorAnalysis', style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _loadItemAnalysis,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else if (_itemAnalysis == null || _itemAnalysis!.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No data available in table', style: TextStyle(color: Colors.grey)),
                        )
                      else
                        SizedBox(
                          height: 400, // Fixed height to prevent overflow
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                              columns: const [
                                DataColumn(label: Text('#')),
                                DataColumn(label: Text('Pri. Ans.')),
                                DataColumn(label: Text('# Correct'), numeric: true),
                                DataColumn(label: Text('% Correct'), numeric: true),
                                DataColumn(label: Text('Discrim. Factor'), numeric: true),
                                DataColumn(label: Text('Responses')),
                              ],
                              rows: _itemAnalysis!.items.map((item) {
                                // Calculate response distribution (simplified - show correct/incorrect/blank)
                                final total = item.correctCount + item.incorrectCount + item.blankCount;
                                final responses = total > 0
                                    ? 'Correct: ${item.correctPercent.toStringAsFixed(1)}%, Incorrect: ${item.incorrectPercent.toStringAsFixed(1)}%, Blank: ${item.blankPercent.toStringAsFixed(1)}%'
                                    : 'N/A';
                                
                                return DataRow(
                                  cells: [
                                    DataCell(Text(item.questionNumber.toString())),
                                    DataCell(Text(item.correctAnswer)),
                                    DataCell(Text(item.correctCount.toString())),
                                    DataCell(Text('${item.correctPercent.toStringAsFixed(1)}%')),
                                    DataCell(Text('N/A')), // Discrimination factor not calculated yet
                                    DataCell(
                                      Tooltip(
                                        message: responses,
                                        child: Text(
                                          responses.length > 50 ? '${responses.substring(0, 50)}...' : responses,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}