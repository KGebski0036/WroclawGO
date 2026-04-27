import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../core/storage/token_storage.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';

class AppSession extends ChangeNotifier {
  AppSession({
    required AuthService authService,
    required TokenStorage tokenStorage,
  }) : _authService = authService,
       _tokenStorage = tokenStorage;

  final AuthService _authService;
  final TokenStorage _tokenStorage;

  String? _accessToken;
  String? _refreshToken;
  AuthUser? _user;
  bool _isLoading = true;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _accessToken != null && _refreshToken != null;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  AuthUser? get user => _user;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _accessToken = await _tokenStorage.readAccessToken();
    _refreshToken = await _tokenStorage.readRefreshToken();

    if (_accessToken != null) {
      try {
        _user = await _authService.fetchCurrentUser(_accessToken!);
      } catch (_) {
        await clearSession();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    final response = await _authService.login(email: email, password: password);

    _accessToken = response.access;
    _refreshToken = response.refresh;
    _user = response.user;

    await _tokenStorage.writeTokens(
      access: response.access,
      refresh: response.refresh,
    );
    notifyListeners();
  }

  Future<String> refreshAccessToken() async {
    final refresh = _refreshToken;
    if (refresh == null) {
      throw Exception('No refresh token available');
    }

    final nextAccess = await _authService.refreshAccessToken(refresh);
    _accessToken = nextAccess;
    await _tokenStorage.writeAccessToken(nextAccess);
    notifyListeners();
    return nextAccess;
  }

  Future<void> reloadCurrentUser() async {
    _user = await withAuthorizedRequest(
      (accessToken) => _authService.fetchCurrentUser(accessToken),
    );
    notifyListeners();
  }

  Future<T> withAuthorizedRequest<T>(
    Future<T> Function(String accessToken) request,
  ) async {
    final access = _accessToken;
    if (access == null) {
      throw Exception('No access token available');
    }

    try {
      return await request(access);
    } on ApiException catch (err) {
      if (err.statusCode != 401) {
        rethrow;
      }

      try {
        final refreshed = await refreshAccessToken();
        return await request(refreshed);
      } catch (_) {
        await clearSession();
        rethrow;
      }
    }
  }

  Future<void> logout() async {
    final access = _accessToken;
    final refresh = _refreshToken;

    if (access != null && refresh != null) {
      try {
        await _authService.logout(accessToken: access, refreshToken: refresh);
      } catch (_) {
        // Ignore network logout errors and clear local session anyway.
      }
    }

    await clearSession();
  }

  Future<void> clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    await _tokenStorage.clear();
    notifyListeners();
  }
}
