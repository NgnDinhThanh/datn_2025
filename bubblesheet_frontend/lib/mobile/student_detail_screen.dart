import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/student_model.dart';
import '../providers/class_provider.dart';
import 'student_form_dialog.dart';

class StudentDetailScreen extends StatelessWidget {
  final Student student;
  const StudentDetailScreen({Key? key, required this.student}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final allClasses = context.watch<ClassProvider>().classes;
    final studentClasses = allClasses.where((c) => student.classCodes.contains(c.id)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final updated = await showDialog(
                context: context,
                builder: (_) => StudentFormDialog(student: student),
              );
              if (updated == true && context.mounted) {
                Navigator.of(context).pop(); // Đóng màn hình chi tiết để reload lại danh sách
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('First Name ', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(student.firstName),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Last Name ', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(student.lastName),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('ZipGrade ID ', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(student.studentId),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Classes ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: studentClasses.isEmpty
                        ? [const Text('--')]
                        : studentClasses.map((c) => Chip(label: Text(c.class_name))).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 