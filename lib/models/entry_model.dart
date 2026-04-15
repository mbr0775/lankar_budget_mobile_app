// lib/models/entry_model.dart

class EntryModel {
  final String id;
  final String bookId;
  final double amount;
  final String description;
  final bool isIncome;
  final DateTime entryDate;
  final DateTime createdAt;
  final bool synced;

  const EntryModel({
    required this.id,
    required this.bookId,
    required this.amount,
    required this.description,
    required this.isIncome,
    required this.entryDate,
    required this.createdAt,
    this.synced = false,
  });

  factory EntryModel.fromJson(Map<String, dynamic> json) => EntryModel(
        id:          json['id'] as String,
        bookId:      json['book_id'] as String,
        amount:      (json['amount'] as num).toDouble(),
        description: json['description'] as String? ?? '',
        isIncome:    json['is_income'] as bool,
        entryDate:   DateTime.parse(
            json['entry_date'] as String? ?? json['created_at'] as String),
        createdAt:   DateTime.parse(json['created_at'] as String),
        synced:      json['synced'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id':          id,
        'book_id':     bookId,
        'amount':      amount,
        'description': description,
        'is_income':   isIncome,
        'entry_date':  entryDate.toIso8601String(),
        'created_at':  createdAt.toIso8601String(),
        'synced':      synced,
      };

  EntryModel copyWith({
    double? amount,
    String? description,
    bool?   synced,
  }) =>
      EntryModel(
        id:          id,
        bookId:      bookId,
        amount:      amount      ?? this.amount,
        description: description ?? this.description,
        isIncome:    isIncome,
        entryDate:   entryDate,
        createdAt:   createdAt,
        synced:      synced      ?? this.synced,
      );
}