class AnswerKeyModel {
  final String id;
  final String idTeacher;
  final String quizId;
  final String answersheetId;
  final int numQuestions;
  final int numVersions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<dynamic> answerBank;
  final List<dynamic> versions;

  AnswerKeyModel({
    required this.id,
    required this.idTeacher,
    required this.quizId,
    required this.answersheetId,
    required this.numQuestions,
    required this.numVersions,
    required this.createdAt,
    required this.updatedAt,
    required this.answerBank,
    required this.versions,
  });

  factory AnswerKeyModel.fromJson(Map<String, dynamic> json) {
    return AnswerKeyModel(
      id: json['id']?.toString() ?? '',
      idTeacher: json['id_teacher']?.toString() ?? '',
      quizId: json['quiz_id']?.toString() ?? '',
      answersheetId: json['answersheet_id']?.toString() ?? '',
      numQuestions: json['num_questions'] is int ? json['num_questions'] : int.tryParse(json['num_questions']?.toString() ?? '') ?? 0,
      numVersions: json['num_versions'] is int ? json['num_versions'] : int.tryParse(json['num_versions']?.toString() ?? '') ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
      answerBank: json['answer_bank'] ?? [],
      versions: json['versions'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_teacher': idTeacher,
      'quiz_id': quizId,
      'answersheet_id': answersheetId,
      'num_questions': numQuestions,
      'num_versions': numVersions,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'answer_bank': answerBank,
      'versions': versions,
    };
  }
}