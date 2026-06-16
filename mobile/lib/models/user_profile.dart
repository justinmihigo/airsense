class UserProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String phone;
  final String role;
  final String? avatarUrl;
  final DateTime? birthDate;
  final String? gender;

  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.birthDate,
    this.gender,
  });

  String get fullName => '$firstName $lastName';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      birthDate: json['birthDate'] != null
          ? DateTime.parse(json['birthDate'] as String)
          : null,
      gender: json['gender'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'username': username,
        'email': email,
        'phone': phone,
        'role': role,
        'avatarUrl': avatarUrl,
        'birthDate': birthDate?.toIso8601String(),
        'gender': gender,
      };

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? avatarUrl,
    DateTime? birthDate,
    String? gender,
  }) {
    return UserProfile(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
    );
  }
}
