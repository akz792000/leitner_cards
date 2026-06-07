import 'dart:math';

import 'package:get/get.dart';
import 'package:leitner_cards/enums/group_code.dart';
import 'package:leitner_cards/util/date_time_util.dart';

import '../entity/card_entity.dart';
import '../repository/card_repository.dart';
import '../util/list_util.dart';

/// Business logic for the Leitner spaced-repetition algorithm.
///
/// The core rule: level 0 cards are always included.  For level N ≥ 1, a card
/// must sit in the current level for 2^(N-1) daily sessions before it surfaces.
/// [subLevel] tracks how many sessions have elapsed; when it reaches the
/// maximum it is added to the result set and both level and subLevel are reset
/// by [LeitnerScreen] on thumb-up/thumb-down.
class CardService {
  final CardRepository _cardRepository = Get.find<CardRepository>();

  /// Returns cards due today according to the Leitner schedule, ordered by
  /// level ascending and then by [CardEntity.order] within each level.
  ///
  /// Side-effect: increments [subLevel] (and persists) for cards that have a
  /// day's gap but haven't reached their sub-level ceiling yet.
  List<CardEntity> findAllBasedOnLeitner(GroupCode groupCode) {
    final elements = _cardRepository.findAllByGroupCode(groupCode).cast<CardEntity>();

    // Group cards by level
    final Map<int, List<CardEntity>> groupedByLevel = {};
    for (final element in elements) {
      groupedByLevel[element.level] = groupedByLevel[element.level] ?? [];
      groupedByLevel[element.level]!.add(element);
    }

    // Sort keys ascending (lowest level first)
    final sortedKeys = ListUtil.sortAsc(groupedByLevel.keys.toList());

    final List<CardEntity> result = [];

    for (final key in sortedKeys) {
      final List<CardEntity> items = groupedByLevel[key]!;
      final List<CardEntity> addedItems = [];

      if (key == CardEntity.initLevel) {
        addedItems.addAll(items);
      } else {
        final int maxSubLevelCount = pow(2, key - 1).toInt();

        /**
          * For each card that has aged at least one full day since last modification:
          * - If subLevel hasn't reached the ceiling, increment it and defer the card.
          * - Once subLevel hits the ceiling, include the card in today's study set.
          */
        for (final item in items) {
          if (DateTimeUtil.daysToNowWithoutTime(item.modified) >= 1) {
            if (item.subLevel < maxSubLevelCount) {
              item.subLevel++;
              item.modified = DateTimeUtil.now();
              _cardRepository.merge(item);
            } else {
              addedItems.add(item);
            }
          }
        }
      }

      // Order items by `order` field
      addedItems.sort((a, b) => a.order.compareTo(b.order));
      result.addAll(addedItems);
    }

    return result;
  }
}
