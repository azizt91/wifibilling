// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProfileModelAdapter extends TypeAdapter<ProfileModel> {
  @override
  final int typeId = 0;

  @override
  ProfileModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProfileModel(
      id: fields[0] as String,
      idpl: fields[1] as String?,
      fullName: fields[2] as String?,
      address: fields[3] as String?,
      gender: fields[4] as String?,
      whatsappNumber: fields[5] as String?,
      role: fields[6] as String,
      photoUrl: fields[7] as String?,
      status: fields[8] as String?,
      installationDate: fields[9] as DateTime?,
      deviceType: fields[10] as String?,
      ipStaticPppoe: fields[11] as String?,
      createdAt: fields[12] as DateTime?,
      churnDate: fields[13] as DateTime?,
      packageId: fields[14] as int?,
      latitude: fields[15] as double?,
      longitude: fields[16] as double?,
      email: fields[17] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProfileModel obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.idpl)
      ..writeByte(2)
      ..write(obj.fullName)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.gender)
      ..writeByte(5)
      ..write(obj.whatsappNumber)
      ..writeByte(6)
      ..write(obj.role)
      ..writeByte(7)
      ..write(obj.photoUrl)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.installationDate)
      ..writeByte(10)
      ..write(obj.deviceType)
      ..writeByte(11)
      ..write(obj.ipStaticPppoe)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.churnDate)
      ..writeByte(14)
      ..write(obj.packageId)
      ..writeByte(15)
      ..write(obj.latitude)
      ..writeByte(16)
      ..write(obj.longitude)
      ..writeByte(17)
      ..write(obj.email);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
