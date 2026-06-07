import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../entity/card_entity.dart';
import '../enums/group_code.dart';

/// Hive CRUD for the "card" box — content only, no progress data.
///
/// All card types (FA_EN, EN_DE, VISUAL) live in this single box,
/// distinguished by [CardEntity.groupCode].
class CardRepository {
  static const String boxId = 'card';

  Box<CardEntity> get _box => Hive.box<CardEntity>(boxId);

  /// Listenable for reactive UI (ValueListenableBuilder).
  ValueListenable<Box<CardEntity>> listenable() => _box.listenable();

  /// Insert or update a card (upsert by id).
  Future<void> merge(CardEntity card) async => await _box.put(card.id, card);

  Future<void> remove(CardEntity card) async => await _box.delete(card.id);

  Future<void> removeAll() async => await _box.deleteAll(_box.keys);

  Future<void> removeList(List<CardEntity> cards) async {
    final futures = cards.map((card) => _box.delete(card.id));
    await Future.wait(futures);
  }

  CardEntity? findById(int id) => _box.get(id);

  List<CardEntity> findAll() => _box.values.toList();

  /// All cards for a specific deck.
  List<CardEntity> findAllByGroupCode(GroupCode groupCode) =>
      _box.values.where((c) => c.groupCode == groupCode.code).toList();

  /// Card count per groupCode — used by stats screen.
  Map<String, int> findAllGroupCodeBased() {
    final result = <String, int>{};
    for (final card in _box.values) {
      result[card.groupCode] = (result[card.groupCode] ?? 0) + 1;
    }
    return result;
  }
}
