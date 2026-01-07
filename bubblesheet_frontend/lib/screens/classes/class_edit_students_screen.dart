import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/student_model.dart';
import '../../models/class_model.dart';
import '../../services/class_service.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';

class ClassEditStudentsScreen extends StatefulWidget {
  final String classCode;
  const ClassEditStudentsScreen({Key? key, required this.classCode}) : super(key: key);

  @override
  State<ClassEditStudentsScreen> createState() => _ClassEditStudentsScreenState();
}

class _ClassEditStudentsScreenState extends State<ClassEditStudentsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  List<Student> _allStudents = [];
  List<Student> _classRoster = [];
  List<Student> _studentList = [];
  ClassModel? _classModel;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      // Lấy danh sách sinh viên của giáo viên
      final students = await ApiService.getStudents();
      // Lấy chi tiết lớp
      final classes = await ClassService.getClasses(token);
      final classModel = classes.firstWhere((c) => c.class_code == widget.classCode);
      _classModel = classModel;
      // Phân loại
      final classStudentIds = classModel.student_ids.map((id) => id.toString()).toSet();
      _classRoster = students.where((s) => classStudentIds.contains(s.id)).toList();
      _studentList = students.where((s) => !classStudentIds.contains(s.id)).toList();
      _allStudents = students;
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _moveToRoster(Student s) {
    setState(() {
      _studentList.remove(s);
      _classRoster.add(s);
    });
  }

  void _moveToList(Student s) {
    setState(() {
      _classRoster.remove(s);
      _studentList.add(s);
    });
  }

  Future<void> _save() async {
    setState(() { _isSaving = true; _error = null; });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      await ClassService.updateClass(widget.classCode, {
        'student_ids': _classRoster.map((s) => s.studentId).toList(),
      }, token);
      await Provider.of<ClassProvider>(context, listen: false).fetchClasses(context);
      if (mounted) context.go('/classes');
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Center(
        child: Container(
          width: 900,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: 'Edit Class Roster: ',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                            children: [
                              TextSpan(
                                text: _classModel?.class_code ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Student List
                            Expanded(
                              child: Column(
                                children: [
                                  const Text('Click to add students to the class roster on left:', style: TextStyle(fontSize: 16)),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 320,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListView.builder(
                                      itemCount: _studentList.length,
                                      itemBuilder: (context, idx) {
                                        final s = _studentList[idx];
                                        return InkWell(
                                          onTap: () => _moveToRoster(s),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(color: Colors.grey.shade200),
                                              ),
                                            ),
                                            child: Text('${s.firstName} ${s.lastName}', style: const TextStyle(fontSize: 16)),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 32),
                            // Class Roster
                            Expanded(
                              child: Column(
                                children: [
                                  const Text('Class Roster', style: TextStyle(fontSize: 16)),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 320,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListView.builder(
                                      itemCount: _classRoster.length,
                                      itemBuilder: (context, idx) {
                                        final s = _classRoster[idx];
                                        return InkWell(
                                          onTap: () => _moveToList(s),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(color: Colors.grey.shade200),
                                              ),
                                            ),
                                            child: Text('${s.firstName} ${s.lastName}', style: const TextStyle(fontSize: 16)),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: 220,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            onPressed: _isSaving ? null : _save,
                            child: _isSaving
                                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Save Student Roster'),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
} 