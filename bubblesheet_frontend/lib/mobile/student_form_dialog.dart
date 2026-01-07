import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../providers/student_provider.dart';
import '../providers/class_provider.dart';

class StudentFormDialog extends StatefulWidget {
  final Student? student;
  const StudentFormDialog({Key? key, this.student}) : super(key: key);

  @override
  State<StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<StudentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _externalRefController = TextEditingController();
  Set<String> _selectedClassIds = {};
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.student != null) {
      _firstNameController.text = widget.student!.firstName;
      _lastNameController.text = widget.student!.lastName;
      _studentIdController.text = widget.student!.studentId;
      // _externalRefController.text = ... // Nếu có trường này trong model
      _selectedClassIds = Set<String>.from(widget.student!.classCodes);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _studentIdController.dispose();
    _externalRefController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = {
        'student_id': _studentIdController.text.trim(),
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'class_codes': _selectedClassIds.toList(),
        // 'external_ref': _externalRefController.text.trim(), // Nếu có
      };
      final provider = Provider.of<StudentProvider>(context, listen: false);
      if (widget.student == null) {
        await provider.addStudent(context, data);
      } else {
        await provider.updateStudent(context, widget.student!.studentId, data);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _delete() async {
    if (widget.student == null) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final provider = Provider.of<StudentProvider>(context, listen: false);
      await provider.deleteStudent(context, widget.student!.studentId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allClasses = context.watch<ClassProvider>().classes;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.student == null ? 'New Student' : 'Edit Student',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _studentIdController,
                  decoration: const InputDecoration(labelText: 'Student ID', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  enabled: widget.student == null, // Không cho sửa ID khi edit
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                if (allClasses.isNotEmpty) ...[
                  Text('Classes (${allClasses.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.student != null)
                      ElevatedButton(
                        onPressed: _isLoading ? null : _delete,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('DELETE'),
                      ),
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                      child: const Text('CANCEL'),
                    ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('SAVE'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 