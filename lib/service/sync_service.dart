import 'package:get/get.dart';

import '../entity/card_entity.dart';
import '../repository/card_repository.dart';

/// Handles all-or-nothing card persistence to Hive.
///
/// Card content is downloaded on demand via [DownloadScreen] — never
/// automatically on startup. This service only manages writes that must
/// keep Hive consistent (save / remove).
class SyncService {
  final CardRepository _cardRepository = Get.find<CardRepository>();

  /// Saves a card to Hive (content only — progress unchanged).
  Future<void> saveCard(CardEntity card) async {
    await _cardRepository.merge(card);
  }

  /// Removes a card from Hive.
  Future<void> removeCard(CardEntity card) async {
    await _cardRepository.remove(card);
  }

  /// Removes multiple cards from Hive.
  Future<void> removeCards(List<CardEntity> cards) async {
    if (cards.isEmpty) return;
    await _cardRepository.removeList(cards);
  }
}
