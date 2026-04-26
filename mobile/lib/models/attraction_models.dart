import 'package:flutter/material.dart';

class Attraction {
  Attraction({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.pointsReward,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final String name;
  final String description;
  final String category;
  final int pointsReward;
  final double latitude;
  final double longitude;

  factory Attraction.fromGeoJsonFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final coordinates =
        (geometry['coordinates'] as List<dynamic>? ?? [0.0, 0.0]);
    final longitude = (coordinates.isNotEmpty ? coordinates[0] : 0.0) as num?;
    final latitude = (coordinates.length > 1 ? coordinates[1] : 0.0) as num?;
    final featureId =
        (feature['id'] as num?)?.toInt() ??
        (properties['id'] as num?)?.toInt() ??
        0;

    return Attraction(
      id: featureId,
      name: properties['name'] as String? ?? 'Unknown attraction',
      description: properties['description'] as String? ?? '',
      category: properties['category'] as String? ?? 'Unknown',
      pointsReward: (properties['points_reward'] as num?)?.toInt() ?? 0,
      longitude: longitude?.toDouble() ?? 0.0,
      latitude: latitude?.toDouble() ?? 0.0,
    );
  }

  static Color categoryColor(String category) {
    switch (category) {
      case 'Muzeum':
        return Colors.blue;
      case 'Park':
        return Colors.green;
      case 'Krasnal':
        return Colors.orange;
      case 'Kościół':
        return Colors.pink;
      case 'Zabytki':
        return Colors.purple;
      default:
        return const Color(0xFFF43F5E);
    }
  }

  static String categoryHex(String category) {
    final color = categoryColor(category);
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }
}
