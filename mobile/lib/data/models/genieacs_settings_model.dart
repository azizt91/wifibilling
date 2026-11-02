class GenieAcsSettingsModel {
  final String id;
  final String settingKey;
  final String? settingValue;
  final bool isEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GenieAcsSettingsModel({
    required this.id,
    required this.settingKey,
    this.settingValue,
    required this.isEnabled,
    this.createdAt,
    this.updatedAt,
  });

  factory GenieAcsSettingsModel.fromJson(Map<String, dynamic> json) {
    return GenieAcsSettingsModel(
      id: json['id'] as String,
      settingKey: json['setting_key'] as String,
      settingValue: json['setting_value'] as String?,
      isEnabled: json['is_enabled'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'setting_key': settingKey,
      'setting_value': settingValue,
      'is_enabled': isEnabled,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  GenieAcsSettingsModel copyWith({
    String? id,
    String? settingKey,
    String? settingValue,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GenieAcsSettingsModel(
      id: id ?? this.id,
      settingKey: settingKey ?? this.settingKey,
      settingValue: settingValue ?? this.settingValue,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Helper class to manage GenieACS settings as a group
class GenieAcsConfig {
  final bool enabled;
  final String url;
  final String username;
  final String password;

  GenieAcsConfig({
    required this.enabled,
    required this.url,
    required this.username,
    required this.password,
  });

  factory GenieAcsConfig.fromSettings(List<GenieAcsSettingsModel> settings) {
    final settingsMap = {
      for (var s in settings) s.settingKey: s.settingValue ?? ''
    };

    return GenieAcsConfig(
      enabled: settingsMap['genieacs_enabled'] == 'true',
      url: settingsMap['genieacs_url'] ?? '',
      username: settingsMap['genieacs_username'] ?? '',
      password: settingsMap['genieacs_password'] ?? '',
    );
  }

  Map<String, String> toSettingsMap() {
    return {
      'genieacs_enabled': enabled.toString(),
      'genieacs_url': url,
      'genieacs_username': username,
      'genieacs_password': password,
    };
  }
}
