import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;

import '../enums/group_code.dart';
import 'hive_type_ids.dart';

part 'card_entity.g.dart';

/// Unified Hive entity for all flashcard types.
///
/// Covers three deck types via [groupCode]:
/// - FA_EN: English ↔ Farsi language cards (en + fa fields)
/// - EN_DE: Deutsch ↔ English language cards (en + de fields)
/// - VISUAL: Image-based bilingual cards (image + en + de fields)
///
/// Progress fields (level, subLevel, order) live in [ProgressEntity], not here.
///
/// ⚠️ card_entity.g.dart is maintained manually — do NOT run build_runner.
@HiveType(typeId: HiveTypeIds.cardId)
class CardEntity {
  @HiveField(0)
  int id; // seconds-epoch (DateTime.millisecondsSinceEpoch ~/ 1000)

  @HiveField(1)
  tz.TZDateTime created; // when card was first downloaded

  @HiveField(2)
  tz.TZDateTime modified; // when card content last changed (from JSON update)

  @HiveField(3)
  String groupCode; // stored as string: "FA_EN", "EN_DE", "VISUAL"

  @HiveField(4)
  String image; // PNG filename for VISUAL cards; empty for language cards

  @HiveField(5)
  String en; // English text (all decks)

  @HiveField(6)
  String fa; // Farsi text (FA_EN only)

  @HiveField(7)
  String de; // German text (EN_DE and VISUAL)

  @HiveField(8)
  String desc; // optional notes/description

  CardEntity({
    required this.id,
    required this.created,
    required this.modified,
    required this.groupCode,
    this.image = '',
    this.en = '',
    this.fa = '',
    this.de = '',
    this.desc = '',
  });

  /// Convenience getter for typed enum access.
  GroupCode get group => GroupCode.fromCode(groupCode);
}
