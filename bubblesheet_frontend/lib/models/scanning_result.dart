class ScanningResult {
  final bool success;
  final int score;
  final int totalQuestions;
  final double percentage;
  final String studentId;
  final String quizId;
  final String? classId;
  final Map<String, dynamic> answers;
  final Map<String, dynamic>? correctAnswers; // Answer key from server
  final String versionCode;
  final String? annotatedImageBase64;
  final String? warpedImageBase64; // Raw warped image for re-annotation
  final String? infoSectionBase64; // Cropped info section (student/quiz/class IDs)
  final String? error;
  final int multipleMarks; // Count of questions with multiple bubbles marked
  final int blankCount; // Count of questions with no answer

  ScanningResult({
    required this.success,
    required this.score,
    required this.totalQuestions,
    required this.percentage,
    required this.studentId,
    required this.quizId,
    this.classId,
    required this.answers,
    this.correctAnswers,
    required this.versionCode,
    this.annotatedImageBase64,
    this.warpedImageBase64,
    this.infoSectionBase64,
    this.error,
    this.multipleMarks = 0,
    this.blankCount = 0,
  });

  factory ScanningResult.fromJson(Map<String, dynamic> json) {
    return ScanningResult(
      success: json['success'] ?? false,
      score: json['score'] ?? 0,
      totalQuestions: json['total_questions'] ?? 0,
      percentage: (json['percentage'] ?? 0.0).toDouble(),
      studentId: json['student_id'] ?? '',
      quizId: json['quiz_id'] ?? '',
      classId: json['class_id'],
      answers: json['answers'] is Map
          ? Map<String, dynamic>.from(json['answers'])
          : {},
      correctAnswers: json['correct_answers'] is Map
          ? Map<String, dynamic>.from(json['correct_answers'])
          : null,
      versionCode: json['version_code'] ?? '',
      annotatedImageBase64: json['annotated_image_base64'],
      warpedImageBase64: json['warped_image_base64'],
      infoSectionBase64: json['info_section_base64'],
      error: json['error'],
      multipleMarks: json['multiple_marks'] ?? 0,
      blankCount: json['blank_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'score': score,
      'total_questions': totalQuestions,
      'percentage': percentage,
      'student_id': studentId,
      'quiz_id': quizId,
      'class_id': classId,
      'answers': answers,
      'correct_answers': correctAnswers,
      'version_code': versionCode,
      'annotated_image_base64': annotatedImageBase64,
      'warped_image_base64': warpedImageBase64,
      'info_section_base64': infoSectionBase64,
      'error': error,
      'multiple_marks': multipleMarks,
      'blank_count': blankCount,
    };
  }
  
  /// Create a copy with updated fields
  ScanningResult copyWith({
    bool? success,
    int? score,
    int? totalQuestions,
    double? percentage,
    String? studentId,
    String? quizId,
    String? classId,
    Map<String, dynamic>? answers,
    Map<String, dynamic>? correctAnswers,
    String? versionCode,
    String? annotatedImageBase64,
    String? warpedImageBase64,
    String? infoSectionBase64,
    String? error,
    int? multipleMarks,
    int? blankCount,
  }) {
    return ScanningResult(
      success: success ?? this.success,
      score: score ?? this.score,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      percentage: percentage ?? this.percentage,
      studentId: studentId ?? this.studentId,
      quizId: quizId ?? this.quizId,
      classId: classId ?? this.classId,
      answers: answers ?? this.answers,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      versionCode: versionCode ?? this.versionCode,
      annotatedImageBase64: annotatedImageBase64 ?? this.annotatedImageBase64,
      warpedImageBase64: warpedImageBase64 ?? this.warpedImageBase64,
      infoSectionBase64: infoSectionBase64 ?? this.infoSectionBase64,
      error: error ?? this.error,
      multipleMarks: multipleMarks ?? this.multipleMarks,
      blankCount: blankCount ?? this.blankCount,
    );
  }
}

class PreviewCheckResult {
  final bool ready;
  final List<Map<String, dynamic>> markers;
  final List<Map<String, dynamic>> markersNorm;
  final Map<String, int> imageSize;
  final String? error;

  PreviewCheckResult({
    required this.ready,
    required this.markers,
    required this.markersNorm,
    required this.imageSize,
    this.error,
  });

  factory PreviewCheckResult.fromJson(Map<String, dynamic> json) {
    return PreviewCheckResult(
      ready: json['ready'] ?? false,
      markers: json['markers'] is List
          ? List<Map<String, dynamic>>.from(json['markers'])
          : [],
      markersNorm: json['markers_norm'] is List
          ? List<Map<String, dynamic>>.from(json['markers_norm'])
          : [],
      imageSize: json['image_size'] is Map
          ? Map<String, int>.from(json['image_size'])
          : {'width': 0, 'height': 0},
      error: json['error'],
    );
  }
}





