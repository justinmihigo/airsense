import 'user_model.dart';

class AuthResponse {
  final String accessToken;
  final UserModel user;

  const AuthResponse({required this.accessToken, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken: json['access_token'] as String,
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      );
}
