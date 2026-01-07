import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/class_provider.dart';
import '../../models/class_model.dart';
import '../../services/class_service.dart';
import '../../providers/auth_provider.dart';

class ClassEditScreen extends StatefulWidget {
  final String classCode;
  const ClassEditScreen({Key? key, required this.classCode}) : super(key: key);

  @override
  State<ClassEditScreen> createState() => _ClassEditScreenState();
}

class _ClassEditScreenState extends State<ClassEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _error;
  ClassModel? _classModel;

  @override
  void initState() {
    super.initState();
    _fetchClass();
  }

  Future<void> _fetchClass() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final data = await ClassService.getClasses(token);
      final found = data.firstWhere((c) => c.class_code == widget.classCode, orElse: () => throw Exception('Class not found'));
      _classModel = found;
      _nameController.text = found.class_name;
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSaving = true; _error = null; });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      await ClassService.updateClass(widget.classCode, {
        'class_name': _nameController.text.trim(),
      }, token);
      await Provider.of<ClassProvider>(context, listen: false).fetchClasses(context);
      if (mounted) context.go('/classes');
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isSaving = false; });
    }
  }

  Future<void> _delete() async {
    setState(() { _isDeleting = true; _error = null; });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      await ClassService.deleteClass(widget.classCode, token);
      await Provider.of<ClassProvider>(context, listen: false).fetchClasses(context);
      if (mounted) context.go('/classes');
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isDeleting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text.rich(
                            TextSpan(
                              text: 'Edit Class: ',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                              children: [
                                TextSpan(
                                  text: _classModel?.class_name ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Class Name',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 28),
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
                              onPressed: _isSaving ? null : _save,
                              child: _isSaving
                                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Save Class'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              onPressed: _isDeleting ? null : _delete,
                              child: _isDeleting
                                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Delete Class'),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
} 