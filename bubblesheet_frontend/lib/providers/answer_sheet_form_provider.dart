import 'package:flutter/material.dart';

class AnswerSheetFormProvider extends ChangeNotifier {
  // Step 1: Name
  String name = '';

  // Step 2: Headers (tối đa 6)
  List<HeaderField> headers = [
    HeaderField(enabled: true, label: 'Name', width: 'Large'),
    HeaderField(enabled: true, label: 'Quiz', width: 'Medium'),
    HeaderField(enabled: true, label: 'Class', width: 'Medium'),
    HeaderField(enabled: false, label: '', width: 'Medium'),
    HeaderField(enabled: false, label: '', width: 'Medium'),
    HeaderField(enabled: false, label: '', width: 'Medium'),
  ];

  // Step 3: ID counts & labels
  int studentIdDigits = 5;
  String studentIdLabel = 'Student ID';
  int classIdDigits = 5;
  String classIdLabel = 'Class ID';
  int examIdDigits = 5;
  String examIdLabel = 'Quiz ID';

  // Step 4: Questions
  int numQuestions = 25;
  int numOptions = 5;
  List<QuestionField> questions = [];

  // Step 5: Preview (có thể thêm các trường preview nếu cần)

  void setName(String value) {
    name = value;
    notifyListeners();
  }

  void setHeader(int index, HeaderField header) {
    headers[index] = header;
    notifyListeners();
  }

  void setStudentIdDigits(int value) {
    studentIdDigits = value;
    notifyListeners();
  }
  void setStudentIdLabel(String value) {
    studentIdLabel = value;
    notifyListeners();
  }
  void setClassIdDigits(int value) {
    classIdDigits = value;
    notifyListeners();
  }
  void setClassIdLabel(String value) {
    classIdLabel = value;
    notifyListeners();
  }
  void setExamIdDigits(int value) {
    examIdDigits = value;
    notifyListeners();
  }
  void setExamIdLabel(String value) {
    examIdLabel = value;
    notifyListeners();
  }

  void setNumQuestions(int value) {
    numQuestions = value;
    notifyListeners();
  }
  void setNumOptions(int value) {
    numOptions = value;
    notifyListeners();
  }
  void setQuestions(List<QuestionField> value) {
    questions = value;
    notifyListeners();
  }

  void reset() {
    name = '';
    headers = [
      HeaderField(enabled: true, label: 'Name', width: 'Large'),
      HeaderField(enabled: true, label: 'Quiz', width: 'Medium'),
      HeaderField(enabled: true, label: 'Class', width: 'Medium'),
      HeaderField(enabled: false, label: '', width: 'Medium'),
      HeaderField(enabled: false, label: '', width: 'Medium'),
      HeaderField(enabled: false, label: '', width: 'Medium'),
    ];
    studentIdDigits = 5;
    studentIdLabel = 'Student ID';
    classIdDigits = 5;
    classIdLabel = 'Class ID';
    examIdDigits = 5;
    examIdLabel = 'Quiz ID';
    numQuestions = 25;
    numOptions = 5;
    questions = [];
    notifyListeners();
  }
}

class HeaderField {
  bool enabled;
  String label;
  String width; // Large, Medium, Small
  HeaderField({required this.enabled, required this.label, required this.width});
}

class QuestionField {
  int number;
  String type; // Internal Label, ...
  String labels; // ABCDE
  QuestionField({required this.number, required this.type, required this.labels});
}

extension AnswerSheetFormProviderApi on AnswerSheetFormProvider {
  Map<String, dynamic> toApiJson() {
    return {
      "name": name,
      "labels": headers.where((h) => h.enabled).map((h) => h.label).toList(),
      "widths": headers.where((h) => h.enabled).map((h) => h.width).toList(),
      "num_questions": numQuestions,
      "num_options": numOptions,
      "student_id_digits": studentIdDigits,
      "exam_id_digits": examIdDigits,
      "class_id_digits": classIdDigits,
    };
  }
} 