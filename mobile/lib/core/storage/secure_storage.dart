import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _tokenKey = 'access_token';

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {}
  }

  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  Future<bool> hasToken() async => (await getToken()) != null;
}
