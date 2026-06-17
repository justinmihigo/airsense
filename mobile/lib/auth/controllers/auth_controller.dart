import 'package:flutter/material.dart';

enum AuthStatus { idle, loading, success, error }

class AuthController extends ChangeNotifier {
  AuthStatus _status = AuthStatus.idle;
  String? _errorMessage;

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;

  Future<bool> signIn({required String username, required String password}) async {
    _setLoading();
    try {
      // TODO: replace with real API call
      await Future.delayed(const Duration(seconds: 1));
      _setSuccess();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> signUp({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
  }) async {
    _setLoading();
    try {
      // TODO: replace with real API call
      await Future.delayed(const Duration(seconds: 1));
      _setSuccess();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> sendResetCode({required String email}) async {
    _setLoading();
    try {
      // TODO: replace with real API call
      await Future.delayed(const Duration(seconds: 1));
      _setSuccess();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> verifyOtp({required String otp}) async {
    _setLoading();
    try {
      // TODO: replace with real API call
      await Future.delayed(const Duration(seconds: 1));
      _setSuccess();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> resetPassword({required String newPassword}) async {
    _setLoading();
    try {
      // TODO: replace with real API call
      await Future.delayed(const Duration(seconds: 1));
      _setSuccess();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setSuccess() {
    _status = AuthStatus.success;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  void reset() {
    _status = AuthStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
