// lib/models/user_model.dart

class UserModel {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id:        json['id'] as String,
        email:     json['email'] as String? ?? '',
        fullName:  json['full_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        createdAt: DateTime.parse(
            json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toJson() => {
        'id':         id,
        'email':      email,
        'full_name':  fullName,
        'avatar_url': avatarUrl,
        'created_at': createdAt.toIso8601String(),
      };

  UserModel copyWith({
    String? fullName,
    String? avatarUrl,
  }) =>
      UserModel(
        id:        id,
        email:     email,
        fullName:  fullName  ?? this.fullName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt,
      );

  String get displayName => fullName ?? email.split('@').first;
}