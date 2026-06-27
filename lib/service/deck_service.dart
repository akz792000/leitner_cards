import 'package:get/get.dart';

import '../entity/deck_entity.dart';
import '../enums/group_code.dart';
import '../repository/card_repository.dart';
import '../repository/deck_repository.dart';
import '../repository/progress_repository.dart';

/// Domain operations on decks that span multiple repositories.
///
/// Keeps the view layer free of multi-repo orchestration logic.
class DeckService {
  final DeckRepository _deckRepo = Get.find<DeckRepository>();
  final CardRepository _cardRepo = Get.find<CardRepository>();
  final ProgressRepository _progressRepo = Get.find<ProgressRepository>();

  /// Deletes a deck together with all its cards and their progress records.
  Future<void> deleteDeckWithData(DeckEntity deck) async {
    if (deck.groupCode.isNotEmpty) {
      final gc = GroupCode.fromCode(deck.groupCode);
      final cards = _cardRepo.findAllByGroupCode(gc);
      final cardIds = cards.map((c) => c.id).toList();
      await _progressRepo.removeByCardIds(cardIds);
      await _cardRepo.removeList(cards);
    }
    // Future: handle user-created decks (cards linked by deckId).

    await _deckRepo.remove(deck.id);
  }
}
