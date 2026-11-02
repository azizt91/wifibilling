class AppSettingsModel {
  final String? id;
  final String appName;
  final String? whatsappNumber;
  final String? supportEmail;
  final String? officeAddress;
  final String? offlinePaymentName;
  final String? offlinePaymentAddress;
  final String? qrisImageUrl;
  final bool showQris;
  final String? genieacsUrl;
  final String? genieacsUsername;
  final String? genieacsPassword;
  final DateTime? updatedAt;

  AppSettingsModel({
    this.id,
    required this.appName,
    this.whatsappNumber,
    this.supportEmail,
    this.officeAddress,
    this.offlinePaymentName,
    this.offlinePaymentAddress,
    this.qrisImageUrl,
    this.showQris = true,
    this.genieacsUrl,
    this.genieacsUsername,
    this.genieacsPassword,
    this.updatedAt,
  });

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(
      id: json['id']?.toString(),
      appName: json['app_name'] ?? 'WiFi Billing System',
      whatsappNumber: json['whatsapp_number'],
      supportEmail: json['support_email'],
      officeAddress: json['office_address'],
      offlinePaymentName: json['offline_payment_name'],
      offlinePaymentAddress: json['offline_payment_address'],
      qrisImageUrl: json['qris_image_url'],
      showQris: json['show_qris'] ?? true,
      genieacsUrl: json['genieacs_url'],
      genieacsUsername: json['genieacs_username'],
      genieacsPassword: json['genieacs_password'],
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'app_name': appName,
      if (whatsappNumber != null) 'whatsapp_number': whatsappNumber,
      if (supportEmail != null) 'support_email': supportEmail,
      if (officeAddress != null) 'office_address': officeAddress,
      if (offlinePaymentName != null) 'offline_payment_name': offlinePaymentName,
      if (offlinePaymentAddress != null) 'offline_payment_address': offlinePaymentAddress,
      if (qrisImageUrl != null) 'qris_image_url': qrisImageUrl,
      'show_qris': showQris,
      if (genieacsUrl != null) 'genieacs_url': genieacsUrl,
      if (genieacsUsername != null) 'genieacs_username': genieacsUsername,
      if (genieacsPassword != null) 'genieacs_password': genieacsPassword,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  AppSettingsModel copyWith({
    String? id,
    String? appName,
    String? whatsappNumber,
    String? supportEmail,
    String? officeAddress,
    String? offlinePaymentName,
    String? offlinePaymentAddress,
    String? qrisImageUrl,
    bool? showQris,
    String? genieacsUrl,
    String? genieacsUsername,
    String? genieacsPassword,
    DateTime? updatedAt,
  }) {
    return AppSettingsModel(
      id: id ?? this.id,
      appName: appName ?? this.appName,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      supportEmail: supportEmail ?? this.supportEmail,
      officeAddress: officeAddress ?? this.officeAddress,
      offlinePaymentName: offlinePaymentName ?? this.offlinePaymentName,
      offlinePaymentAddress: offlinePaymentAddress ?? this.offlinePaymentAddress,
      qrisImageUrl: qrisImageUrl ?? this.qrisImageUrl,
      showQris: showQris ?? this.showQris,
      genieacsUrl: genieacsUrl ?? this.genieacsUrl,
      genieacsUsername: genieacsUsername ?? this.genieacsUsername,
      genieacsPassword: genieacsPassword ?? this.genieacsPassword,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class WhatsAppSettingsModel {
  final String? id;
  final String settingKey;
  final String settingValue;

  WhatsAppSettingsModel({
    this.id,
    required this.settingKey,
    required this.settingValue,
  });

  factory WhatsAppSettingsModel.fromJson(Map<String, dynamic> json) {
    return WhatsAppSettingsModel(
      id: json['id']?.toString(),
      settingKey: json['setting_key'] ?? '',
      settingValue: json['setting_value'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'setting_key': settingKey,
      'setting_value': settingValue,
    };
  }
}
