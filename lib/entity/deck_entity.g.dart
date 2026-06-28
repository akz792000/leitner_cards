// GENERATED CODE - DO NOT MODIFY BY HAND
// ⚠️ Manually maintained — do NOT run build_runner.

part of 'deck_entity.dart';

class DeckEntityAdapter extends TypeAdapter<DeckEntity> {
  @override
  final int typeId = HiveTypeIds.deckId;

  @override
  DeckEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeckEntity(
      id: (fields[0] ?? '') as String,
      name: (fields[1] ?? '') as String,
      sourceLang: (fields[2] ?? '') as String,
      targetLang: (fields[3] ?? '') as String,
      iconCodePoint: (fields[4] ?? 0xe06d) as int,
      colorValue: (fields[5] ?? 0xFF1565C0) as int,
      createdAt: fields[6] != null
          ? tz.TZDateTime.from(fields[6], tz.local)
          : tz.TZDateTime.now(tz.local),
      modifiedAt: fields[7] != null
          ? tz.TZDateTime.from(fields[7], tz.local)
          : tz.TZDateTime.now(tz.local),
      groupCode: (fields[8] ?? '') as String,
      sortOrder: (fields[9] ?? 0) as int,
    );
  }

  @override
  void write(BinaryWriter writer, DeckEntity obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.sourceLang)
      ..writeByte(3)
      ..write(obj.targetLang)
      ..writeByte(4)
      ..write(obj.iconCodePoint)
      ..writeByte(5)
      ..write(obj.colorValue)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.modifiedAt)
      ..writeByte(8)
      ..write(obj.groupCode)
      ..writeByte(9)
      ..write(obj.sortOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeckEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
