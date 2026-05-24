// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'InfoEntity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InfoEntityAdapter extends TypeAdapter<InfoEntity> {
  @override
  final int typeId = HiveTypeIds.INFO_ID;

  @override
  InfoEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InfoEntity(
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

      // groupCode
      groupCode: GroupCode.values[fields[3] ?? GroupCode.english.index],

      // key
      key: (fields[4] ?? "") as String,

      // value
      value: (fields[5] ?? "") as String,
    );
  }

  @override
  void write(BinaryWriter writer, InfoEntity obj) {
    writer
      ..writeByte(6)

      // id
      ..writeByte(0)
      ..write(obj.id)

      // created
      ..writeByte(1)
      ..write(obj.created)

      // modified
      ..writeByte(2)
      ..write(obj.modified)

      // val
      ..writeByte(3)
      ..write(obj.groupCode.index)

      // key
      ..writeByte(4)
      ..write(obj.key)

      // value
      ..writeByte(5)
      ..write(obj.value);
    ;
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InfoEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
