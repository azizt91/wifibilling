import 'package:hive/hive.dart';

part 'invoice_model.g.dart';

@HiveType(typeId: 1)
class InvoiceModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String customerId;

  @HiveField(2)
  final int? packageId;

  @HiveField(3)
  final String invoicePeriod;

  @HiveField(4)
  final double amount;

  @HiveField(5)
  final String status;

  @HiveField(6)
  final DateTime? dueDate;

  @HiveField(7)
  final DateTime? paidAt;

  @HiveField(8)
  final DateTime? createdAt;

  @HiveField(9)
  final double? totalDue;

  @HiveField(10)
  final double? amountPaid;

  @HiveField(11)
  final List<Map<String, dynamic>>? paymentHistory;

  @HiveField(12)
  final DateTime? lastPaymentDate;

  @HiveField(13)
  final String? paymentMethod;

  // Profile data from join (not stored in Hive)
  final Map<String, dynamic>? profiles;

  InvoiceModel({
    required this.id,
    required this.customerId,
    this.packageId,
    required this.invoicePeriod,
    required this.amount,
    required this.status,
    this.dueDate,
    this.paidAt,
    this.createdAt,
    this.totalDue,
    this.amountPaid,
    this.paymentHistory,
    this.lastPaymentDate,
    this.paymentMethod,
    this.profiles,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      packageId: json['package_id'] as int?,
      invoicePeriod: json['invoice_period'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      totalDue: json['total_due'] != null
          ? (json['total_due'] as num).toDouble()
          : null,
      amountPaid: json['amount_paid'] != null
          ? (json['amount_paid'] as num).toDouble()
          : 0,
      paymentHistory: json['payment_history'] != null
          ? List<Map<String, dynamic>>.from(json['payment_history'] as List)
          : null,
      lastPaymentDate: json['last_payment_date'] != null
          ? DateTime.parse(json['last_payment_date'] as String)
          : null,
      paymentMethod: json['payment_method'] as String?,
      profiles: json['profiles'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'package_id': packageId,
      'invoice_period': invoicePeriod,
      'amount': amount,
      'status': status,
      'due_date': dueDate?.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'total_due': totalDue,
      'amount_paid': amountPaid,
      'payment_history': paymentHistory,
      'last_payment_date': lastPaymentDate?.toIso8601String(),
      'payment_method': paymentMethod,
    };
  }

  InvoiceModel copyWith({
    String? id,
    String? customerId,
    int? packageId,
    String? invoicePeriod,
    double? amount,
    String? status,
    DateTime? dueDate,
    DateTime? paidAt,
    DateTime? createdAt,
    double? totalDue,
    double? amountPaid,
    List<Map<String, dynamic>>? paymentHistory,
    DateTime? lastPaymentDate,
    String? paymentMethod,
    Map<String, dynamic>? profiles,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      packageId: packageId ?? this.packageId,
      invoicePeriod: invoicePeriod ?? this.invoicePeriod,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
      totalDue: totalDue ?? this.totalDue,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentHistory: paymentHistory ?? this.paymentHistory,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      profiles: profiles ?? this.profiles,
    );
  }

  bool get isPaid => status == 'paid';
  bool get isUnpaid => status == 'unpaid';
  bool get isInstallment => status == 'installment' || status == 'partially_paid';
  bool get isOverdue => dueDate != null && DateTime.now().isAfter(dueDate!);

  double get remainingAmount => (totalDue ?? amount) - (amountPaid ?? 0);
  
  // Computed properties for compatibility
  String get invoiceNumber => 'INV-${id.substring(0, 8).toUpperCase()}';
  String get customerName => profiles?['full_name'] as String? ?? '';
  String get customerIdpl => profiles?['idpl'] as String? ?? '';
  String get customerWhatsapp => profiles?['whatsapp_number'] as String? ?? '';
  double get paidAmount => amountPaid ?? 0;
  String get description => invoicePeriod;
  String get notes => '';
}
