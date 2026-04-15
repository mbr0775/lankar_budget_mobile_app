// lib/models/book_model.dart

class BookModel {
  final String id;
  final String userId;
  final String name;
  final double balance;
  final DateTime createdAt;
  final bool synced;

  const BookModel({
    required this.id,
    required this.userId,
    required this.name,
    this.balance = 0.0,
    required this.createdAt,
    this.synced = false,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) => BookModel(
        id:        json['id'] as String,
        userId:    json['user_id'] as String,
        name:      json['name'] as String,
        balance:   (json['balance'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.parse(
            json['created_at'] as String? ?? DateTime.now().toIso8601String()),
        synced:    json['synced'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id':         id,
        'user_id':    userId,
        'name':       name,
        'balance':    balance,
        'created_at': createdAt.toIso8601String(),
        'synced':     synced,
      };

  BookModel copyWith({
    String? name,
    double? balance,
    bool?   synced,
  }) =>
      BookModel(
        id:        id,
        userId:    userId,
        name:      name    ?? this.name,
        balance:   balance ?? this.balance,
        createdAt: createdAt,
        synced:    synced  ?? this.synced,
      );
}