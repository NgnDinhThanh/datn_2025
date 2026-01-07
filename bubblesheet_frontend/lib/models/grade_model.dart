class GradeModel {
  final String id;
  final String classCode;
  final String examId; // quiz_id
  final String studentId;
  final double? score;
  final double? percentage;
  final Map<String, dynamic> answers;
  final String? scannedImage;
  final String? annotatedImage;
  final DateTime? scannedAt;
  final String? versionCode;
  final String? answersheetId;
  final String? teacherId;

  GradeModel({
    required this.id,
    required this.classCode,
    required this.examId,
    required this.studentId,
    this.score,
    this.percentage,
    required this.answers,
    this.scannedImage,
    this.annotatedImage,
    this.scannedAt,
    this.versionCode,
    this.answersheetId,
    this.teacherId,
  });

  factory GradeModel.fromJson(Map<String, dynamic> json) {
    return GradeModel(
      id: json['id']?.toString() ?? '',
      classCode: json['class_code']?.toString() ?? '',
      examId: json['exam_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      score: json['score'] != null ? (json['score'] is int ? json['score'].toDouble() : json['score']) : null,
      percentage: json['percentage'] != null ? (json['percentage'] is int ? json['percentage'].toDouble() : json['percentage']) : null,
      answers: json['answers'] is Map ? Map<String, dynamic>.from(json['answers']) : {},
      scannedImage: json['scanned_image']?.toString(),
      annotatedImage: json['annotated_image']?.toString(),
      scannedAt: json['scanned_at'] != null ? DateTime.tryParse(json['scanned_at'].toString()) : null,
      versionCode: json['version_code']?.toString(),
      answersheetId: json['answersheet_id']?.toString(),
      teacherId: json['teacher_id']?.toString(),
    );
  }
}

class ItemAnalysisModel {
  final String quizId;
  final int totalPapers;
  final int numQuestions;
  final List<ItemModel> items;
  final StatisticsModel statistics;

  ItemAnalysisModel({
    required this.quizId,
    required this.totalPapers,
    required this.numQuestions,
    required this.items,
    required this.statistics,
  });

  factory ItemAnalysisModel.fromJson(Map<String, dynamic> json) {
    return ItemAnalysisModel(
      quizId: json['quiz_id']?.toString() ?? '',
      totalPapers: json['total_papers'] is int ? json['total_papers'] : int.tryParse(json['total_papers']?.toString() ?? '') ?? 0,
      numQuestions: json['num_questions'] is int ? json['num_questions'] : int.tryParse(json['num_questions']?.toString() ?? '') ?? 0,
      items: (json['items'] as List?)?.map((e) => ItemModel.fromJson(e)).toList() ?? [],
      statistics: StatisticsModel.fromJson(json['statistics'] ?? {}),
    );
  }
}

class ItemModel {
  final int questionNumber;
  final String correctAnswer;
  final int correctCount;
  final int incorrectCount;
  final int blankCount;
  final double correctPercent;
  final double incorrectPercent;
  final double blankPercent;

  ItemModel({
    required this.questionNumber,
    required this.correctAnswer,
    required this.correctCount,
    required this.incorrectCount,
    required this.blankCount,
    required this.correctPercent,
    required this.incorrectPercent,
    required this.blankPercent,
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      questionNumber: json['question_number'] is int ? json['question_number'] : int.tryParse(json['question_number']?.toString() ?? '') ?? 0,
      correctAnswer: json['correct_answer']?.toString() ?? '',
      correctCount: json['correct_count'] is int ? json['correct_count'] : int.tryParse(json['correct_count']?.toString() ?? '') ?? 0,
      incorrectCount: json['incorrect_count'] is int ? json['incorrect_count'] : int.tryParse(json['incorrect_count']?.toString() ?? '') ?? 0,
      blankCount: json['blank_count'] is int ? json['blank_count'] : int.tryParse(json['blank_count']?.toString() ?? '') ?? 0,
      correctPercent: json['correct_percent'] is double ? json['correct_percent'] : (json['correct_percent'] is int ? json['correct_percent'].toDouble() : double.tryParse(json['correct_percent']?.toString() ?? '') ?? 0.0),
      incorrectPercent: json['incorrect_percent'] is double ? json['incorrect_percent'] : (json['incorrect_percent'] is int ? json['incorrect_percent'].toDouble() : double.tryParse(json['incorrect_percent']?.toString() ?? '') ?? 0.0),
      blankPercent: json['blank_percent'] is double ? json['blank_percent'] : (json['blank_percent'] is int ? json['blank_percent'].toDouble() : double.tryParse(json['blank_percent']?.toString() ?? '') ?? 0.0),
    );
  }
}

class StatisticsModel {
  final double minScore;
  final double maxScore;
  final double averageScore;
  final double averagePercent;
  final double medianScore;
  final double stdDeviation;

  StatisticsModel({
    required this.minScore,
    required this.maxScore,
    required this.averageScore,
    required this.averagePercent,
    required this.medianScore,
    required this.stdDeviation,
  });

  factory StatisticsModel.fromJson(Map<String, dynamic> json) {
    return StatisticsModel(
      minScore: json['min_score'] is double ? json['min_score'] : (json['min_score'] is int ? json['min_score'].toDouble() : double.tryParse(json['min_score']?.toString() ?? '') ?? 0.0),
      maxScore: json['max_score'] is double ? json['max_score'] : (json['max_score'] is int ? json['max_score'].toDouble() : double.tryParse(json['max_score']?.toString() ?? '') ?? 0.0),
      averageScore: json['average_score'] is double ? json['average_score'] : (json['average_score'] is int ? json['average_score'].toDouble() : double.tryParse(json['average_score']?.toString() ?? '') ?? 0.0),
      averagePercent: json['average_percent'] is double ? json['average_percent'] : (json['average_percent'] is int ? json['average_percent'].toDouble() : double.tryParse(json['average_percent']?.toString() ?? '') ?? 0.0),
      medianScore: json['median_score'] is double ? json['median_score'] : (json['median_score'] is int ? json['median_score'].toDouble() : double.tryParse(json['median_score']?.toString() ?? '') ?? 0.0),
      stdDeviation: json['std_deviation'] is double ? json['std_deviation'] : (json['std_deviation'] is int ? json['std_deviation'].toDouble() : double.tryParse(json['std_deviation']?.toString() ?? '') ?? 0.0),
    );
  }
}


