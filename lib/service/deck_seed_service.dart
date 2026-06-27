import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../entity/deck_entity.dart';
import '../enums/group_code.dart';
import '../repository/card_repository.dart';
import '../repository/deck_repository.dart';

/// Seeds [DeckEntity] records for existing GroupCode-based decks on first launch.
///
/// Only creates decks for GroupCodes that actually have cards in the card box.
/// This bridges the legacy hardcoded deck model to the new dynamic deck system.
class DeckSeedService {
  static const _uuid = Uuid();

  /// Seed legacy decks if the deck box is empty and cards exist.
  static Future<void> seedIfNeeded() async {
    final deckRepo = Get.find<DeckRepository>();
    final cardRepo = Get.find<CardRepository>();

    // Only seed once — if decks already exist, skip.
    if (!deckRepo.isEmpty) return;

    final cardCounts = cardRepo.findAllGroupCodeBased();
    if (cardCounts.isEmpty) return;

    final now = tz.TZDateTime.now(tz.local);

    // Seed a deck for each GroupCode that has cards.
    for (final gc in GroupCode.values) {
      final count = cardCounts[gc.code] ?? 0;
      if (count == 0) continue;

      final config = _legacyDeckConfig(gc);
      final deck = DeckEntity(
        id: _uuid.v4(),
        name: config.name,
        sourceLang: config.sourceLang,
        targetLang: config.targetLang,
        iconCodePoint: config.iconCodePoint,
        colorValue: config.colorValue,
        createdAt: now,
        modifiedAt: now,
        groupCode: gc.code,
      );
      await deckRepo.merge(deck);
      debugPrint('Seeded deck "${deck.name}" for ${gc.code} ($count cards)');
    }
  }

  static _DeckConfig _legacyDeckConfig(GroupCode gc) {
    switch (gc) {
      case GroupCode.faEn:
        return _DeckConfig(
          name: 'Farsi → English',
          sourceLang: 'fa',
          targetLang: 'en',
          iconCodePoint: Icons.translate.codePoint,
          colorValue: 0xFF1565C0, // blue
        );
      case GroupCode.enDe:
        return _DeckConfig(
          name: 'Deutsch Sentences',
          sourceLang: 'en',
          targetLang: 'de',
          iconCodePoint: Icons.chat_bubble_outline.codePoint,
          colorValue: 0xFFE65100, // orange
        );
      case GroupCode.enDeVerbs:
        return _DeckConfig(
          name: 'Deutsch Verbs',
          sourceLang: 'en',
          targetLang: 'de',
          iconCodePoint: Icons.format_list_bulleted.codePoint,
          colorValue: 0xFFE65100, // orange
        );
      case GroupCode.visual:
        return _DeckConfig(
          name: 'Visual Cards',
          sourceLang: 'en',
          targetLang: 'de',
          iconCodePoint: Icons.image_outlined.codePoint,
          colorValue: 0xFF00695C, // teal
        );
    }
  }
}

class _DeckConfig {
  final String name;
  final String sourceLang;
  final String targetLang;
  final int iconCodePoint;
  final int colorValue;

  const _DeckConfig({
    required this.name,
    required this.sourceLang,
    required this.targetLang,
    required this.iconCodePoint,
    required this.colorValue,
  });
}
