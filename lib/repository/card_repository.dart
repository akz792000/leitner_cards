import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:leitner_cards/enums/group_code.dart';
import 'package:leitner_cards/util/date_time_util.dart';

import '../entity/card_entity.dart';
import '../util/list_util.dart';

/// Hive persistence layer for [CardEntity].
///
/// All reads are synchronous (Hive in-memory box); writes are async.
/// Use [SyncService] for writes from the UI so rollback is handled correctly.
class CardRepository {
  static const String boxId = "card";

  Box<CardEntity> get _box => Hive.box<CardEntity>(boxId);

  ValueListenable<Box<CardEntity>> listenable() => _box.listenable();

  /// Upserts by [card.id]: adds if id == 0, otherwise overwrites the existing key.
  Future<int> merge(CardEntity card) async {
    if (card.id == 0) {
      card.id = await _box.add(card);
    }
    await _box.put(card.id, card);
    return card.id;
  }

  Future<void> remove(CardEntity card) async => await _box.delete(card.id);

  Future<void> removeAll() async => await _box.deleteAll(_box.keys);

  Future<void> removeList(List<CardEntity> cards) async {
    final futures = cards.map((card) => _box.delete(card.id));
    await Future.wait(futures);
  }

  CardEntity? findById(int id) => _box.get(id);

  List findAll() => _box.values.toList();

  List<CardEntity> findAllByGroupCode(GroupCode groupCode) =>
      _box.values.where((c) => c.groupCode == groupCode).toList();

  List<CardEntity> findAllByLevelAndGroupCode(int level, GroupCode groupCode) =>
      _box.values.where((c) => c.level == level && c.groupCode == groupCode).toList();

  /// Returns cards that are due for review based on the Leitner schedule.
  ///
  /// Level 1 is always eligible. For level N ≥ 2 the card is eligible when
  /// it was created at least 2^(N-1) days ago.
  List<CardEntity> findAllByDateDifference() => _box.values
      .where((c) => c.level == 1 || DateTimeUtil.daysToNow(c.created) >= pow(2, c.level - 1))
      .toList();

  /// Returns a level → card-count map sorted descending by level (highest first).
  Map<int, int> findAllLevelBasedByGroupCode(GroupCode groupCode) {
    final elements = findAllByGroupCode(groupCode);

    final groupLevel = <int, int>{};
    for (final card in elements) {
      groupLevel[card.level] = (groupLevel[card.level] ?? 0) + 1;
    }

    final sortedKeys = ListUtil.sortDesc(groupLevel.keys.toList());

    return {for (final key in sortedKeys) key: groupLevel[key]!};
  }
}
