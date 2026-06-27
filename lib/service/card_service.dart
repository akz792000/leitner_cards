import 'dart:math';

import 'package:get/get.dart';

import '../entity/card_entity.dart';
import '../entity/progress_entity.dart';
import '../enums/group_code.dart';
import '../repository/card_repository.dart';
import '../repository/progress_repository.dart';
import '../util/date_time_util.dart';
import '../util/list_util.dart';

/// Business logic for language-card Leitner scheduling.
///
/// Joins [CardEntity] (content) with [ProgressEntity] (level/schedule)
/// at query time. The two are linked by cardId.
class CardService {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final ProgressRepository _progressRepository = Get.find<ProgressRepository>();

  /// Returns cards due for study today for the given [groupCode], ordered by
  /// Leitner algorithm (level 0 first, then by subLevel gating).
  ///
  /// Returns a list of (CardEntity, ProgressEntity) pairs.
  List<(CardEntity, ProgressEntity)> findAllBasedOnLeitner(
      GroupCode groupCode) {
    return findAllBasedOnLeitnerByCode(groupCode.code);
  }

  /// Same as [findAllBasedOnLeitner] but accepts a raw groupCode string.
  List<(CardEntity, ProgressEntity)> findAllBasedOnLeitnerByCode(String code) {
    final cards = _cardRepository.findAllByCode(code);

    // Build a map of cardId → ProgressEntity (create default if missing)
    final progressMap = <int, ProgressEntity>{};
    for (final card in cards) {
      progressMap[card.id] = _progressRepository.findOrCreate(card.id);
    }

    // Group by level
    final Map<int, List<CardEntity>> groupedByLevel = {};
    for (final card in cards) {
      final level = progressMap[card.id]!.level;
      groupedByLevel[level] = groupedByLevel[level] ?? [];
      groupedByLevel[level]!.add(card);
    }

    final sortedKeys = ListUtil.sortDesc(groupedByLevel.keys.toList());
    final List<(CardEntity, ProgressEntity)> result = [];

    for (final key in sortedKeys) {
      final items = groupedByLevel[key]!;
      final List<(CardEntity, ProgressEntity)> addedItems = [];

      if (key == ProgressEntity.initLevel) {
        // Level 0: always due
        for (final card in items) {
          addedItems.add((card, progressMap[card.id]!));
        }
      } else {
        final int maxSubLevelCount = pow(2, key - 1).toInt();
        for (final card in items) {
          final progress = progressMap[card.id]!;
          if (DateTimeUtil.daysToNowWithoutTime(progress.modified) >= 1) {
            if (progress.subLevel < maxSubLevelCount) {
              // Not ready yet — advance sub-counter and persist
              progress.subLevel++;
              progress.modified = DateTimeUtil.now();
              _progressRepository.merge(progress);
            } else {
              addedItems.add((card, progress));
            }
          }
        }
      }

      // Stable sort by order within each level
      addedItems.sort((a, b) => a.$2.order.compareTo(b.$2.order));
      result.addAll(addedItems);
    }

    return result;
  }
}
