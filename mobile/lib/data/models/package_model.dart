import 'package:hive/hive.dart';

part 'package_model.g.dart';

@HiveType(typeId: 2)
class PackageModel extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String packageName;

  @HiveField(2)
  final double price;

  @HiveField(3)
  final int? speedMbps;

  @HiveField(4)
  final String? description;

  @HiveField(5)
  final DateTime? createdAt;

  PackageModel({
    required this.id,
    required this.packageName,
    required this.price,
    this.speedMbps,
    this.description,
    this.createdAt,
  });

  factory PackageModel.fromJson(Map<String, dynamic> json) {
    return PackageModel(
      id: json['id'] as int,
      packageName: json['package_name'] as String,
      price: (json['price'] as num).toDouble(),
      speedMbps: json['speed_mbps'] as int?,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'package_name': packageName,
      'price': price,
      'speed_mbps': speedMbps,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get speedDisplay => speedMbps != null ? '$speedMbps Mbps' : 'N/A';
}
