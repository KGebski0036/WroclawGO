import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/network/api_exception.dart';
import '../models/achievement_models.dart';

class AchievementService {
  AchievementService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Achievement>> fetchAllAchievements(String accessToken) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiUrl}/achievements/'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _apiException(response, 'Failed to load achievements.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const <Achievement>[];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Achievement.fromJson)
        .toList();
  }

  Future<List<UserAchievement>> fetchEarnedAchievements(
    String accessToken,
  ) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiUrl}/achievements/my/'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _apiException(response, 'Failed to load earned achievements.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const <UserAchievement>[];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(UserAchievement.fromJson)
        .toList();
  }

  ApiException _apiException(http.Response response, String fallback) {
    return ApiException(
      statusCode: response.statusCode,
      message: _extractErrorMessage(response.body, fallback: fallback),
    );
  }

  String _extractErrorMessage(String body, {required String fallback}) {
    if (body.isEmpty) {
      return fallback;
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
      }
    } catch (_) {
      // Ignore parse errors and use fallback.
    }

    return fallback;
  }
}
