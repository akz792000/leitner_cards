import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;

import 'hive_type_ids.dart';

part 'deck_entity.g.dart';

/// Hive entity representing a user-created flashcard deck.
///
/// Each deck has a source and target language, a display name,
/// and optional visual customisation (icon code point and color).
///
/// [groupCode] is always set at creation to 'SOURCELANG_TARGETLANG'
/// (e.g. "FA_EN"). Legacy decks seeded from [GroupCode] use the same format.
///
/// ⚠️ deck_entity.g.dart is maintained manually — do NOT run build_runner.
@HiveType(typeId: HiveTypeIds.deckId)
class DeckEntity {
  @HiveField(0)
  String id; // UUID string

  @HiveField(1)
  String name; // display name, e.g. "Farsi → English"

  @HiveField(2)
  String sourceLang; // ISO 639-1 code, e.g. "fa", "en"

  @HiveField(3)
  String targetLang; // ISO 639-1 code, e.g. "en", "de"

  @HiveField(4)
  int iconCodePoint; // Material icon code point (default: Icons.style)

  @HiveField(5)
  int colorValue; // Color as 32-bit ARGB int

  @HiveField(6)
  tz.TZDateTime createdAt;

  @HiveField(7)
  tz.TZDateTime modifiedAt;

  @HiveField(8)
  String groupCode; // e.g. "FA_EN", "EN_DE" — set at creation for all decks.

  @HiveField(9)
  int sortOrder; // manual ordering on home screen (lower = higher)

  DeckEntity({
    required this.id,
    required this.name,
    required this.sourceLang,
    required this.targetLang,
    this.iconCodePoint = 0xe06d, // Icons.style
    this.colorValue = 0xFF1565C0, // blue
    required this.createdAt,
    required this.modifiedAt,
    this.groupCode = '',
    this.sortOrder = 0,
  });
}
