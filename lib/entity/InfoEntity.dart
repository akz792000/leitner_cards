import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:leitner_cards/enums/GroupCode.dart';

import 'HiveTypeIds.dart';

part 'InfoEntity.g.dart';

@HiveType(typeId: HiveTypeIds.INFO_ID)
class InfoEntity {
  @HiveField(0)
  int id;

  @HiveField(1)
  tz.TZDateTime created;

  @HiveField(2)
  tz.TZDateTime modified;

  @HiveField(3)
  GroupCode groupCode;

  @HiveField(4)
  String key;

  @HiveField(5)
  String value;

  InfoEntity({
    required this.id,
    required this.created,
    required this.modified,
    required this.groupCode,
    required this.key,
    required this.value,
  });
}
