// GENERATED CODE - DO NOT MODIFY BY HAND
// ⚠️ Manually maintained — do NOT run build_runner (would overwrite HiveTypeIds reference).

part of 'card_entity.dart';

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
      id: fields[0] as int,
      created: fields[1] != null
          ? tz.TZDateTime.from(fields[1], tz.local)
          : tz.TZDateTime.now(tz.local),
      modified: fields[2] != null
          ? tz.TZDateTime.from(fields[2], tz.local)
          : tz.TZDateTime.now(tz.local),
      groupCode: (fields[3] ?? GroupCode.faEn.code) as String,
      image: (fields[4] ?? '') as String,
      en: (fields[5] ?? '') as String,
      fa: (fields[6] ?? '') as String,
      de: (fields[7] ?? '') as String,
      desc: (fields[8] ?? '') as String,
    );
  }

  @override
  void write(BinaryWriter writer, CardEntity obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.created)
      ..writeByte(2)
      ..write(obj.modified)
      ..writeByte(3)
      ..write(obj.groupCode)
      ..writeByte(4)
      ..write(obj.image)
      ..writeByte(5)
      ..write(obj.en)
      ..writeByte(6)
      ..write(obj.fa)
      ..writeByte(7)
      ..write(obj.de)
      ..writeByte(8)
      ..write(obj.desc);
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
