import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../entity/card_entity.dart';
import '../entity/visual_card_entity.dart';
import '../enums/group_code.dart';
import '../repository/card_repository.dart';
import '../repository/visual_card_repository.dart';
import '../util/date_time_util.dart';

/// Handles all card data persistence and startup synchronisation.
///
/// The app is fully offline; content (cards) is downloaded from a public
/// GitHub repository (akz792000/Dictionary) and stored in Hive. Supabase is
/// not used. [syncOnStartup] fetches en_fa.json, de_en.json, and vi_en.json on
/// every launch — existing progress fields (level, subLevel, order, modified)
/// are preserved; only changed content fields trigger a Hive write.
class SyncService {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final VisualCardRepository _visualCardRepository = Get.find<VisualCardRepository>();

  static const String _baseUrl =
      'https://raw.githubusercontent.com/akz792000/Dictionary/main';

  static const List<String> _cardSources = [
    '$_baseUrl/en_fa.json',
    '$_baseUrl/de_en.json',
  ];
  static const String _visualSource = '$_baseUrl/vi_en.json';

  /// Saves a card to Hive.
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

  /// Called on app startup — fetches latest cards from GitHub and updates Hive.
  /// Preserves existing progress. Skips silently if offline.
  Future<void> syncOnStartup(void Function(String) onStatus) async {
    // Language cards
    for (final url in _cardSources) {
      try {
        onStatus('Downloading cards...');
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) continue;
        final List<dynamic> rows = json.decode(response.body);
        onStatus('Saving ${rows.length} cards...');
        for (final row in rows) {
          await _persistCard(row as Map<String, dynamic>);
        }
      } catch (_) {
        // Offline or fetch failed — skip silently
      }
    }

    // Visual cards
    try {
      onStatus('Downloading visual cards...');
      final response = await http.get(Uri.parse(_visualSource));
      if (response.statusCode == 200) {
        final List<dynamic> rows = json.decode(response.body);
        onStatus('Saving ${rows.length} visual cards...');
        for (final row in rows) {
          await _persistVisualCard(row as Map<String, dynamic>);
        }
      }
    } catch (_) {
      // Offline or fetch failed — skip silently
    }
  }

  Future<void> _persistCard(Map<String, dynamic> element) async {
    final id = element['id'] as int? ?? 0;
    final existing = _cardRepository.findById(id);

    final entity = CardEntity(
      id: id,
      created: existing?.created ?? DateTimeUtil.now(),
      modified: existing?.modified ?? DateTimeUtil.now(),
      level: existing?.level ?? CardEntity.initLevel,
      subLevel: existing?.subLevel ?? CardEntity.initSubLevel,
      order: existing?.order ?? 0,
      fa: element['fa'] ?? '',
      en: element['en'] ?? '',
      de: element['de'] ?? '',
      desc: element['desc'] ?? '',
      groupCode: GroupCode.values[element['groupCode'] ?? GroupCode.english.index],
    );

    final contentChanged = existing == null ||
        existing.fa != entity.fa ||
        existing.en != entity.en ||
        existing.de != entity.de ||
        existing.desc != entity.desc;

    if (contentChanged) {
      await _cardRepository.merge(entity);
    }
  }

  Future<void> _persistVisualCard(Map<String, dynamic> element) async {
    final id = element['id'] as int? ?? 0;
    final existing = _visualCardRepository.findById(id);

    final entity = VisualCardEntity(
      id: id,
      created: existing?.created ?? DateTimeUtil.now(),
      modified: existing?.modified ?? DateTimeUtil.now(),
      level: existing?.level ?? VisualCardEntity.initLevel,
      subLevel: existing?.subLevel ?? VisualCardEntity.initSubLevel,
      order: existing?.order ?? 0,
      image: element['image'] ?? '',
      en: element['en'] ?? '',
      de: element['de'] ?? '',
    );

    final contentChanged = existing == null ||
        existing.image != entity.image ||
        existing.en != entity.en ||
        existing.de != entity.de;

    if (contentChanged) {
      await _visualCardRepository.merge(entity);
    }
  }
}
