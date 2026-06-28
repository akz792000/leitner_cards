import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../entity/deck_entity.dart';

/// Hive CRUD for the "deck" box.
///
/// Each deck is stored with its [DeckEntity.id] (UUID) as the Hive key.
class DeckRepository {
  static const String boxId = 'deck';

  Box<DeckEntity> get _box => Hive.box<DeckEntity>(boxId);

  /// Listenable for reactive UI (ValueListenableBuilder).
  ValueListenable<Box<DeckEntity>> listenable() => _box.listenable();

  /// Insert or update a deck (upsert by id).
  Future<void> merge(DeckEntity deck) async => await _box.put(deck.id, deck);

  /// Delete a deck by id.
  Future<void> remove(String id) async => await _box.delete(id);

  /// Find a deck by id.
  DeckEntity? findById(String id) => _box.get(id);

  /// All decks, ordered by sortOrder (lower first), then creation date.
  List<DeckEntity> findAll() {
    final decks = _box.values.toList();
    decks.sort((a, b) {
      final cmp = a.sortOrder.compareTo(b.sortOrder);
      return cmp != 0 ? cmp : a.createdAt.compareTo(b.createdAt);
    });
    return decks;
  }

  /// Number of decks.
  int get count => _box.length;

  /// Whether any decks exist.
  bool get isEmpty => _box.isEmpty;
}
