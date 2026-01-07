class ClassModel {
  final String id;
  final String class_code;
  final String class_name;
  final int student_count;
  final List<String> exam_ids;
  final String teacher_id;
  final List<String> student_ids;

  ClassModel({
    required this.id,
    required this.class_code,
    required this.class_name,
    required this.student_count,
    required this.teacher_id,
    required this.exam_ids,
    required this.student_ids,
  });

  String get name => class_name;

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      class_code: json['class_code'] ?? '',
      class_name: json['class_name'] ?? '',
      student_count: json['student_count'] ?? 0,
      teacher_id: json['teacher_id'] ?? '',
      exam_ids: (json['exam_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      student_ids: (json['student_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_code': class_code,
      'class_name': class_name,
      'student_count': student_count,
      'exam_ids': exam_ids,
      'teacher_id': teacher_id,
      'student_ids': student_ids,
    };
  }
}