class ExpenseModel {
  final String? id;
  final String description;
  final double amount;
  final DateTime expenseDate;
  final DateTime? createdAt;

  ExpenseModel({
    this.id,
    required this.description,
    required this.amount,
    required this.expenseDate,
    this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id']?.toString(),
      description: json['description'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      expenseDate: DateTime.parse(json['expense_date']),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'description': description,
      'amount': amount,
      'expense_date': expenseDate.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  ExpenseModel copyWith({
    String? id,
    String? description,
    double? amount,
    DateTime? expenseDate,
    DateTime? createdAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
