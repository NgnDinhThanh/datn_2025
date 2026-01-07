import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/student_provider.dart';
import '../../providers/class_provider.dart';

class StudentFormScreen extends StatefulWidget {
  final String? studentId;
  const StudentFormScreen({Key? key, this.studentId}) : super(key: key);

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _externalRefController = TextEditingController();
  Set<String> _selectedClassIds = {};
  bool _isLoading = false;
  String? _error;
  String? _success;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    if (widget.studentId != null) {
      _isEdit = true;
      _fetchStudent();
    }
  }

  Future<void> _fetchStudent() async {
    setState(() { _isLoading = true; });
    try {
      final provider = Provider.of<StudentProvider>(context, listen: false);
      final student = await provider.fetchStudentById(context, widget.studentId!);
      _studentIdController.text = student.studentId;
      _firstNameController.text = student.firstName;
      _lastNameController.text = student.lastName;
      _selectedClassIds = Set<String>.from(student.classCodes);
    } catch (e) {
      setState(() { _error = 'Failed to load student info'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; _success = null; });
    try {
      final data = {
        'student_id': _studentIdController.text.trim(),
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'class_codes': _selectedClassIds.toList(),
      };
      final provider = Provider.of<StudentProvider>(context, listen: false);
      if (_isEdit) {
        await provider.updateStudent(context, widget.studentId!, data);
        setState(() { _success = 'Student updated successfully!'; });
      } else {
        await provider.addStudent(context, data);
        setState(() { _success = 'Student created successfully!'; });
      }
      await Provider.of<ClassProvider>(context, listen: false).fetchClasses(context);
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) context.go('/students');
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _deleteStudent() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final provider = Provider.of<StudentProvider>(context, listen: false);
      await provider.deleteStudent(context, widget.studentId!);
      await Provider.of<ClassProvider>(context, listen: false).fetchClasses(context);
      if (mounted) context.go('/students');
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _externalRefController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allClasses = context.watch<ClassProvider>().classes;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Center(
        child: Container(
          width: 420,
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
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isEdit ? 'Edit Student: ${_firstNameController.text} ${_lastNameController.text}' : 'Add New Student',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _studentIdController,
                    decoration: InputDecoration(
                      labelText: 'Student ID',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.badge),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    enabled: !_isEdit, // Không cho sửa student_id khi edit
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  if (allClasses.isNotEmpty) ...[
                    const Text('Classes:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...allClasses.map((c) => CheckboxListTile(
                          value: _selectedClassIds.contains(c.id),
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedClassIds.add(c.id);
                              } else {
                                _selectedClassIds.remove(c.id);
                              }
                            });
                          },
                          title: Text(c.class_name),
                        )),
                    const SizedBox(height: 8),
                  ],
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                        ],
                      ),
                    ),
                  if (_success != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_success!, style: const TextStyle(color: Colors.green))),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Student'),
                    ),
                  ),
                  if (_isEdit)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isLoading ? null : _deleteStudent,
                        child: const Text('Delete Student'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 