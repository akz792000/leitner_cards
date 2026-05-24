import 'dart:math';

import 'package:get/get.dart';
import 'package:leitner_cards/enums/GroupCode.dart';
import 'package:leitner_cards/util/DateTimeUtil.dart';

import '../entity/CardEntity.dart';
import '../repository/CardRepository.dart';
import '../util/ListUtil.dart';

class CardService {
  final CardRepository _cardRepository = Get.find<CardRepository>();

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
         * consider each item if exist more then one day discrepancy
         * if it is in the last sub level, it means we have to consider it and
         * if not we have to increase the sub level till to the maximum sub level
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
