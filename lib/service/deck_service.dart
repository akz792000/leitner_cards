import 'package:get/get.dart';

import '../entity/card_entity.dart';
import '../entity/deck_entity.dart';
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
    // Find cards by groupCode (legacy decks) and by deck.id (user-created decks)
    final codes = <String>{deck.id};
    if (deck.groupCode.isNotEmpty) codes.add(deck.groupCode);

    final cards = <CardEntity>[];
    for (final code in codes) {
      cards.addAll(_cardRepo.findAllByCode(code));
    }

    if (cards.isNotEmpty) {
      final cardIds = cards.map((c) => c.id).toList();
      await _progressRepo.removeByCardIds(cardIds);
      await _cardRepo.removeList(cards);
    }

    await _deckRepo.remove(deck.id);
  }
}
