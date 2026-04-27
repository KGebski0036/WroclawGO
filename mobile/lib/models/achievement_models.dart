class Achievement {
  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.badgePath,
    required this.pointsReward,
  });

  final int id;
  final String name;
  final String description;
  final String badgePath;
  final int pointsReward;

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      badgePath: json['badge_path'] as String? ?? '',
      pointsReward: (json['points_reward'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserAchievement {
  UserAchievement({
    required this.id,
    required this.achievement,
    required this.earnedAt,
  });

  final int id;
  final Achievement achievement;
  final DateTime? earnedAt;

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    return UserAchievement(
      id: (json['id'] as num?)?.toInt() ?? 0,
      achievement: Achievement.fromJson(
        json['achievement'] as Map<String, dynamic>? ?? {},
      ),
      earnedAt: DateTime.tryParse(json['earned_at'] as String? ?? ''),
    );
  }
}
