class AnswerSheet {
  final String id;
  final String name;
  final DateTime createdAt;
  final int numQuestions;
  final int numOptions;
  final int studentIdDigits;
  final int examIdDigits;
  final int classIdDigits;
  final String filePdf;
  final String fileJson;
  final String filePreview;

  AnswerSheet({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.numQuestions,
    required this.numOptions,
    required this.studentIdDigits,
    required this.examIdDigits,
    required this.classIdDigits,
    required this.filePdf,
    required this.fileJson,
    required this.filePreview,
  });

  factory AnswerSheet.fromJson(Map<String, dynamic> json) {
    String rawId = json['id'] ?? '';
    // Nếu id có dạng ObjectId('...') thì lấy phần trong dấu '
    if (rawId.startsWith('ObjectId(')) {
      rawId = rawId.substring(9, rawId.length - 2);
    }
    return AnswerSheet(
      id: rawId,
      name: json['name'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      numQuestions: json['num_questions'] ?? 0,
      numOptions: json['num_options'] ?? 0,
      studentIdDigits: json['student_id_digits'] ?? 0,
      examIdDigits: json['exam_id_digits'] ?? 0,
      classIdDigits: json['class_id_digits'] ?? 0,
      filePdf: json['file_pdf'] ?? '',
      fileJson: json['file_json'] ?? '',
      filePreview: json['file_preview'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'num_questions': numQuestions,
      'num_options': numOptions,
      'student_id_digits': studentIdDigits,
      'exam_id_digits': examIdDigits,
      'class_id_digits': classIdDigits,
      'file_pdf': filePdf,
      'file_json': fileJson,
      'file_preview': filePreview,
    };
  }
} 