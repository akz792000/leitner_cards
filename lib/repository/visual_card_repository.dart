import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:leitner_cards/util/date_time_util.dart';

import '../entity/visual_card_entity.dart';

/// Hive CRUD for the "visual_card" box.
///
/// All writes go through [merge] — both new inserts and updates use put()
/// keyed on card.id so duplicates are never created.
class VisualCardRepository {
  static const String boxId = 'visual_card';

  Box<VisualCardEntity> get _box => Hive.box<VisualCardEntity>(boxId);

  /// Listenable for reactive UI (ValueListenableBuilder).
  ValueListenable<Box<VisualCardEntity>> listenable() => _box.listenable();

  /// Insert or update a card (upsert by id).
  Future<void> merge(VisualCardEntity card) async => await _box.put(card.id, card);

  Future<void> remove(VisualCardEntity card) async => await _box.delete(card.id);

  /// Wipes the entire visual deck (used by DownloadScreen override toggle).
  Future<void> removeAll() async => await _box.deleteAll(_box.keys);

  VisualCardEntity? findById(int id) => _box.get(id);

  List<VisualCardEntity> findAll() => _box.values.toList();

  /// Cards where enough days have passed since creation based on their level.
  /// Used by stats — not by the Leitner scheduling loop (that lives in the service).
  List<VisualCardEntity> findAllByDateDifference() => _box.values
      .where((c) => c.level == 1 || DateTimeUtil.daysToNow(c.created) >= pow(2, c.level - 1))
      .toList();

  /// Returns a map of level → card count for the stats screen.
  Map<int, int> findAllLevelBased() {
    final groupLevel = <int, int>{};
    for (final card in _box.values) {
      groupLevel[card.level] = (groupLevel[card.level] ?? 0) + 1;
    }
    return groupLevel;
  }
}
