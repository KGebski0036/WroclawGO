import 'avatar_models.dart';
import 'achievement_models.dart';

class LeaderboardUser {
  LeaderboardUser({
    required this.id,
    required this.username,
    required this.points,
    required this.level,
    required this.rank,
    required this.isLiked,
    required this.favoritesCount,
    required this.equippedItems,
  });

  final int id;
  final String username;
  final int points;
  final int level;
  final int rank;
  bool isLiked;
  int favoritesCount;
  final List<UserEquippedAvatarItem> equippedItems;

  factory LeaderboardUser.fromJson(Map<String, dynamic> json) {
    final equipped = (json['equipped_items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(UserEquippedAvatarItem.fromJson)
        .toList();

    return LeaderboardUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      favoritesCount: (json['favorites_count'] as num?)?.toInt() ?? 0,
      equippedItems: equipped,
    );
  }
}

class LeaderboardResponse {
  LeaderboardResponse({
    required this.count,
    required this.next,
    required this.previous,
    required this.results,
  });

  final int count;
  final String? next;
  final String? previous;
  final List<LeaderboardUser> results;

  factory LeaderboardResponse.fromJson(Map<String, dynamic> json) {
    final users = (json['results'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LeaderboardUser.fromJson)
        .toList();

    return LeaderboardResponse(
      count: (json['count'] as num?)?.toInt() ?? 0,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results: users,
    );
  }
}

class PublicUserProfile {
  PublicUserProfile({
    required this.id,
    required this.username,
    required this.points,
    required this.level,
    required this.rank,
    required this.isLiked,
    required this.favoritesCount,
    required this.achievementsTotal,
    required this.visitedTotal,
    required this.equippedItems,
    required this.achievements,
  });

  final int id;
  final String username;
  final int points;
  final int level;
  final int rank;
  final bool isLiked;
  final int favoritesCount;
  final int achievementsTotal;
  final int visitedTotal;
  final List<UserEquippedAvatarItem> equippedItems;
  final List<UserAchievement> achievements;

  factory PublicUserProfile.fromJson(Map<String, dynamic> json) {
    final equipped = (json['equipped_items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(UserEquippedAvatarItem.fromJson)
        .toList();
    final achievements = (json['achievements'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(UserAchievement.fromJson)
        .toList();

    return PublicUserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      favoritesCount: (json['favorites_count'] as num?)?.toInt() ?? 0,
      achievementsTotal: (json['achievements_total'] as num?)?.toInt() ?? 0,
      visitedTotal: (json['visited_total'] as num?)?.toInt() ?? 0,
      equippedItems: equipped,
      achievements: achievements,
    );
  }
}

class FavoriteToggleResponse {
  FavoriteToggleResponse({
    required this.username,
    required this.isLiked,
    required this.favoritesCount,
  });

  final String username;
  final bool isLiked;
  final int favoritesCount;

  factory FavoriteToggleResponse.fromJson(Map<String, dynamic> json) {
    return FavoriteToggleResponse(
      username: json['username'] as String? ?? '',
      isLiked: json['is_liked'] as bool? ?? false,
      favoritesCount: (json['favorites_count'] as num?)?.toInt() ?? 0,
    );
  }
}
