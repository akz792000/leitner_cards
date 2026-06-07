// GENERATED CODE - DO NOT MODIFY BY HAND
// ⚠️ Manually maintained — do NOT run build_runner.

part of 'progress_entity.dart';

class ProgressEntityAdapter extends TypeAdapter<ProgressEntity> {
  @override
  final int typeId = HiveTypeIds.progressId;

  @override
  ProgressEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProgressEntity(
      cardId: fields[0] as int,
      level: (fields[1] ?? 0) as int,
      subLevel: (fields[2] ?? 0) as int,
      order: (fields[3] ?? 0) as int,
      created: fields[4] != null
          ? tz.TZDateTime.from(fields[4], tz.local)
          : tz.TZDateTime.now(tz.local),
      modified: fields[5] != null
          ? tz.TZDateTime.from(fields[5], tz.local)
          : tz.TZDateTime.now(tz.local),
    );
  }

  @override
  void write(BinaryWriter writer, ProgressEntity obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.cardId)
      ..writeByte(1)
      ..write(obj.level)
      ..writeByte(2)
      ..write(obj.subLevel)
      ..writeByte(3)
      ..write(obj.order)
      ..writeByte(4)
      ..write(obj.created)
      ..writeByte(5)
      ..write(obj.modified);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
