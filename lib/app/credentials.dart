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

  Future<SavedCredentials?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_kUsername) ?? '';
    final password = prefs.getString(_kPassword) ?? '';
    final rememberMe = prefs.getBool(_kRememberMe) ?? true;
    final server = prefs.getString(_kServer) ?? 'eu';

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
    await prefs.setString(_kUsername, creds.username);
    await prefs.setString(_kPassword, creds.password);
    await prefs.setString(_kServer, creds.server);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUsername);
    await prefs.remove(_kPassword);
  }
}
