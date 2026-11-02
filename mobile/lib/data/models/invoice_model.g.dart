// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InvoiceModelAdapter extends TypeAdapter<InvoiceModel> {
  @override
  final int typeId = 1;

  @override
  InvoiceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InvoiceModel(
      id: fields[0] as String,
      customerId: fields[1] as String,
      packageId: fields[2] as int?,
      invoicePeriod: fields[3] as String,
      amount: fields[4] as double,
      status: fields[5] as String,
      dueDate: fields[6] as DateTime?,
      paidAt: fields[7] as DateTime?,
      createdAt: fields[8] as DateTime?,
      totalDue: fields[9] as double?,
      amountPaid: fields[10] as double?,
      paymentHistory: (fields[11] as List?)
          ?.map((dynamic e) => (e as Map).cast<String, dynamic>())
          ?.toList(),
      lastPaymentDate: fields[12] as DateTime?,
      paymentMethod: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.customerId)
      ..writeByte(2)
      ..write(obj.packageId)
      ..writeByte(3)
      ..write(obj.invoicePeriod)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.dueDate)
      ..writeByte(7)
      ..write(obj.paidAt)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.totalDue)
      ..writeByte(10)
      ..write(obj.amountPaid)
      ..writeByte(11)
      ..write(obj.paymentHistory)
      ..writeByte(12)
      ..write(obj.lastPaymentDate)
      ..writeByte(13)
      ..write(obj.paymentMethod);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
