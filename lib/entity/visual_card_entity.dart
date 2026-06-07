import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;

import 'hive_type_ids.dart';

part 'visual_card_entity.g.dart';

/// Hive entity for visual (image-based) flashcards.
///
/// Each card has one image and bilingual descriptions (EN + DE).
/// No groupCode — the card is bilingual by design; one deck covers both languages.
///
/// ⚠️ visual_card_entity.g.dart is maintained manually — do NOT run build_runner.
/// Field indices must stay stable. New fields must be appended at the end.
@HiveType(typeId: HiveTypeIds.visualCardId)
class VisualCardEntity {
  /// Level 0 = new card, not yet studied.
  static const int initLevel = 0;

  /// subLevel resets to 1 each time the level changes.
  static const int initSubLevel = 1;

  @HiveField(0)
  int id; // seconds-epoch (DateTime.millisecondsSinceEpoch ~/ 1000) — max 0xFFFFFFFF

  @HiveField(1)
  tz.TZDateTime created; // when the card was first downloaded

  @HiveField(2)
  tz.TZDateTime modified; // updated on every level/subLevel change (drives Leitner schedule)

  @HiveField(3)
  int level; // Leitner box (0 = new, higher = better known)

  @HiveField(4)
  int subLevel; // counts study sessions within a level; resets on level change

  @HiveField(5)
  int order; // incremented each time the card is shown — used for stable sort

  @HiveField(6)
  String image; // PNG filename, e.g. "20001.png" — fetched from Dictionary/images/

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
    this.de = '', // optional — defaults to empty if not in JSON
  });
}
