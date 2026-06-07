/// Central registry for Hive type adapter IDs.
///
/// Each [HiveType] typeId must be unique across the app and must never change
/// after data has been written — changing a typeId corrupts existing boxes.
/// The generated adapter in card_entity.g.dart references [cardId] by name
/// rather than a literal int, so do NOT re-run build_runner without manually
/// re-applying that patch.
class HiveTypeIds {
  static const int cardId = 1; // CardEntity adapter
  static const int visualCardId = 2; // VisualCardEntity adapter
}
