class AvatarItem {
  AvatarItem({
    required this.id,
    required this.tag,
    required this.name,
    required this.svgPath,
    required this.cost,
    required this.isDefault,
  });

  final int id;
  final String tag;
  final String name;
  final String svgPath;
  final int cost;
  final bool isDefault;

  factory AvatarItem.fromJson(Map<String, dynamic> json) {
    return AvatarItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      tag: json['tag'] as String? ?? '',
      name: json['name'] as String? ?? '',
      svgPath: json['svg_path'] as String? ?? '',
      cost: (json['cost'] as num?)?.toInt() ?? 0,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }
}

class UserAvatarItem {
  UserAvatarItem({
    required this.id,
    required this.item,
    required this.unlockedAt,
  });

  final int id;
  final AvatarItem item;
  final DateTime? unlockedAt;

  factory UserAvatarItem.fromJson(Map<String, dynamic> json) {
    return UserAvatarItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      item: AvatarItem.fromJson(json['item'] as Map<String, dynamic>? ?? {}),
      unlockedAt: DateTime.tryParse(json['unlocked_at'] as String? ?? ''),
    );
  }
}

class UserEquippedAvatarItem {
  UserEquippedAvatarItem({
    required this.id,
    required this.slot,
    required this.item,
    required this.updatedAt,
  });

  final int id;
  final String slot;
  final AvatarItem item;
  final DateTime? updatedAt;

  factory UserEquippedAvatarItem.fromJson(Map<String, dynamic> json) {
    return UserEquippedAvatarItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slot: json['slot'] as String? ?? '',
      item: AvatarItem.fromJson(json['item'] as Map<String, dynamic>? ?? {}),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}
