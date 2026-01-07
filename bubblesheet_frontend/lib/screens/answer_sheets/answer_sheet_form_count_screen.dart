import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/answer_sheet_form_provider.dart';
import 'package:go_router/go_router.dart';

class AnswerSheetFormCountScreen extends StatefulWidget {
  const AnswerSheetFormCountScreen({Key? key}) : super(key: key);

  @override
  State<AnswerSheetFormCountScreen> createState() => _AnswerSheetFormCountScreenState();
}

class _AnswerSheetFormCountScreenState extends State<AnswerSheetFormCountScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final formProvider = Provider.of<AnswerSheetFormProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 3 of 5: Key Version and Student/Class/Exam ID'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sheet Name: ${formProvider.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                // Student ID
                const Text('Student ID Section', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text('Number of Digits:'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: formProvider.studentIdDigits,
                      items: List.generate(10, (i) => i + 1)
                          .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) formProvider.setStudentIdDigits(val);
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: formProvider.studentIdLabel,
                        decoration: const InputDecoration(
                          labelText: 'Label',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (value.length > 20) {
                            return 'Max 20 chars';
                          }
                          return null;
                        },
                        onChanged: (val) => formProvider.setStudentIdLabel(val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Class ID
                const Text('Class ID Section', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text('Number of Digits:'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: formProvider.classIdDigits,
                      items: List.generate(10, (i) => i + 1)
                          .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) formProvider.setClassIdDigits(val);
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: formProvider.classIdLabel,
                        decoration: const InputDecoration(
                          labelText: 'Label',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (value.length > 20) {
                            return 'Max 20 chars';
                          }
                          return null;
                        },
                        onChanged: (val) => formProvider.setClassIdLabel(val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Exam ID
                const Text('Exam ID Section', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text('Number of Digits:'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: formProvider.examIdDigits,
                      items: List.generate(10, (i) => i + 1)
                          .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) formProvider.setExamIdDigits(val);
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: formProvider.examIdLabel,
                        decoration: const InputDecoration(
                          labelText: 'Label',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (value.length > 20) {
                            return 'Max 20 chars';
                          }
                          return null;
                        },
                        onChanged: (val) => formProvider.setExamIdLabel(val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        context.go('/answer-sheets/create/header/');
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          context.go('/answer-sheets/create/question/');
                        }
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
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