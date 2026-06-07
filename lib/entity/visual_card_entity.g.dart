// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visual_card_entity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VisualCardEntityAdapter extends TypeAdapter<VisualCardEntity> {
  @override
  final int typeId = HiveTypeIds.visualCardId;

  @override
  VisualCardEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VisualCardEntity(
      // id
      id: fields[0] as int,

      // created
      created: fields[1] != null
          ? tz.TZDateTime.from(fields[1], tz.local)
          : tz.TZDateTime.now(tz.local),

      // modified
      modified: fields[2] != null
          ? tz.TZDateTime.from(fields[2], tz.local)
          : tz.TZDateTime.now(tz.local),

      // level
      level: (fields[3] ?? 0) as int,

      // subLevel
      subLevel: (fields[4] ?? 0) as int,

      // order
      order: (fields[5] ?? 0) as int,

      // image
      image: (fields[6] ?? '') as String,

      // en
      en: (fields[7] ?? '') as String,

      // de: field 8 in new records (String), field 9 in old records (field 8 was groupCode int)
      de: fields[8] is String ? fields[8] as String : (fields[9] ?? '') as String,
    );
  }

  @override
  void write(BinaryWriter writer, VisualCardEntity obj) {
    writer
      ..writeByte(9)

      // id
      ..writeByte(0)
      ..write(obj.id)

      // created
      ..writeByte(1)
      ..write(obj.created)

      // modified
      ..writeByte(2)
      ..write(obj.modified)

      // level
      ..writeByte(3)
      ..write(obj.level)

      // subLevel
      ..writeByte(4)
      ..write(obj.subLevel)

      // order
      ..writeByte(5)
      ..write(obj.order)

      // image
      ..writeByte(6)
      ..write(obj.image)

      // en
      ..writeByte(7)
      ..write(obj.en)

      // de
      ..writeByte(8)
      ..write(obj.de);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisualCardEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
