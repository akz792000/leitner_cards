import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:leitner_cards/util/date_time_util.dart';

import '../entity/visual_card_entity.dart';

class VisualCardRepository {
  static const String boxId = 'visual_card';

  Box<VisualCardEntity> get _box => Hive.box<VisualCardEntity>(boxId);

  ValueListenable<Box<VisualCardEntity>> listenable() => _box.listenable();

  Future<void> merge(VisualCardEntity card) async => await _box.put(card.id, card);

  Future<void> remove(VisualCardEntity card) async => await _box.delete(card.id);

  Future<void> removeAll() async => await _box.deleteAll(_box.keys);

  VisualCardEntity? findById(int id) => _box.get(id);

  List<VisualCardEntity> findAll() => _box.values.toList();

  List<VisualCardEntity> findAllByDateDifference() => _box.values
      .where((c) => c.level == 1 || DateTimeUtil.daysToNow(c.created) >= pow(2, c.level - 1))
      .toList();

  Map<int, int> findAllLevelBased() {
    final groupLevel = <int, int>{};
    for (final card in _box.values) {
      groupLevel[card.level] = (groupLevel[card.level] ?? 0) + 1;
    }
    return groupLevel;
  }
}
