import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../models/auth_models.dart';

class AuthService {
  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/auth/login/');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

    if (response.statusCode != 200) {
      throw Exception('Login failed (${response.statusCode})');
    }

    return AuthResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String> refreshAccessToken(String refreshToken) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/auth/token/refresh/');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refreshToken}),
    );

    if (response.statusCode != 200) {
      throw Exception('Token refresh failed (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final access = body['access'] as String?;
    if (access == null || access.isEmpty) {
      throw Exception('Token refresh response missing access token');
    }
    return access;
  }

  Future<AuthUser> fetchCurrentUser(String accessToken) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/auth/me/');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Fetching profile failed (${response.statusCode})');
    }

    return AuthUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> logout({
    required String accessToken,
    required String refreshToken,
  }) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/auth/logout/');
    await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'refresh': refreshToken}),
    );
  }
}
