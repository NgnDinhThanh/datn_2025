import 'package:bubblesheet_frontend/providers/auth_provider.dart';
import 'package:bubblesheet_frontend/providers/student_provider.dart';
import 'package:bubblesheet_frontend/providers/class_provider.dart';
import 'package:bubblesheet_frontend/models/class_model.dart';
import 'package:bubblesheet_frontend/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final Set<String> _selectedStudentIds = {};
  String? _error;
  int _pageSize = 10;
  int _currentPage = 1;
  String _searchText = '';
  String _sortField = 'student_id';
  bool _sortAsc = true;

  final List<int> _pageSizeOptions = [10, 25, 50, 100];
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<StudentProvider>().fetchStudents(context);
      context.read<ClassProvider>().fetchClasses(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassProvider>().fetchClasses(context);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _toggleStudentSelection(String studentId) {
    setState(() {
      if (_selectedStudentIds.contains(studentId)) {
        _selectedStudentIds.remove(studentId);
      } else {
        _selectedStudentIds.add(studentId);
      }
    });
  }

  Future<void> _deleteSelectedStudents() async {
    if (_selectedStudentIds.isEmpty) return;
    try {
      final provider = Provider.of<StudentProvider>(context, listen: false);
      for (final studentId in _selectedStudentIds) {
        await provider.deleteStudent(context, studentId);
      }
      await Provider.of<ClassProvider>(context, listen: false).fetchClasses(context);
      setState(() { _selectedStudentIds.clear(); });
    } catch (e) {
      setState(() { _error = 'Failed to delete selected students'; });
    }
  }

  Future<void> exportStudents(String type) async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export functionality is only available on web')),
      );
      return;
    }

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final url = type == 'csv'
          ? '${ApiService.baseUrl}/students/export/csv/'
          : '${ApiService.baseUrl}/students/export/excel/';
      
      final response = await http.get(Uri.parse(url), headers: {
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        // Create blob from response bytes
        final bytes = response.bodyBytes;
        final blob = html.Blob([bytes]);
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        
        // Create anchor element and trigger download
        final anchor = html.AnchorElement(href: blobUrl)
          ..setAttribute('download', type == 'csv' ? 'students.csv' : 'students.xlsx')
          ..click();
        
        // Clean up
        html.Url.revokeObjectUrl(blobUrl);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export ${type.toUpperCase()} completed successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export error: $e')),
      );
    }
  }

  void _onSort(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortField = field;
        _sortAsc = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalController,
        child: Consumer<StudentProvider>(
          builder: (context, studentProvider, child) {
            if (studentProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
            if (studentProvider.error != null) {
              return Center(child: Text('Error: ${studentProvider.error}'));
            }
            final students = studentProvider.students;
            if (students.isEmpty) {
              return const Center(child: Text('No students found.'));
            }

            final allClasses = context.read<ClassProvider>().classes;

          // Lọc và phân trang
            final filtered = students.where((s) {
              final query = _searchText.toLowerCase();
              final inId = s.studentId.toLowerCase().contains(query);
              final inFirst = s.firstName.toLowerCase().contains(query);
              final inLast = s.lastName.toLowerCase().contains(query);
              final classNames = s.classCodes.map((cid) {
                final cList = allClasses.where((cl) => cl.id == cid).toList();
                return cList.isNotEmpty ? cList.first.class_name : '';
              }).toList();
              final inClass = classNames.any((c) => c.toLowerCase().contains(query));
              return inId || inFirst || inLast || inClass;
            }).toList();
            // Sort
            filtered.sort((a, b) {
              int cmp;
              switch (_sortField) {
                case 'student_id':
                  cmp = a.studentId.compareTo(b.studentId);
                  break;
                case 'first_name':
                  cmp = a.firstName.compareTo(b.firstName);
                  break;
                case 'last_name':
                  cmp = a.lastName.compareTo(b.lastName);
                  break;
                case 'classes':
                  final aClasses = a.classCodes.map((cid) {
                    final cList = allClasses.where((cl) => cl.id == cid).toList();
                    return cList.isNotEmpty ? cList.first.class_name : '';
                  }).join(',');
                  final bClasses = b.classCodes.map((cid) {
                    final cList = allClasses.where((cl) => cl.id == cid).toList();
                    return cList.isNotEmpty ? cList.first.class_name : '';
                  }).join(',');
                  cmp = aClasses.compareTo(bClasses);
                  break;
                default:
                  cmp = 0;
              }
              return _sortAsc ? cmp : -cmp;
            });
          final total = filtered.length;
          final totalPages = (total / _pageSize).ceil();
          final start = total == 0 ? 0 : (_currentPage - 1) * _pageSize + 1;
          final end = total == 0
              ? 0
              : ((_currentPage * _pageSize) > total ? total : (_currentPage * _pageSize));
          final pageData = filtered.skip((_currentPage - 1) * _pageSize).take(_pageSize).toList();

          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  const Text(
                      'All Students',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                            context.go('/students/new');
                          },
                          child: const Text('Add New Student'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            context.go('/students/importStudent');
                          },
                          child: const Text('Import Student From CSV'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => exportStudents('csv'),
                          child: const Text('Export as CSV'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => exportStudents('excel'),
                          child: const Text('Export as Excel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                          onPressed: _selectedStudentIds.isEmpty
                            ? null
                            : () {
                            _deleteSelectedStudents();
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
                                  setState(() {
                                    _searchText = value;
                                    _currentPage = 1;
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
                  // Bảng
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
                            2: FixedColumnWidth(80),
                            3: FixedColumnWidth(80),
                            4: FixedColumnWidth(120),
                            5: FixedColumnWidth(80),
                            6: FixedColumnWidth(80),
                            7: FixedColumnWidth(80),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: Colors.grey.shade200),
                              children: [
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Center(
                                    child: Checkbox(
                                      value: pageData.isNotEmpty && pageData.every((c) => _selectedStudentIds.contains(c.studentId)),
                                    onChanged: (selected) {
                                      setState(() {
                                        if (selected == true) {
                                            _selectedStudentIds.addAll(pageData.map((c) => c.studentId));
                                        } else {
                                            _selectedStudentIds.removeWhere((id) => pageData.any((c) => c.studentId == id));
                                        }
                                      });
                                    },
                                    ),
                                  ),
                                ),
                                TableCell(
                                  child: InkWell(
                                    onTap: () => _onSort('student_id'),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text('ID'),
                                        Icon(
                                          _sortField == 'student_id'
                                              ? (_sortAsc ? Icons.arrow_upward : Icons.arrow_downward)
                                              : Icons.import_export,
                                          size: 16,
                                          color: _sortField == 'student_id' ? Colors.blue : Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                TableCell(
                                  child: InkWell(
                                    onTap: () => _onSort('first_name'),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text('First Name'),
                                        Icon(
                                          _sortField == 'first_name'
                                              ? (_sortAsc ? Icons.arrow_upward : Icons.arrow_downward)
                                              : Icons.import_export,
                                          size: 16,
                                          color: _sortField == 'first_name' ? Colors.blue : Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                TableCell(
                                  child: InkWell(
                                    onTap: () => _onSort('last_name'),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text('Last Name'),
                                        Icon(
                                          _sortField == 'last_name'
                                              ? (_sortAsc ? Icons.arrow_upward : Icons.arrow_downward)
                                              : Icons.import_export,
                                          size: 16,
                                          color: _sortField == 'last_name' ? Colors.blue : Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                TableCell(
                                  child: InkWell(
                                    onTap: () => _onSort('classes'),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text('Classes'),
                                        Icon(
                                          _sortField == 'classes'
                                              ? (_sortAsc ? Icons.arrow_upward : Icons.arrow_downward)
                                              : Icons.import_export,
                                          size: 16,
                                          color: _sortField == 'classes' ? Colors.blue : Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Center(child: Text("Edit")),
                                ),
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Center(child: Text("Papers & Sessions")),
                                ),
                              ],
                            ),
                            ...pageData.map((studentItem) => TableRow(
                              children: [
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Center(
                                    child: Checkbox(
                                      value: _selectedStudentIds.contains(studentItem.studentId),
                                      onChanged: (bool? value) {
                                        _toggleStudentSelection(studentItem.studentId);
                                      },
                                    ),
                                  ),
                                ),
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Center(child: Text('${studentItem.studentId}')),
                                ),
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Center(child: Text('${studentItem.firstName}')),
                                ),
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Center(child: Text('${studentItem.lastName}')),
                                ),
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Center(
                                    child: Text(
                                      studentItem.classCodes
                                        .map((id) => allClasses.firstWhere(
                                              (c) => c.id == id,
                                              orElse: () => ClassModel(
                                                id: id,
                                                class_code: '',
                                                class_name: id,
                                                student_count: 0,
                                                teacher_id: '',
                                                exam_ids: [],
                                                student_ids: [],
                                              ),
                                            ).class_name)
                                        .join(', '),
                                    ),
                                  ),
                                ),
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Center(
                                        child: IconButton(
                                      icon: const Icon(Icons.edit),
                                          onPressed: () {
                                        context.go('/students/${studentItem.studentId}');
                                          },
                                        ),
                                      ),
                                    ),
                                TableCell(
                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                  child: Center(
                                        child: IconButton(
                                      icon: const Icon(Icons.file_copy_outlined),
                                          onPressed: () {
                                            // TODO: Navigate to grade book report
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                            ))
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