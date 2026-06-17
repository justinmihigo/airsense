import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _service;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider(this._service);

  Future<void> restoreSession() async {
    final me = await _service.getMe();
    if (me != null) {
      _user = me;
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading();
    try {
      final auth = await _service.signIn(email, password);
      _user = auth.user;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _setError(_extractMessage(e));
      return false;
    } catch (e) {
      _setError('An unexpected error occurred');
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _setLoading();
    try {
      final auth = await _service.register(name, email, password);
      _user = auth.user;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _setError(_extractMessage(e));
      return false;
    } catch (e) {
      _setError('An unexpected error occurred');
      return false;
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data.containsKey('detail')) return data['detail'] as String;
    return e.message ?? 'Request failed';
  }
}
