import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/network/api_exception.dart';
import '../models/avatar_models.dart';

class AvatarService {
  AvatarService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const List<String> slotOrder = <String>[
    'background',
    'base',
    'pants',
    'shirts',
    'mouth',
    'eyes',
    'hair',
  ];

  Future<List<AvatarItem>> fetchAllItems(String accessToken) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiUrl}/avatar/items/'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _apiException(response, 'Failed to load avatar shop items.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const <AvatarItem>[];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AvatarItem.fromJson)
        .toList();
  }

  Future<List<UserAvatarItem>> fetchUnlockedItemRows(String accessToken) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiUrl}/avatar/my-items/'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _apiException(response, 'Failed to load unlocked avatar items.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const <UserAvatarItem>[];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(UserAvatarItem.fromJson)
        .toList();
  }

  Future<List<AvatarItem>> fetchUnlockedItems(String accessToken) async {
    final rows = await fetchUnlockedItemRows(accessToken);
    return rows.map((row) => row.item).toList();
  }

  Future<List<UserEquippedAvatarItem>> fetchEquippedItems(
    String accessToken,
  ) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiUrl}/avatar/my-equipped/'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _apiException(response, 'Failed to load equipped avatar items.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const <UserEquippedAvatarItem>[];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(UserEquippedAvatarItem.fromJson)
        .toList();
  }

  Future<UserAvatarItem> purchaseItem(int itemId, String accessToken) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiUrl}/avatar/purchase/$itemId/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: '{}',
    );

    if (response.statusCode != 201) {
      throw _apiException(response, 'Could not buy this item.');
    }

    return UserAvatarItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>? ?? {},
    );
  }

  Future<UserEquippedAvatarItem> equipItem(
    int itemId,
    String accessToken,
  ) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiUrl}/avatar/equip/$itemId/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: '{}',
    );

    if (response.statusCode != 200) {
      throw _apiException(response, 'Could not equip this item.');
    }

    return UserEquippedAvatarItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>? ?? {},
    );
  }

  Future<void> unequipSlot(String slot, String accessToken) async {
    final response = await _client.delete(
      Uri.parse('${AppConfig.apiUrl}/avatar/unequip/$slot/'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw _apiException(response, 'Could not remove this item.');
    }
  }

  Map<String, List<AvatarItem>> groupItemsByTag(List<AvatarItem> items) {
    final grouped = <String, List<AvatarItem>>{};

    for (final item in items) {
      grouped.putIfAbsent(item.tag, () => <AvatarItem>[]).add(item);
    }

    return grouped;
  }

  bool canUnequipSlot(String slot) {
    return !<String>{'base', 'background'}.contains(slot);
  }

  List<UserEquippedAvatarItem> sortEquippedItems(
    List<UserEquippedAvatarItem> items,
  ) {
    final order = <String, int>{
      for (var i = 0; i < slotOrder.length; i++) slotOrder[i]: i,
    };

    final sorted = [...items];
    sorted.sort((a, b) {
      final oa = order[a.slot] ?? 999;
      final ob = order[b.slot] ?? 999;
      return oa.compareTo(ob);
    });
    return sorted;
  }

  String slotLabel(String slot) {
    return switch (slot) {
      'background' => 'Background',
      'base' => 'Base',
      'pants' => 'Pants',
      'shirts' => 'Shirts',
      'mouth' => 'Mouth',
      'eyes' => 'Eyes',
      'hair' => 'Hair',
      _ => slot,
    };
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
      // Ignore parse errors and fall back to default message.
    }

    return fallback;
  }
}
