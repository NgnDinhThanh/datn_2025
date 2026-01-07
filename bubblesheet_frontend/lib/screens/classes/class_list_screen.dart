import 'package:bubblesheet_frontend/models/class_model.dart';
import 'package:bubblesheet_frontend/providers/class_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'class_add_screen.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

class ClassListScreen extends StatefulWidget {
  const ClassListScreen({Key? key}) : super(key: key);

  @override
  _ClassListScreenState createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> {
  final Set<String> _selectedClassIds = {};
  int _pageSize = 10;
  int _currentPage = 1;
  String _searchText = '';
  String _sortField = 'class_code';
  bool _sortAsc = true;
  Timer? _debounce;
  List<ClassModel> _filteredClasses = [];

  final List<int> _pageSizeOptions = [10, 25, 50, 100];
  final TextEditingController _searchController = TextEditingController();

  // ScrollController cho cuộn ngang bảng
  final ScrollController _horizontalController = ScrollController();
  // ScrollController cho cuộn dọc toàn trang
  final ScrollController _verticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ClassProvider>().fetchClasses(context));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _filterClasses(List<ClassModel> classes) {
    final search = _searchText.toLowerCase();
    final filtered = classes.where((c) {
      final combined = [
        c.id,
        c.class_code,
        c.class_name,
        c.student_count.toString(),
        c.teacher_id,
        c.student_ids.join(','),
      ].join(' ').toLowerCase();
      return combined.contains(search);
    }).toList();
    filtered.sort((a, b) {
      int cmp;
      if (_sortField == 'class_code') {
        cmp = a.class_code.compareTo(b.class_code);
      } else if (_sortField == 'class_name') {
        cmp = a.class_name.compareTo(b.class_name);
      } else {
        cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });
    setState(() {
      _filteredClasses = filtered;
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalController,
        child: Consumer<ClassProvider>(
          builder: (context, classProvider, child) {
            if (classProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (classProvider.error != null) {
              return Center(child: Text('Error: ${classProvider.error}'));
            }
            final classes = classProvider.classes;
            if (classes.isEmpty) {
              return const Center(child: Text('No classes found.'));
            }

            if (_filteredClasses.isEmpty && _searchText.isEmpty) {
              _filteredClasses = List<ClassModel>.from(classes);
            }

            // Lọc, sắp xếp và phân trang
            final int total = _filteredClasses.length;
            final int totalPages = (total / _pageSize).ceil();
            final int start = total == 0 ? 0 : (_currentPage - 1) * _pageSize + 1;
            final int end = total == 0
                ? 0
                : ((_currentPage * _pageSize) > total ? total : (_currentPage * _pageSize));
            final List<ClassModel> pageData = _filteredClasses.skip((_currentPage - 1) * _pageSize).take(_pageSize).toList();

            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // BỎ header màu xanh (AppBar custom)
                    const SizedBox(height: 32),
                    const Text(
                      'All Classes',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            context.go('/classes/new');
                          },
                          child: const Text('Add New Class'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _selectedClassIds.isEmpty
                              ? null
                              : () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirm Delete'),
                                      content: const Text('Deleting classes will remove the class, but does not delete students or their papers. Continue?'),
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
                                    await context.read<ClassProvider>().deleteClasses(context, _selectedClassIds.toList());
                                    setState(() {
                                      _selectedClassIds.clear();
                                      _filterClasses(context.read<ClassProvider>().classes);
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
                                      _filterClasses(classProvider.classes);
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
                          4: FixedColumnWidth(100),
                          5: FixedColumnWidth(120),
                          6: FixedColumnWidth(120),
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
                                    value: pageData.isNotEmpty && pageData.every((c) => _selectedClassIds.contains(c.class_code)),
                                    onChanged: (selected) {
                                      setState(() {
                                        if (selected == true) {
                                          _selectedClassIds.addAll(pageData.map((c) => c.class_code));
                                        } else {
                                          _selectedClassIds.removeWhere((id) => pageData.any((c) => c.class_code == id));
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
                                      if (_sortField == 'class_code') {
                                        _sortAsc = !_sortAsc;
                                      } else {
                                        _sortField = 'class_code';
                                        _sortAsc = true;
                                      }
                                    });
                                    _filterClasses(classProvider.classes);
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('ID'),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_upward,
                                        size: 16,
                                        color: _sortField == 'class_code'
                                            ? (_sortAsc ? Colors.blue : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                      Icon(
                                        Icons.arrow_downward,
                                        size: 16,
                                        color: _sortField == 'class_code'
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
                                      if (_sortField == 'class_name') {
                                        _sortAsc = !_sortAsc;
                                      } else {
                                        _sortField = 'class_name';
                                        _sortAsc = true;
                                      }
                                    });
                                    _filterClasses(classProvider.classes);
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('Class Name'),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_upward,
                                        size: 16,
                                        color: _sortField == 'class_name'
                                            ? (_sortAsc ? Colors.blue : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                      Icon(
                                        Icons.arrow_downward,
                                        size: 16,
                                        color: _sortField == 'class_name'
                                            ? (!_sortAsc ? Colors.blue : Colors.grey)
                                            : Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Center(child: Icon(Icons.edit, color: Colors.transparent)),
                              ),
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Center(child: Text('Student Count')),
                              ),
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Center(child: Text('Edit Student Roster')),
                              ),
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Center(child: Text('Grade Book Report')),
                              ),
                            ],
                          ),
                          // Data rows
                          ...pageData.map((classItem) => TableRow(
                            children: [
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Center(
                                  child: Checkbox(
                                    value: _selectedClassIds.contains(classItem.class_code),
                                    onChanged: (selected) {
                                      setState(() {
                                        if (selected == true) {
                                          _selectedClassIds.add(classItem.class_code);
                                        } else {
                                          _selectedClassIds.remove(classItem.class_code);
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Center(child: Text('${classItem.class_code}')),
                              ),
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Center(child: Text('${classItem.name}')),
                              ),
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Center(
                                  child: IconButton(
                                    icon: const Icon(Icons.edit),
                                    tooltip: 'Edit',
                                    onPressed: () {
                                      context.go('/classes/${classItem.class_code}');
                                    },
                                  ),
                                ),
                              ),
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Center(child: Text('${classItem.student_count}')),
                              ),
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Center(
                                  child: IconButton(
                                    icon: const Icon(Icons.group),
                                    tooltip: 'Edit Student Roster',
                                    onPressed: () {
                                      context.go('/classes/${classItem.class_code}/students');
                                    },
                                  ),
                                ),
                              ),
                              TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Center(
                                  child: IconButton(
                                    icon: const Icon(Icons.assignment),
                                    tooltip: 'Grade Book Report',
                                    onPressed: () {
                                      // TODO: Navigate to grade book report
                                    },
                                  ),
                                ),
                              ),
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