import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../entity/deck_entity.dart';

/// Hive CRUD for the "deck" box.
///
/// Each deck is stored with its [DeckEntity.id] (UUID) as the Hive key.
/// Legacy decks seeded from GroupCode have a non-empty [DeckEntity.groupCode].
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

  /// Find a deck by its legacy groupCode (e.g. "FA_EN").
  DeckEntity? findByGroupCode(String groupCode) {
    if (groupCode.isEmpty) return null;
    final matches = _box.values.where((d) => d.groupCode == groupCode);
    return matches.isEmpty ? null : matches.first;
  }

  /// All decks, ordered by creation date (newest first).
  List<DeckEntity> findAll() {
    final decks = _box.values.toList();
    decks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return decks;
  }

  /// Number of decks.
  int get count => _box.length;

  /// Whether any decks exist.
  bool get isEmpty => _box.isEmpty;
}
