import '../api_client.dart';
import '../api_exception.dart';
import 'session_store.dart';

class AuthService {
  AuthService(this._client, this._sessions, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final ApiClient _client;
  final SessionStore _sessions;
  final DateTime Function() _clock;

  static const _defaultLifetime = Duration(hours: 1);

  /// `POST /users/api/login`. With [remember], the session survives restarts.
  Future<Session> login({
    required String email,
    required String password,
    bool remember = false,
  }) async {
    final body = await _client.post(
      '/users/api/login',
      body: {'email': email.trim(), 'password': password},
      auth: false,
    );
    final token = body is Map ? body['bearerToken'] : null;
    if (token is! String || token.isEmpty) {
      throw const ApiException(
          'Login failed: the server did not return a token.', 0);
    }
    final session = Session(
      email: email.trim(),
      bearerToken: token,
      refreshToken: (body as Map)['refreshToken'] as String?,
      expiresAt:
          _clock().millisecondsSinceEpoch + parseExpiresInMs(body['expiresIn']),
    );
    await _sessions.save(session, remember: remember);
    return session;
  }

  /// Public sign-up: `POST /users/api/CustomerRegister`. Returns the message
  /// to show.
  Future<String> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final body = await _client.post(
      '/users/api/CustomerRegister',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
      },
      auth: false,
    );
    return _messageOr(body, 'Account created successfully.');
  }

  /// Admin creates a user: `POST /users/api/register` (e.g. profileCode
  /// `VET`, `STAFF`, `ADMIN_PROFILE`).
  Future<String> createUser({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String profileCode,
  }) async {
    final body = await _client.post('/users/api/register', body: {
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'password': password,
      'profileCode': profileCode,
    });
    return _messageOr(body, 'User created successfully.');
  }

  /// There is no logout endpoint: the session is only cleared locally.
  Future<void> logout() => _sessions.clear();

  static String _messageOr(Object? body, String fallback) {
    final message = body is Map ? body['message'] : null;
    return message is String && message.isNotEmpty ? message : fallback;
  }
}

/// `expiresIn` is seconds, usually sent as a string. Missing or invalid → 1 hour.
int parseExpiresInMs(Object? expiresIn) {
  final seconds = expiresIn is num
      ? expiresIn.toDouble()
      : double.tryParse('${expiresIn ?? ''}'.trim());
  if (seconds == null || !seconds.isFinite || seconds <= 0) {
    return AuthService._defaultLifetime.inMilliseconds;
  }
  return (seconds * 1000).round();
}
