import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_model.dart';
import '../providers/class_provider.dart';

class ClassFormDialog extends StatefulWidget {
  final ClassModel? classModel;
  const ClassFormDialog({Key? key, this.classModel}) : super(key: key);

  @override
  State<ClassFormDialog> createState() => _ClassFormDialogState();
}

class _ClassFormDialogState extends State<ClassFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isDeleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.classModel != null) {
      _codeController.text = widget.classModel!.class_code;
      _nameController.text = widget.classModel!.class_name;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final provider = Provider.of<ClassProvider>(context, listen: false);
      if (widget.classModel == null) {
        // Tạo mới: truyền đúng class_code và class_name
        final data = {
          'class_code': _codeController.text.trim(),
          'class_name': _nameController.text.trim(),
        };
        await provider.addClass(context, data);
      } else {
        // Sửa: chỉ cho sửa tên lớp
        final data = {
          'class_name': _nameController.text.trim(),
          'class_code': _codeController.text.trim(), // luôn truyền mã lớp cũ
        };
        await provider.updateClass(context, widget.classModel!.class_code, data);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _delete() async {
    if (widget.classModel == null) return;
    setState(() { _isDeleting = true; _error = null; });
    try {
      final provider = Provider.of<ClassProvider>(context, listen: false);
      await provider.deleteClass(context, widget.classModel!.class_code);
      if (mounted) Navigator.of(context).pop('deleted');
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isDeleting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.classModel != null;
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
                  isEdit ? 'Edit Class' : 'New Class',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(labelText: 'Class Code', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  enabled: !isEdit, // Không cho sửa mã lớp khi edit
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Class Name', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isEdit)
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