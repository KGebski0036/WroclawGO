import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/network/api_exception.dart';
import '../models/attraction_models.dart';

class AttractionService {
  final http.Client _client;

  AttractionService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Attraction>> fetchAttractions() async {
    final uri = Uri.parse('${AppConfig.apiUrl}/attractions/');
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load attractions (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = body['features'] as List<dynamic>? ?? const [];

    return features
        .whereType<Map<String, dynamic>>()
        .map(Attraction.fromGeoJsonFeature)
        .where((item) => item.latitude != 0 && item.longitude != 0)
        .toList();
  }

  Future<void> markAsVisited({
    required int attractionId,
    required String accessToken,
  }) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/visited/$attractionId/');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Client-Platform': 'flutter-mobile',
        'X-App-Version': '0.1.0',
      },
      body: '{}',
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: _extractErrorMessage(
        response.body,
        fallback: 'Failed to mark attraction as visited.',
      ),
    );
  }

  Future<Set<int>> fetchVisitedAttractionIds({
    required String accessToken,
  }) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/visited/');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(
          response.body,
          fallback: 'Failed to load visited attractions.',
        ),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return <int>{};
    }

    final result = <int>{};

    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final attraction = item['attraction'];
      if (attraction is! Map<String, dynamic>) {
        continue;
      }

      final nestedProperties = attraction['properties'];
      final id =
          (attraction['id'] as num?)?.toInt() ??
          (nestedProperties is Map<String, dynamic>
              ? (nestedProperties['id'] as num?)?.toInt()
              : null);

      if (id != null) {
        result.add(id);
      }
    }

    return result;
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
      // Ignore parse errors and return fallback.
    }

    return fallback;
  }
}
