import 'dart:math';

import 'package:get/get.dart';
import 'package:leitner_cards/util/date_time_util.dart';

import '../entity/visual_card_entity.dart';
import '../repository/visual_card_repository.dart';
import '../util/list_util.dart';

/// Business logic for the visual (image-based) Leitner deck.
///
/// Mirrors CardService but operates on VisualCardEntity.
/// One shared deck — no groupCode separation needed since each card
/// already contains both EN and DE descriptions.
class VisualCardService {
  final VisualCardRepository _repository = Get.find<VisualCardRepository>();

  /// Returns visual cards due for study today, ordered by Leitner algorithm.
  ///
  /// Algorithm (same as CardService):
  /// - Level 0 cards always appear (new cards).
  /// - Higher-level cards appear only after enough days have passed.
  /// - Cards that haven't waited long enough increment subLevel and are skipped.
  /// - Due cards are sorted by [order] (ascending) within each level.
  List<VisualCardEntity> findAllBasedOnLeitner() {
    final elements = _repository.findAll();

    // Group cards by their current Leitner level
    final Map<int, List<VisualCardEntity>> groupedByLevel = {};
    for (final card in elements) {
      groupedByLevel[card.level] = groupedByLevel[card.level] ?? [];
      groupedByLevel[card.level]!.add(card);
    }

    final sortedKeys = ListUtil.sortAsc(groupedByLevel.keys.toList());
    final List<VisualCardEntity> result = [];

    for (final key in sortedKeys) {
      final List<VisualCardEntity> items = groupedByLevel[key]!;
      final List<VisualCardEntity> addedItems = [];

      if (key == VisualCardEntity.initLevel) {
        // Level 0: always due — add all new cards
        addedItems.addAll(items);
      } else {
        // Level N: due every 2^(N-1) days
        // subLevel tracks partial waits: if not yet at maxSubLevel, increment and skip
        final int maxSubLevelCount = pow(2, key - 1).toInt();
        for (final item in items) {
          if (DateTimeUtil.daysToNowWithoutTime(item.modified) >= 1) {
            if (item.subLevel < maxSubLevelCount) {
              // Not ready yet — advance sub-counter and persist
              item.subLevel++;
              item.modified = DateTimeUtil.now();
              _repository.merge(item);
            } else {
              // Waited long enough — card is due today
              addedItems.add(item);
            }
          }
        }
      }

      // Stable sort by order so cards appear in consistent sequence
      addedItems.sort((a, b) => a.order.compareTo(b.order));
      result.addAll(addedItems);
    }

    return result;
  }
}
