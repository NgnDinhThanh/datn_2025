import 'package:bubblesheet_frontend/mobile/quiz_detail_screen.dart';
import 'package:bubblesheet_frontend/mobile/student_detail_screen.dart';
import 'package:bubblesheet_frontend/mobile/student_form_dialog.dart';
import 'package:bubblesheet_frontend/models/exam_model.dart';
import 'package:bubblesheet_frontend/providers/exam_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../providers/student_provider.dart';
import 'class_form_dialog.dart';
import '../services/class_service.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';

class ClassDetailScreen extends StatefulWidget {
  final ClassModel classModel;
  const ClassDetailScreen({Key? key, required this.classModel}) : super(key: key);

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ClassModel _classModel;
  bool _updated = false;
  String _studentSearch = '';
  String _quizSearch = '';
  String _sortKey = 'Last Name';
  final List<String> _sortOptions = ['First Name', 'Last Name', 'ID'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Trigger rebuild khi đổi tab
    });
    _classModel = widget.classModel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StudentProvider>(context, listen: false).fetchStudents(context);
      Provider.of<ExamProvider>(context, listen: false).fetchExams(context);
    });
  }
  Future<void> _refreshClassDetail() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final newDetail = await ClassService.getClassDetail(_classModel.class_code, token);
    setState(() {
      _classModel = newDetail;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  List<Student> _filterAndSort(List<Student> students) {
    // Lọc theo classId
    List<Student> filtered = students.where((s) => s.classCodes.contains(_classModel.id)).toList();
    // Search
    if (_studentSearch.isNotEmpty) {
      filtered = filtered.where((s) =>
        s.firstName.toLowerCase().contains(_studentSearch.toLowerCase()) ||
        s.lastName.toLowerCase().contains(_studentSearch.toLowerCase()) ||
        s.studentId.toLowerCase().contains(_studentSearch.toLowerCase())
      ).toList();
    }
    // Sort
    switch (_sortKey) {
      case 'First Name':
        filtered.sort((a, b) => a.firstName.compareTo(b.firstName));
        break;
      case 'Last Name':
        filtered.sort((a, b) => a.lastName.compareTo(b.lastName));
        break;
      case 'ID':
        filtered.sort((a, b) => a.studentId.compareTo(b.studentId));
        break;
    }
    return filtered;
  }

  List<ExamModel>_filterAndSortQuiz(List<ExamModel> exams) {
    // Lọc theo classId
    List<ExamModel> filtered = exams.where((s) => s.class_codes.contains(_classModel.class_code)).toList();
    // Search
    if (_quizSearch.isNotEmpty) {
      filtered = filtered.where((s) =>
      s.date.toLowerCase().contains(_quizSearch.toLowerCase()) ||
          s.name.toLowerCase().contains(_quizSearch.toLowerCase())
      ).toList();
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
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_updated);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Class: ${_classModel.class_name}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await showDialog(
                  context: context,
                  builder: (_) => ClassFormDialog(classModel: _classModel),
                );
                if (updated == 'deleted' && context.mounted) {
                  Navigator.of(context).pop(true);
                } else if (updated == true && context.mounted) {
                  await _refreshClassDetail();
                  _updated = true;
                }
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Students'),
              Tab(text: 'Quizzes'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Students Tab
            Consumer<StudentProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.error != null) {
                  return Center(child: Text('Error: ${provider.error}', style: const TextStyle(color: Colors.red)));
                }
                final students = _filterAndSort(provider.students);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          DropdownButton<String>(
                            value: _sortKey,
                            items: _sortOptions.map((e) => DropdownMenuItem(value: e, child: Text('Sort\n$e'))).toList(),
                            onChanged: (v) => setState(() => _sortKey = v ?? 'Last Name'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Search',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) => setState(() => _studentSearch = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (students.isEmpty)
                      const Expanded(child: Center(child: Text('No students found.')))
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: students.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final s = students[i];
                            return ListTile(
                              title: Text('${s.firstName} ${s.lastName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('ID: ${s.studentId}'),
                              onTap: () {
                                Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => StudentDetailScreen(student: s)));
                              },
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
            // Quizzes Tab
            Consumer<ExamProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.error != null) {
                  return Center(child: Text('Error: \\${provider.error}', style: const TextStyle(color: Colors.red)));
                }
                final exams = _filterAndSortQuiz(provider.exams);
                final classCodeToName = Provider.of<ClassProvider>(context).classCodeToName;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          DropdownButton<String>(
                            value: _sortKey,
                            items: _sortOptions.map((e) => DropdownMenuItem(value: e, child: Text('Sort\n$e'))).toList(),
                            onChanged: (v) => setState(() => _sortKey = v ?? 'Date'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Search',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) => setState(() => _quizSearch = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (exams.isEmpty)
                      const Expanded(child: Center(child: Text('No exams found.')))
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: exams.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final s = exams[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                        child: Text('${s.name}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                    Text('Papers: ${s.papers?.length ?? 0}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                  ],
                                ),
                                subtitle: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(s.class_codes
                                          .map((code) => classCodeToName[code] ?? code)
                                          .join(', '),),
                                    ),
                                    Text(s.date),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => QuizDetailScreen(quiz: s)));
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        floatingActionButton: _tabController.index == 0
            ? FloatingActionButton.extended(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => StudentFormDialog(),
                  );
                },
                icon: const Icon(Icons.person_add),
                label: const Text('New Student'),
              )
            : null,
      ),
    );
  }
} 