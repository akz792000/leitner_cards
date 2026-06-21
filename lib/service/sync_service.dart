import 'package:get/get.dart';

import '../entity/card_entity.dart';
import '../repository/card_repository.dart';
import '../repository/progress_repository.dart';

/// Handles all-or-nothing card persistence to Hive.
///
/// Card content is downloaded on demand via [DownloadScreen] — never
/// automatically on startup. This service only manages writes that must
/// keep Hive consistent (save / remove).
class SyncService {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final ProgressRepository _progressRepository = Get.find<ProgressRepository>();

  /// Saves a card to Hive (content only — progress unchanged).
  Future<void> saveCard(CardEntity card) async {
    await _cardRepository.merge(card);
  }

  /// Removes a card from Hive.
  /// If [withProgress] is true, also deletes the card's progress record.
  Future<void> removeCard(CardEntity card, {bool withProgress = false}) async {
    await _cardRepository.remove(card);
    if (withProgress) await _progressRepository.removeByCardId(card.id);
  }

  /// Removes multiple cards from Hive.
  /// If [withProgress] is true, also deletes their progress records.
  Future<void> removeCards(List<CardEntity> cards,
      {bool withProgress = false}) async {
    if (cards.isEmpty) return;
    await _cardRepository.removeList(cards);
    if (withProgress) {
      for (final card in cards) {
        await _progressRepository.removeByCardId(card.id);
      }
    }
  }
}
