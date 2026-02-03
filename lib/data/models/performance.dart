class Performance {
  final String id;
  final String employeeId;
  final int totalXp;
  final int currentLevel;
  final String rank;
  final int xpToNextLevel;
  final int dayStreak;
  final List<String> badgesEarned;
  final DateTime? lastActivityDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Performance({
    required this.id,
    required this.employeeId,
    required this.totalXp,
    required this.currentLevel,
    required this.rank,
    required this.xpToNextLevel,
    required this.dayStreak,
    required this.badgesEarned,
    this.lastActivityDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Performance.fromJson(Map<String, dynamic> json) {
    return Performance(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      totalXp: json['total_xp'] as int? ?? 0,
      currentLevel: json['current_level'] as int? ?? 1,
      rank: json['rank'] as String? ?? 'Beginner',
      xpToNextLevel: json['xp_to_next_level'] as int? ?? 100,
      dayStreak: json['day_streak'] as int? ?? 0,
      badgesEarned: json['badges_earned'] != null
          ? List<String>.from(json['badges_earned'] as List)
          : [],
      lastActivityDate: json['last_activity_date'] != null
          ? DateTime.parse(json['last_activity_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'total_xp': totalXp,
      'current_level': currentLevel,
      'rank': rank,
      'xp_to_next_level': xpToNextLevel,
      'day_streak': dayStreak,
      'badges_earned': badgesEarned,
      'last_activity_date': lastActivityDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Performance copyWith({
    String? id,
    String? employeeId,
    int? totalXp,
    int? currentLevel,
    String? rank,
    int? xpToNextLevel,
    int? dayStreak,
    List<String>? badgesEarned,
    DateTime? lastActivityDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Performance(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      totalXp: totalXp ?? this.totalXp,
      currentLevel: currentLevel ?? this.currentLevel,
      rank: rank ?? this.rank,
      xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
      dayStreak: dayStreak ?? this.dayStreak,
      badgesEarned: badgesEarned ?? this.badgesEarned,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper method to calculate level from XP
  static int calculateLevel(int totalXp) {
    // Level formula: level = floor(sqrt(totalXp / 100)) + 1
    // This means: Level 1: 0-99 XP, Level 2: 100-399 XP, Level 3: 400-899 XP, etc.
    return (totalXp / 100).floor() ~/ 10 + 1;
  }

  // Helper method to get XP needed for next level
  static int getXpForNextLevel(int currentLevel) {
    // XP needed = (level^2) * 100
    return currentLevel * currentLevel * 100;
  }

  // Helper method to get rank based on level
  static String getRankForLevel(int level) {
    if (level >= 10) return 'Legend';
    if (level >= 8) return 'Master';
    if (level >= 6) return 'Expert';
    if (level >= 4) return 'Rising Star';
    if (level >= 2) return 'Apprentice';
    return 'Beginner';
  }
}
