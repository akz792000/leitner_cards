/// Central registry of Hive typeIds.
/// Never reuse a retired typeId — append new ones only.
class HiveTypeIds {
  static const int cardId = 1; // CardEntity — all card types
  static const int progressId = 2; // ProgressEntity — progress/level data
}
