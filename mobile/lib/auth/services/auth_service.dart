import 'package:dio/dio.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';
import '../../core/storage/secure_storage.dart';

class AuthService {
  final Dio _dio;
  final SecureStorage _storage;

  AuthService(this._dio, this._storage);

  Future<AuthResponse> signIn(String email, String password) async {
    final res = await _dio.post(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
    final auth = AuthResponse.fromJson(res.data as Map<String, dynamic>);
    await _storage.saveToken(auth.accessToken);
    return auth;
  }

  Future<AuthResponse> register(String name, String email, String password) async {
    final res = await _dio.post(
      '/api/auth/register',
      data: {'name': name, 'email': email, 'password': password},
    );
    final auth = AuthResponse.fromJson(res.data as Map<String, dynamic>);
    await _storage.saveToken(auth.accessToken);
    return auth;
  }

  Future<UserModel?> getMe() async {
    try {
      final res = await _dio.get('/api/auth/me');
      return UserModel.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() => _storage.deleteToken();
}
