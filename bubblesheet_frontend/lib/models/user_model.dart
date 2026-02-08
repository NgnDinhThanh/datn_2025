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

class AdminUserItem {
  final String id;
  final String username;
  final String email;
  final bool isTeacher;
  final bool isAdmin;

  AdminUserItem({
    required this.id,
    required this.username,
    required this.email,
    required this.isTeacher,
    required this.isAdmin,
  });

  factory AdminUserItem.fromJson(Map<String, dynamic> json) {
    return AdminUserItem(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      isTeacher: json['is_teacher'] ?? false,
      isAdmin: json['is_admin'] ?? false,
    );
  }
}

class AdminStats {
  final int totalUsers;
  final int totalClasses;
  final int totalStudents;
  final int totalQuizzes;
  final int totalGradedPapers;

  AdminStats({
    required this.totalUsers,
    required this.totalClasses,
    required this.totalStudents,
    required this.totalQuizzes,
    required this.totalGradedPapers,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalUsers: json['total_users'] ?? 0,
      totalClasses: json['total_classes'] ?? 0,
      totalStudents: json['total_students'] ?? 0,
      totalQuizzes: json['total_quizzes'] ?? 0,
      totalGradedPapers: json['total_graded_papers'] ?? 0,
    );
  }
}
