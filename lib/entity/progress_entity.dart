import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;

import 'hive_type_ids.dart';

part 'progress_entity.g.dart';

/// Hive entity storing Leitner progress for a single card.
///
/// Separated from [CardEntity] so progress can be exported/imported
/// independently — enabling cross-device sync without re-downloading cards.
///
/// Key: [cardId] matches [CardEntity.id].
///
/// ⚠️ progress_entity.g.dart is maintained manually — do NOT run build_runner.
@HiveType(typeId: HiveTypeIds.progressId)
class ProgressEntity {
  static const int initLevel = 0;
  static const int initSubLevel = 1;

  @HiveField(0)
  int cardId; // foreign key → CardEntity.id

  @HiveField(1)
  int level; // Leitner box (0 = new/reset, higher = better known)

  @HiveField(2)
  int subLevel; // sessions within current level; resets on level change

  @HiveField(3)
  int order; // incremented each visit — used for stable sort within a level

  @HiveField(4)
  tz.TZDateTime created; // when this progress record was first created

  @HiveField(5)
  tz.TZDateTime modified; // when level/subLevel last changed — drives schedule

  ProgressEntity({
    required this.cardId,
    required this.level,
    required this.subLevel,
    required this.order,
    required this.created,
    required this.modified,
  });
}
