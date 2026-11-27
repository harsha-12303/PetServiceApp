import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/models.dart';

/// Stores a successful session locally. Passwords are never persisted.
class SessionLocalDataSource {
  SessionLocalDataSource({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _sessionKey = 'petcare.cached_session';
  final SharedPreferencesAsync _preferences;

  Future<void> save(AppSession session) => _preferences.setString(
        _sessionKey,
        jsonEncode({
          'bearerToken': session.tokens.bearerToken,
          'refreshToken': session.tokens.refreshToken,
          'expiresIn': session.tokens.expiresIn,
          'menuItems': session.menuItems.map(_menuToJson).toList(),
        }),
      );

  Future<AppSession?> read() async {
    final raw = await _preferences.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map) return null;
      final bearerToken = value['bearerToken']?.toString() ?? '';
      if (bearerToken.isEmpty) return null;
      final menuItems = value['menuItems'] is List
          ? (value['menuItems'] as List)
              .whereType<Map>()
              .map(_menuFromJson)
              .toList(growable: false)
          : const <MenuItem>[];
      return AppSession(
        tokens: AuthTokens(
          bearerToken: bearerToken,
          refreshToken: value['refreshToken']?.toString() ?? '',
          expiresIn: value['expiresIn']?.toString() ?? '',
        ),
        menuItems: menuItems,
      );
    } on FormatException {
      await clear();
      return null;
    }
  }

  Future<void> clear() => _preferences.remove(_sessionKey);

  static Map<String, Object?> _menuToJson(MenuItem item) => {
        'code': item.code,
        'name': item.name,
        'dataTableBlueprintUrl': item.dataTableBlueprintUrl,
        'dataApi': item.dataApi,
        'searchBlueprintUrl': item.searchBlueprintUrl,
        'searchApi': item.searchApi,
        'createApi': item.createApi,
        'children': item.children.map(_menuToJson).toList(),
      };

  static MenuItem _menuFromJson(Map value) => MenuItem(
        code: value['code']?.toString() ?? '',
        name: value['name']?.toString() ?? '',
        dataTableBlueprintUrl: value['dataTableBlueprintUrl']?.toString(),
        dataApi: value['dataApi']?.toString(),
        searchBlueprintUrl: value['searchBlueprintUrl']?.toString(),
        searchApi: value['searchApi']?.toString(),
        createApi: value['createApi']?.toString(),
        children: value['children'] is List
            ? (value['children'] as List)
                .whereType<Map>()
                .map(_menuFromJson)
                .toList(growable: false)
            : const [],
      );
}
