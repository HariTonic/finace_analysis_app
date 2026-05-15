// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ImportRecordAdapter extends TypeAdapter<ImportRecord> {
  @override
  final int typeId = 3;

  @override
  ImportRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ImportRecord(
      importDate: fields[0] as DateTime,
      transactionCount: fields[1] as int,
      source: fields[2] as String,
      importedTransactionIds: (fields[3] as List).cast<String>(),
      duplicatesSkipped: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ImportRecord obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.importDate)
      ..writeByte(1)
      ..write(obj.transactionCount)
      ..writeByte(2)
      ..write(obj.source)
      ..writeByte(3)
      ..write(obj.importedTransactionIds)
      ..writeByte(4)
      ..write(obj.duplicatesSkipped);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
