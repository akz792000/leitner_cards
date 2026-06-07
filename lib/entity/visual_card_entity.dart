import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;

import 'hive_type_ids.dart';

part 'visual_card_entity.g.dart';

@HiveType(typeId: HiveTypeIds.visualCardId)
class VisualCardEntity {
  static const int initLevel = 0;
  static const int initSubLevel = 1;

  @HiveField(0)
  int id;

  @HiveField(1)
  tz.TZDateTime created;

  @HiveField(2)
  tz.TZDateTime modified;

  @HiveField(3)
  int level;

  @HiveField(4)
  int subLevel;

  @HiveField(5)
  int order;

  @HiveField(6)
  String image; // filename, e.g. "20001.png"

  @HiveField(7)
  String en; // English description shown after image reveal

  @HiveField(8)
  String de; // German description shown after image reveal

  VisualCardEntity({
    required this.id,
    required this.created,
    required this.modified,
    required this.level,
    required this.subLevel,
    required this.order,
    required this.image,
    required this.en,
    this.de = '',
  });
}
