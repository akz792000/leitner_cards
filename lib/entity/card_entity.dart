import 'package:hive/hive.dart';
import 'package:leitner_cards/enums/group_code.dart';
import 'package:timezone/timezone.dart' as tz;

import 'hive_type_ids.dart';

part 'card_entity.g.dart';

/// Persisted flashcard for language study.
///
/// Each card belongs to one [GroupCode] deck (English↔Farsi or Deutsch↔English).
/// The Leitner schedule is driven by [level], [subLevel], and [modified]:
/// - Level 0 cards are always shown.
/// - Level N cards appear every 2^(N-1) days; [subLevel] counts daily sessions
///   within a level and resets to [initSubLevel] whenever the level changes.
/// - [id] uses seconds-epoch (`millisecondsSinceEpoch ~/ 1000`); max 0xFFFFFFFF.
@HiveType(typeId: HiveTypeIds.cardId)
class CardEntity {
  static const int initLevel = 0; // starting level for new / reset cards
  static const int initSubLevel = 1; // sub-level always starts at 1

  @HiveField(0)
  int id; // seconds-epoch identifier, also used as Hive key

  @HiveField(1)
  tz.TZDateTime created; // first time the card was saved locally

  @HiveField(2)
  tz.TZDateTime modified; // updated on every level/sub-level change; drives scheduling

  @HiveField(3)
  int level; // Leitner bucket (0 = new, higher = less frequent review)

  @HiveField(4)
  int subLevel; // session counter within the current level

  @HiveField(5)
  int order; // how many times this card has been shown (used for sorting)

  @HiveField(6)
  String fa; // Farsi translation

  @HiveField(7)
  String en; // English word / phrase

  @HiveField(8)
  String de; // German translation

  @HiveField(9)
  String desc; // optional hint shown in the description sheet

  @HiveField(10)
  GroupCode groupCode;

  /// True when [order] was already incremented this session — prevents double-counting.
  bool orderChanged = false;

  CardEntity(
      {required this.id,
      required this.created,
      required this.modified,
      required this.level,
      required this.subLevel,
      required this.order,
      required this.fa,
      required this.en,
      required this.de,
      required this.desc,
      required this.groupCode});
}
