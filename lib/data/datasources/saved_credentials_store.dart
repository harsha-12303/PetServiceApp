import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedCredentials {
  const SavedCredentials({required this.email, required this.password});
  final String email;
  final String password;
}

/// Remembers the last successful login so the sign-in form fills itself in.
abstract class CredentialsStore {
  Future<SavedCredentials?> read();
  Future<void> save(String email, String password);
  Future<void> clear();
}

/// The email is kept in the app's preferences; the password in secure
/// storage (Android Keystore / iOS Keychain), never as plain text.
class DeviceCredentialsStore implements CredentialsStore {
  DeviceCredentialsStore({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secureStorage,
  })  : _preferences = preferences ?? SharedPreferencesAsync(),
        _secure = secureStorage ?? const FlutterSecureStorage();

  static const _emailKey = 'petcare.saved_email';
  static const _passwordKey = 'petcare.saved_password';

  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secure;

  @override
  Future<SavedCredentials?> read() async {
    try {
      final email = await _preferences.getString(_emailKey);
      if (email == null || email.isEmpty) return null;
      final password = await _secure.read(key: _passwordKey) ?? '';
      return SavedCredentials(email: email, password: password);
    } catch (_) {
      return null; // storage unavailable: just show an empty form
    }
  }

  @override
  Future<void> save(String email, String password) async {
    try {
      await _preferences.setString(_emailKey, email);
      await _secure.write(key: _passwordKey, value: password);
    } catch (_) {
      // Not being able to remember the login must never block signing in.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _preferences.remove(_emailKey);
      await _secure.delete(key: _passwordKey);
    } catch (_) {}
  }
}
