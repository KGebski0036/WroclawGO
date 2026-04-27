import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/network/api_exception.dart';
import '../models/ranking_models.dart';

class RankingService {
  RankingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<LeaderboardResponse> fetchLeaderboard({
    required String accessToken,
    required int page,
    required int pageSize,
    required String search,
    required bool likedOnly,
  }) async {
    final queryParams = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      'search': search.trim(),
      if (likedOnly) 'liked_only': '1',
    };

    final uri = Uri.parse(
      '${AppConfig.apiUrl}/users/ranking/',
    ).replace(queryParameters: queryParams);

    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _apiException(response, 'Failed to load leaderboard.');
    }

    return LeaderboardResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>? ?? {},
    );
  }

  Future<PublicUserProfile> fetchUserProfile({
    required String username,
    required String accessToken,
  }) async {
    final encodedUsername = Uri.encodeComponent(username);
    final response = await _client.get(
      Uri.parse('${AppConfig.apiUrl}/users/$encodedUsername/'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _apiException(response, 'Failed to load user profile.');
    }

    return PublicUserProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>? ?? {},
    );
  }

  Future<FavoriteToggleResponse> toggleFavorite({
    required String username,
    required String accessToken,
  }) async {
    final encodedUsername = Uri.encodeComponent(username);
    final response = await _client.post(
      Uri.parse('${AppConfig.apiUrl}/users/$encodedUsername/favorite/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: '{}',
    );

    if (response.statusCode != 200) {
      throw _apiException(response, 'Could not update favorites right now.');
    }

    return FavoriteToggleResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>? ?? {},
    );
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
        final nonFieldErrors = decoded['non_field_errors'];
        if (nonFieldErrors is List && nonFieldErrors.isNotEmpty) {
          return nonFieldErrors.first.toString();
        }
      }
    } catch (_) {
      // Ignore parse errors and use fallback.
    }

    return fallback;
  }
}
