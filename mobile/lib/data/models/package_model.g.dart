// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'package_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PackageModelAdapter extends TypeAdapter<PackageModel> {
  @override
  final int typeId = 2;

  @override
  PackageModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PackageModel(
      id: fields[0] as int,
      packageName: fields[1] as String,
      price: fields[2] as double,
      speedMbps: fields[3] as int?,
      description: fields[4] as String?,
      createdAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PackageModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.packageName)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.speedMbps)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PackageModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
