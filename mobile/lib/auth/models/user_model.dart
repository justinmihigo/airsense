class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final DateTime createdAt;
  final DateTime? emailVerifiedAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.emailVerifiedAt,
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        emailVerifiedAt: json['email_verified_at'] != null
            ? DateTime.parse(json['email_verified_at'] as String)
            : null,
      );
}
