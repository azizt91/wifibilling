import 'package:hive/hive.dart';
import 'package_model.dart';

part 'profile_model.g.dart';

@HiveType(typeId: 0)
class ProfileModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? idpl;

  @HiveField(2)
  final String? fullName;

  @HiveField(3)
  final String? address;

  @HiveField(4)
  final String? gender;

  @HiveField(5)
  final String? whatsappNumber;

  @HiveField(6)
  final String role;

  @HiveField(7)
  final String? photoUrl;

  @HiveField(8)
  final String? status;

  @HiveField(9)
  final DateTime? installationDate;

  @HiveField(10)
  final String? deviceType;

  @HiveField(11)
  final String? ipStaticPppoe;

  @HiveField(12)
  final DateTime? createdAt;

  @HiveField(13)
  final DateTime? churnDate;

  @HiveField(14)
  final int? packageId;

  @HiveField(15)
  final double? latitude;

  @HiveField(16)
  final double? longitude;

  @HiveField(17)
  final String? email;

  @HiveField(18)
  final PackageModel? package;

  ProfileModel({
    required this.id,
    this.idpl,
    this.fullName,
    this.address,
    this.gender,
    this.whatsappNumber,
    required this.role,
    this.photoUrl,
    this.status,
    this.installationDate,
    this.deviceType,
    this.ipStaticPppoe,
    this.createdAt,
    this.churnDate,
    this.packageId,
    this.latitude,
    this.longitude,
    this.email,
    this.package,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      idpl: json['idpl'] as String?,
      fullName: json['full_name'] as String?,
      address: json['address'] as String?,
      gender: json['gender'] as String?,
      whatsappNumber: json['whatsapp_number'] as String?,
      role: json['role'] as String? ?? 'USER',
      photoUrl: json['photo_url'] as String?,
      status: json['status'] as String?,
      installationDate: json['installation_date'] != null
          ? DateTime.parse(json['installation_date'] as String)
          : null,
      deviceType: json['device_type'] as String?,
      ipStaticPppoe: json['ip_static_pppoe'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      churnDate: json['churn_date'] != null
          ? DateTime.parse(json['churn_date'] as String)
          : null,
      packageId: json['package_id'] as int?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      email: json['email'] as String?,
      package: json['packages'] != null
          ? PackageModel.fromJson(json['packages'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idpl': idpl,
      'full_name': fullName,
      'address': address,
      'gender': gender,
      'whatsapp_number': whatsappNumber,
      'role': role,
      'photo_url': photoUrl,
      'status': status,
      'installation_date': installationDate?.toIso8601String(),
      'device_type': deviceType,
      'ip_static_pppoe': ipStaticPppoe,
      'created_at': createdAt?.toIso8601String(),
      'churn_date': churnDate?.toIso8601String(),
      'package_id': packageId,
      'latitude': latitude,
      'longitude': longitude,
      'email': email,
    };
  }

  ProfileModel copyWith({
    String? id,
    String? idpl,
    String? fullName,
    String? address,
    String? gender,
    String? whatsappNumber,
    String? role,
    String? photoUrl,
    String? status,
    DateTime? installationDate,
    String? deviceType,
    String? ipStaticPppoe,
    DateTime? createdAt,
    DateTime? churnDate,
    int? packageId,
    double? latitude,
    double? longitude,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      idpl: idpl ?? this.idpl,
      fullName: fullName ?? this.fullName,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      installationDate: installationDate ?? this.installationDate,
      deviceType: deviceType ?? this.deviceType,
      ipStaticPppoe: ipStaticPppoe ?? this.ipStaticPppoe,
      createdAt: createdAt ?? this.createdAt,
      churnDate: churnDate ?? this.churnDate,
      packageId: packageId ?? this.packageId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  bool get isAdmin {
    final r = role.toLowerCase().trim();
    return r == 'admin' || r == 'super_admin' || r == 'superadmin' || r == 'tenant_admin';
  }

  bool get isUser {
    final r = role.toLowerCase().trim();
    return r == 'user' || r == 'pelanggan' || r == 'customer' || !isAdmin;
  }

  bool get isActive => status?.toUpperCase() == 'AKTIF';
  
  // Computed properties for compatibility
  String get generatedEmail => '${idpl ?? id}@wifi.id'; // Generated email
  String get phone => whatsappNumber ?? '';
  String get notes => '';
}
