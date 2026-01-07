import 'dart:async';

import 'package:bubblesheet_frontend/models/exam_model.dart';
import 'package:bubblesheet_frontend/providers/exam_provider.dart';
import 'package:bubblesheet_frontend/providers/class_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class QuizzListScreen extends StatefulWidget {
  const QuizzListScreen({Key? key}) : super(key: key);

  @override
  _QuizzListScreenState createState() => _QuizzListScreenState();
}

class _QuizzListScreenState extends State<QuizzListScreen> {
  final Set<String> _selectedExamIds = {};
  int _pageSize = 10;
  int _currentPage = 1;
  String _searchText = '';
  String _sortField = '';
  bool _sortAsc = true;
  Timer? _debounce;
  List<ExamModel> _filteredExams = [];

  final List<int> _pageSizeOptions = [10, 25, 50, 100];
  final TextEditingController _searchController = TextEditingController();

  // ScrollController cho cuộn ngang bảng
  final ScrollController _horizontalController = ScrollController();
  // ScrollController cho cuộn dọc toàn trang
  final ScrollController _verticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ExamProvider>().fetchExams(context));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _filterExams(List<ExamModel> exams) {
    final search = _searchText.toLowerCase();
    final filtered = exams.where((c) {
      final combined = [
        c.id,
        c.name,
        c.class_codes.join(','),
        c.answersheet,
        c.date,
        c.teacher_id,
      ].join(' ').toLowerCase();
      return combined.contains(search);
    }).toList();
    filtered.sort((a, b) {
      int cmp;
      if (_sortField == 'name') {
        cmp = a.name.compareTo(b.name);
      } else if (_sortField == 'class_codes') {
        cmp = a.class_codes.join(',').compareTo(b.class_codes.join(','));
      } else  if (_sortField == 'date') {
        cmp = a.date.compareTo(b.date);
      } else {
        cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
      });
    setState(() {
      _filteredExams = filtered;
      _currentPage = 1;
    });
  }
  @override
  Widget build(BuildContext context) {
    final classProvider = Provider.of<ClassProvider>(context, listen: false);
    final Map<String, String> classCodeToName = {
      for (var c in classProvider.classes) c.class_code: c.class_name
    };
    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalController,
        child: Consumer<ExamProvider>(
          builder: (context, examProvider, child) {
            if (examProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (examProvider.error != null) {
              return Center(child: Text('Error: ${examProvider.error}'));
            }
            final exams = examProvider.exams;
            if (exams.isEmpty) {
              return const Center(child: Text('No exams found.'));
            }

            if (_filteredExams.isEmpty && _searchText.isEmpty) {
              _filteredExams = List<ExamModel>.from(exams);
            }

            // Lọc, sắp xếp và phân trang
            final int total = _filteredExams.length;
            final int totalPages = (total / _pageSize).ceil();
            final int start = total == 0 ? 0 : (_currentPage - 1) * _pageSize + 1;
            final int end = total == 0
                ? 0
                : ((_currentPage * _pageSize) > total ? total : (_currentPage * _pageSize));
            final List<ExamModel> pageData = _filteredExams.skip((_currentPage - 1) * _pageSize).take(_pageSize).toList();

            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // BỎ header màu xanh (AppBar custom)
                    const SizedBox(height: 32),
                    const Text(
                      'All Quizzes',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            context.go('/quizzes/new');
                          },
                          child: const Text('New Quiz'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _selectedExamIds.isEmpty
                              ? null
                              : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Delete'),
                                content: const Text('Deleting quizzes will remove their associated papers and cannot be undone.  Continue?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await context.read<ExamProvider>().deleteExams(context, _selectedExamIds.toList());
                              setState(() {
                                _selectedExamIds.clear();
                                _filterExams(context.read<ExamProvider>().exams);
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Delete Selected'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Show entries & Search
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        children: [
                          // Show entries
                          Row(
                            children: [
                              const Text('Show '),
                              DropdownButton<int>(
                                value: _pageSize,
                                items: _pageSizeOptions
                                    .map((size) => DropdownMenuItem(
                                  value: size,
                                  child: Text('$size'),
                                ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _pageSize = value;
                                      _currentPage = 1;
                                    });
                                  }
                                },
                              ),
                              const Text(' entries'),
                            ],
                          ),
                          const Spacer(),
                          // Search
                          Row(
                            children: [
                              const Text('Search: '),
                              SizedBox(
                                width: 180,
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (value) {
                                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                                    _searchText = value;
                                    _debounce = Timer(const Duration(milliseconds: 300), () {
                                      _filterExams(examProvider.exams);
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Bảng căn giữa
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 24),
                      padding: const EdgeInsets.all(0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Table(
                        border: TableBorder.all(color: Colors.grey, width: 0.7),
                        columnWidths: const {
                          0: FixedColumnWidth(48),
                          1: FixedColumnWidth(80),
                          2: FixedColumnWidth(120),
                          3: FixedColumnWidth(56),
                        },
                        children: [
                          // Header row
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.shade200),
                            children: [
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Center(
                                  child: Checkbox(
                                    value: pageData.isNotEmpty && pageData.every((c) => _selectedExamIds.contains(c.id)),
                                    onChanged: (selected) {
                                      setState(() {
                                        if (selected == true) {
                                          _selectedExamIds.addAll(pageData.map((c) => c.id));
                                        } else {
                                          _selectedExamIds.removeWhere((id) => pageData.any((c) => c.id == id));
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                              // ID (class_code) header with sort
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (_sortField == 'class_codes') {
                                        _sortAsc = !_sortAsc;
                                      } else {
                                        _sortField = 'class_codes';
                                        _sortAsc = true;
                                      }
                                    });
                                    _filterExams(examProvider.exams);
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('Class'),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_upward,
                                        size: 16,
                                        color: _sortField == 'class_codes'
                                            ? (_sortAsc ? Colors.blue : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                      Icon(
                                        Icons.arrow_downward,
                                        size: 16,
                                        color: _sortField == 'class_codes'
                                            ? (!_sortAsc ? Colors.blue : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Class Name header with sort
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (_sortField == 'name') {
                                        _sortAsc = !_sortAsc;
                                      } else {
                                        _sortField = 'name';
                                        _sortAsc = true;
                                      }
                                    });
                                    _filterExams(examProvider.exams);
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('Quiz Name'),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_upward,
                                        size: 16,
                                        color: _sortField == 'name'
                                            ? (_sortAsc ? Colors.blue : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                      Icon(
                                        Icons.arrow_downward,
                                        size: 16,
                                        color: _sortField == 'name'
                                            ? (!_sortAsc ? Colors.blue : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (_sortField == 'date') {
                                        _sortAsc = !_sortAsc;
                                      } else {
                                        _sortField = 'date';
                                        _sortAsc = true;
                                      }
                                    });
                                    _filterExams(examProvider.exams);
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('Date'),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_upward,
                                        size: 16,
                                        color: _sortField == 'date'
                                            ? (_sortAsc ? Colors.blue : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                      Icon(
                                        Icons.arrow_downward,
                                        size: 16,
                                        color: _sortField == 'date'
                                            ? (!_sortAsc ? Colors.blue : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Data rows
                          ...pageData.map((examItem) => TableRow(
                            children: [
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Center(
                                  child: Checkbox(
                                    value: _selectedExamIds.contains(examItem.id),
                                    onChanged: (selected) {
                                      setState(() {
                                        if (selected == true) {
                                          _selectedExamIds.add(examItem.id);
                                        } else {
                                          _selectedExamIds.remove(examItem.id);
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Center(
                                  child: Text(
                                    examItem.class_codes
                                      .map((code) => classCodeToName[code] ?? code)
                                      .join(', '),
                                  ),
                                ),
                              ),
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Center(
                                  child: TextButton(
                                    child: Text(examItem.name),
                                    onPressed: () {
                                      context.go('/quizzes/${examItem.id}');
                                    },
                                  ),
                                ),
                              ),
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Center(child: Text('${examItem.date}')),
                              )
                            ],
                          )),
                        ],
                      ),
                    ),
                    // Showing entries & Pagination
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                      child: Row(
                        children: [
                          Text('Showing $start to $end of $total entries'),
                          const Spacer(),
                          Row(
                            children: [
                              TextButton(
                                onPressed: _currentPage > 1
                                    ? () => setState(() => _currentPage = 1)
                                    : null,
                                child: const Text('First'),
                              ),
                              TextButton(
                                onPressed: _currentPage > 1
                                    ? () => setState(() => _currentPage--)
                                    : null,
                                child: const Text('Previous'),
                              ),
                              Text('$_currentPage'),
                              TextButton(
                                onPressed: _currentPage < totalPages
                                    ? () => setState(() => _currentPage++)
                                    : null,
                                child: const Text('Next'),
                              ),
                              TextButton(
                                onPressed: _currentPage < totalPages
                                    ? () => setState(() => _currentPage = totalPages)
                                    : null,
                                child: const Text('Last'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
