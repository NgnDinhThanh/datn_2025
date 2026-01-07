class Student {
  final String id;
  final String studentId;
  final String firstName;
  final String lastName;
  final List<String> classCodes;

  Student({
    required this.id,
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.classCodes,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      studentId: json['student_id'].toString(),
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      classCodes: (json['class_codes'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'first_name': firstName,
      'last_name': lastName,
      'class_codes': classCodes,
    };
  }
}