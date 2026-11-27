import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Session {
  const Session({
    required this.email,
    required this.bearerToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String email;
  final String bearerToken;
  final String? refreshToken;

  /// Milliseconds since epoch.
  final int expiresAt;

  bool isValidAt(DateTime now) =>
      bearerToken.isNotEmpty && now.millisecondsSinceEpoch < expiresAt;

  Map<String, dynamic> toJson() => {
        'email': email,
        'bearerToken': bearerToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt,
      };

  static Session? fromJson(Object? json) {
    if (json is! Map) return null;
    final token = json['bearerToken'];
    final expiresAt = json['expiresAt'];
    if (token is! String || token.isEmpty || expiresAt is! num) return null;
    return Session(
      email: '${json['email'] ?? ''}',
      bearerToken: token,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: expiresAt.toInt(),
    );
  }
}

/// Minimal key/value interface so tests can swap out secure storage.
abstract class SecureKeyValue {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyValue implements SecureKeyValue {
  FlutterSecureKeyValue([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Holds the signed-in session in memory, and in secure storage when the
/// user chose "remember me". Call [restore] once at startup.
class SessionStore {
  SessionStore({SecureKeyValue? storage, DateTime Function()? clock})
      : _storage = storage ?? FlutterSecureKeyValue(),
        _clock = clock ?? DateTime.now;

  static const _key = 'petwork.session';

  final SecureKeyValue _storage;
  final DateTime Function() _clock;
  Session? _session;

  /// The current session, or null when signed out or expired.
  /// An expired session is removed.
  Session? get current {
    final s = _session;
    if (s == null) return null;
    if (s.isValidAt(_clock())) return s;
    clear();
    return null;
  }

  bool get isSignedIn => current != null;

  /// Loads a remembered session from secure storage.
  Future<Session?> restore() async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null) return null;
      final s = Session.fromJson(jsonDecode(raw));
      if (s == null || !s.isValidAt(_clock())) {
        await _storage.delete(_key);
        return null;
      }
      _session = s;
      return s;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Session session, {required bool remember}) async {
    _session = session;
    if (remember) {
      await _storage.write(_key, jsonEncode(session.toJson()));
    } else {
      await _storage.delete(_key);
    }
  }

  Future<void> clear() async {
    _session = null;
    try {
      await _storage.delete(_key);
    } catch (_) {
      // Storage unavailable: the in-memory session is already gone.
    }
  }
}
