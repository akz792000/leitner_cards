// GENERATED CODE - DO NOT MODIFY BY HAND
//
// ⚠️  MANUALLY PATCHED: typeId uses HiveTypeIds.cardId by name instead of a
// literal int.  Re-running build_runner will overwrite this patch — re-apply
// manually if regeneration is ever needed.

part of 'card_entity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CardEntityAdapter extends TypeAdapter<CardEntity> {
  @override
  final int typeId = HiveTypeIds.cardId;

  @override
  CardEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CardEntity(
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

      // fa
      fa: (fields[6] ?? "") as String,

      // en
      en: (fields[7] ?? "") as String,

      // de
      de: (fields[8] ?? "") as String,

      // desc
      desc: (fields[9] ?? "") as String,

      // groupCode
      groupCode: GroupCode.values[fields[10] ?? GroupCode.english.index],
    );
  }

  @override
  void write(BinaryWriter writer, CardEntity obj) {
    writer
      ..writeByte(11)

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

      // fa
      ..writeByte(6)
      ..write(obj.fa)

      // en
      ..writeByte(7)
      ..write(obj.en)

      // de
      ..writeByte(8)
      ..write(obj.de)

      // desc
      ..writeByte(9)
      ..write(obj.desc)

      // groupCode
      ..writeByte(10)
      ..write(obj.groupCode.index);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
