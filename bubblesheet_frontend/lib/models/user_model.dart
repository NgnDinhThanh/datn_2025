class UserProfileData {
  final String id;
  final String username;
  final String email;
  final bool isTeacher;
  final UserStatistics statistics;

  UserProfileData({
    required this.id,
    required this.username,
    required this.email,
    required this.isTeacher,
    required this.statistics,
  });

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    return UserProfileData(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      isTeacher: json['is_teacher'] ?? false,
      statistics: UserStatistics.fromJson(json['statistics'] ?? {}),
    );
  }
}

class UserStatistics {
  final int totalClasses;
  final int totalStudents;
  final int totalQuizzes;
  final int totalGradedPapers;

  UserStatistics({
    required this.totalClasses,
    required this.totalStudents,
    required this.totalQuizzes,
    required this.totalGradedPapers,
  });

  factory UserStatistics.fromJson(Map<String, dynamic> json) {
    return UserStatistics(
      totalClasses: json['total_classes'] ?? 0,
      totalStudents: json['total_students'] ?? 0,
      totalQuizzes: json['total_quizzes'] ?? 0,
      totalGradedPapers: json['total_graded_papers'] ?? 0,
    );
  }
}
