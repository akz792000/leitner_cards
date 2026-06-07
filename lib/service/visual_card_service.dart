import 'dart:math';

import 'package:get/get.dart';
import 'package:leitner_cards/util/date_time_util.dart';

import '../entity/visual_card_entity.dart';
import '../repository/visual_card_repository.dart';
import '../util/list_util.dart';

class VisualCardService {
  final VisualCardRepository _repository = Get.find<VisualCardRepository>();

  List<VisualCardEntity> findAllBasedOnLeitner() {
    final elements = _repository.findAll();

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
        addedItems.addAll(items);
      } else {
        final int maxSubLevelCount = pow(2, key - 1).toInt();
        for (final item in items) {
          if (DateTimeUtil.daysToNowWithoutTime(item.modified) >= 1) {
            if (item.subLevel < maxSubLevelCount) {
              item.subLevel++;
              item.modified = DateTimeUtil.now();
              _repository.merge(item);
            } else {
              addedItems.add(item);
            }
          }
        }
      }

      addedItems.sort((a, b) => a.order.compareTo(b.order));
      result.addAll(addedItems);
    }

    return result;
  }
}
