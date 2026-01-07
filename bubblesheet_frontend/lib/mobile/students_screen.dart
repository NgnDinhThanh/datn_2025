import 'package:bubblesheet_frontend/mobile/student_detail_screen.dart';
import 'package:bubblesheet_frontend/mobile/student_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/student_model.dart';
import '../providers/student_provider.dart';
import '../services/api_service.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({Key? key}) : super(key: key);

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  String _search = '';
  String _sortKey = 'Last Name';
  final List<String> _sortOptions = ['First Name', 'Last Name', 'ID'];

  @override
  void initState() {
    super.initState();
    ApiService.setContext(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StudentProvider>(context, listen: false).fetchStudents(context);
    });
  }

  List<Student> _filterAndSort(List<Student> students) {
    List<Student> filtered = students;
    // Search
    if (_search.isNotEmpty) {
      filtered = filtered.where((s) =>
        s.firstName.toLowerCase().contains(_search.toLowerCase()) ||
        s.lastName.toLowerCase().contains(_search.toLowerCase()) ||
        s.studentId.toLowerCase().contains(_search.toLowerCase())
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0, // Hide default AppBar
      ),
      body: Column(
        children: [
          // Custom Header
          Container(
            padding: const EdgeInsets.only(top: 16, bottom: 16, left: 16, right: 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'STUDENTS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage students',
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2E7D32)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortKey,
                              items: _sortOptions.map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  'Sort\n$e',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              )).toList(),
                              onChanged: (v) => setState(() => _sortKey = v ?? 'Last Name'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Search Field
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF2E7D32)),
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
            child: Consumer<StudentProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.error != null) {
                  return Center(child: Text('Error: ${provider.error}', style: const TextStyle(color: Colors.red)));
                }
                final students = _filterAndSort(provider.students);
                if (students.isEmpty) {
                  return const Center(child: Text('No students found.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: students.length,
                  itemBuilder: (context, i) {
                    final s = students[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          '${s.firstName} ${s.lastName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${s.studentId}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Classes: ${s.classCodes.join(', ')}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF2E7D32),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentDetailScreen(student: s),
                            ),
                          );
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
          showDialog(
            context: context,
            builder: (_) => const StudentFormDialog(),
          );
        },
        backgroundColor: const Color(0xFF2E7D32),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'NEW STUDENT',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
} 