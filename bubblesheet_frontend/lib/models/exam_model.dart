class ExamModel {
  final String id;
  final String name;
  final List<String> class_codes;
  final String answersheet;
  final String date;
  final String teacher_id;
  final List<dynamic>? papers;

  ExamModel({
    required this.id,
    required this.name,
    required this.class_codes,
    required this.answersheet,
    required this.date,
    required this.teacher_id,
    this.papers,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    return ExamModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: json['name'] ?? '',
      class_codes: (json['class_codes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      answersheet: json['answersheet'] ?? '',
      date: json['date'] ?? '',
      teacher_id: json['teacher_id'] ?? '',
      papers: json['papers'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'class_codes': class_codes,
      'answersheet': answersheet,
      'date': date,
      'teacher_id': teacher_id,
      'paper': papers
    };
  }
}