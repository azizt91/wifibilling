class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String? recipientRole;
  final String? recipientUserId;
  final String? url;
  final DateTime? createdAt;
  final String? type;
  final Map<String, dynamic>? data;
  final DateTime? updatedAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.recipientRole,
    this.recipientUserId,
    this.url,
    this.createdAt,
    this.type,
    this.data,
    this.updatedAt,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      recipientRole: json['recipient_role'] as String?,
      recipientUserId: json['recipient_user_id'] as String?,
      url: json['url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      type: json['type'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'recipient_role': recipientRole,
      'recipient_user_id': recipientUserId,
      'url': url,
      'created_at': createdAt?.toIso8601String(),
      'type': type,
      'data': data,
      'updated_at': updatedAt?.toIso8601String(),
      'is_read': isRead,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? recipientRole,
    String? recipientUserId,
    String? url,
    DateTime? createdAt,
    String? type,
    Map<String, dynamic>? data,
    DateTime? updatedAt,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      recipientRole: recipientRole ?? this.recipientRole,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      url: url ?? this.url,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      data: data ?? this.data,
      updatedAt: updatedAt ?? this.updatedAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
