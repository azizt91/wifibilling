class PaymentMethodModel {
  final String? id;
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;

  PaymentMethodModel({
    this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id']?.toString(),
      bankName: json['bank_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      accountHolder: json['account_holder'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_holder': accountHolder,
      'sort_order': sortOrder,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  PaymentMethodModel copyWith({
    String? id,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return PaymentMethodModel(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountHolder: accountHolder ?? this.accountHolder,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
