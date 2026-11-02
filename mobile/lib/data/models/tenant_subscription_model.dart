class TenantSubscriptionModel {
  final String tenantId;
  final String name;
  final String slug;
  final String subscriptionStatus;
  final DateTime? subscriptionExpiresAt;
  final String planName;
  final int priceMonthly;

  const TenantSubscriptionModel({
    required this.tenantId,
    required this.name,
    required this.slug,
    required this.subscriptionStatus,
    this.subscriptionExpiresAt,
    required this.planName,
    required this.priceMonthly,
  });

  bool get isSuspended => subscriptionStatus.toLowerCase() == 'suspended';

  int get daysOverdue {
    if (subscriptionExpiresAt == null) return -999;
    final now = DateTime.now();
    final dNow = DateTime(now.year, now.month, now.day);
    final dExp = DateTime(
      subscriptionExpiresAt!.year,
      subscriptionExpiresAt!.month,
      subscriptionExpiresAt!.day,
    );
    return dNow.difference(dExp).inDays;
  }

  /// Kunci total jika disuspend admin ATAU telah melewati hari ke-4 jatuh tempo (daysOverdue >= 4)
  bool get isHardLocked {
    if (subscriptionExpiresAt == null && subscriptionStatus.toLowerCase() == 'active') {
      return false;
    }
    if (isSuspended) return true;
    if (subscriptionExpiresAt != null && daysOverdue >= 4) return true;
    return false;
  }

  /// Masa tenggang (Grace Period): Hari H (0) s/d Hari ke-3
  bool get isGracePeriod {
    if (isHardLocked) return false;
    if (subscriptionExpiresAt == null) return false;
    return daysOverdue >= 0 && daysOverdue <= 3;
  }

  /// Sisa hari masa tenggang sebelum terkunci total pada hari ke-4
  int get daysRemainingGrace {
    if (!isGracePeriod) return 0;
    final sisa = 4 - daysOverdue;
    return sisa > 0 ? sisa : 0;
  }

  factory TenantSubscriptionModel.fromJson(Map<String, dynamic> json) {
    final plans = json['saas_plans'] as Map<String, dynamic>?;
    final planName = plans?['name'] as String? ?? 'Starter';
    final rawPrice = plans?['price_monthly'];
    int priceMonthly = 10000;
    if (rawPrice != null) {
      if (rawPrice is num) {
        priceMonthly = rawPrice.toInt();
      } else {
        priceMonthly = double.tryParse(rawPrice.toString())?.toInt() ?? 10000;
      }
    }

    return TenantSubscriptionModel(
      tenantId: json['id'] as String,
      name: json['name'] as String? ?? 'Tenant',
      slug: json['slug'] as String? ?? '',
      subscriptionStatus: json['subscription_status'] as String? ?? 'trial',
      subscriptionExpiresAt: json['subscription_expires_at'] != null
          ? DateTime.tryParse(json['subscription_expires_at'].toString())
          : null,
      planName: planName,
      priceMonthly: priceMonthly,
    );
  }
}

