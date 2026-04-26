import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedCredentials {
  final String username;
  final String password;
  final bool rememberMe;
  final String server;

  const SavedCredentials({
    required this.username,
    required this.password,
    required this.rememberMe,
    this.server = 'eu',
  });

  bool get isComplete => username.isNotEmpty && password.isNotEmpty;
}

class CredentialStore {
  static const _kUsername = 'dexcom.username';
  static const _kPassword = 'dexcom.password';
  static const _kRememberMe = 'dexcom.rememberMe';
  static const _kServer = 'dexcom.server';
  static const _secureStorage = FlutterSecureStorage();

  Future<SavedCredentials?> read() async {
    final prefs = await SharedPreferences.getInstance();
    var username = await _secureStorage.read(key: _kUsername) ?? '';
    var password = await _secureStorage.read(key: _kPassword) ?? '';
    final rememberMe = prefs.getBool(_kRememberMe) ?? true;
    final server = prefs.getString(_kServer) ?? 'eu';

    // One-way migration from the previous SharedPreferences credential store.
    final legacyUsername = prefs.getString(_kUsername) ?? '';
    final legacyPassword = prefs.getString(_kPassword) ?? '';
    if ((username.isEmpty || password.isEmpty) &&
        legacyUsername.isNotEmpty &&
        legacyPassword.isNotEmpty) {
      username = legacyUsername;
      password = legacyPassword;
      await _secureStorage.write(key: _kUsername, value: legacyUsername);
      await _secureStorage.write(key: _kPassword, value: legacyPassword);
    }
    await prefs.remove(_kUsername);
    await prefs.remove(_kPassword);

    final saved = SavedCredentials(
      username: username,
      password: password,
      rememberMe: rememberMe,
      server: server,
    );

    if (!saved.isComplete) return null;
    return saved;
  }

  Future<void> write(SavedCredentials creds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRememberMe, creds.rememberMe);
    if (!creds.rememberMe) {
      await clear();
      return;
    }
    await _secureStorage.write(key: _kUsername, value: creds.username);
    await _secureStorage.write(key: _kPassword, value: creds.password);
    await prefs.setString(_kServer, creds.server);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUsername);
    await prefs.remove(_kPassword);
    await _secureStorage.delete(key: _kUsername);
    await _secureStorage.delete(key: _kPassword);
  }
}
