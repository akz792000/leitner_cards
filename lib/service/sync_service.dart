import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../entity/card_entity.dart';
import '../entity/progress_entity.dart';
import '../enums/group_code.dart';
import '../repository/card_repository.dart';
import '../repository/progress_repository.dart';
import '../util/date_time_util.dart';

/// Handles all card data persistence and startup synchronisation.
///
/// Cards (content) are downloaded from a public GitHub repository
/// (akz792000/Dictionary) and stored in Hive. When a card's content changes
/// (during sync or manual edit), its progress is reset to level 0 so the
/// card re-enters the Leitner queue from the beginning.
///
/// [syncOnStartup] fetches fa_en.json, en_de.json, and visual.json on
/// every launch — unchanged cards are skipped; changed content fields
/// trigger a Hive write AND a progress reset.
class SyncService {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final ProgressRepository _progressRepository = Get.find<ProgressRepository>();

  static const String _baseUrl =
      'https://raw.githubusercontent.com/akz792000/Dictionary/main';

  static const List<Map<String, String>> _cardSources = [
    {'url': '$_baseUrl/fa_en.json', 'groupCode': 'FA_EN'},
    {'url': '$_baseUrl/en_de.json', 'groupCode': 'EN_DE'},
    {'url': '$_baseUrl/visual.json', 'groupCode': 'VISUAL'},
  ];

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

  /// Called on app startup — fetches latest cards from GitHub and updates Hive.
  /// Preserves existing progress. Skips silently if offline.
  Future<void> syncOnStartup(void Function(String) onStatus) async {
    for (final source in _cardSources) {
      try {
        onStatus('Downloading cards...');
        final response = await http.get(Uri.parse(source['url']!));
        if (response.statusCode != 200) continue;
        final List<dynamic> rows = json.decode(response.body);
        onStatus('Saving ${rows.length} cards...');
        for (final row in rows) {
          await _persistCard(row as Map<String, dynamic>, source['groupCode']!);
        }
      } catch (_) {
        // Offline or fetch failed — skip silently
      }
    }
  }

  Future<void> _persistCard(
      Map<String, dynamic> element, String defaultGroupCode) async {
    final id = element['id'] as int? ?? 0;
    final existing = _cardRepository.findById(id);

    // Prefer groupCode from JSON payload; fall back to the source's default
    final groupCode = (element['groupCode'] as String?) ?? defaultGroupCode;

    final entity = CardEntity(
      id: id,
      created: existing?.created ?? DateTimeUtil.now(),
      modified: existing?.modified ?? DateTimeUtil.now(),
      groupCode: GroupCode.fromCode(groupCode).code,
      image: element['image'] ?? '',
      en: element['en'] ?? '',
      fa: element['fa'] ?? '',
      de: element['de'] ?? '',
      desc: element['desc'] ?? '',
    );

    final contentChanged = existing == null ||
        existing.image != entity.image ||
        existing.en != entity.en ||
        existing.fa != entity.fa ||
        existing.de != entity.de ||
        existing.desc != entity.desc;

    if (contentChanged) {
      await _cardRepository.merge(entity);
      // Content changed → reset progress so the card re-enters the queue from level 0.
      final progress = _progressRepository.findOrCreate(id);
      progress.level = ProgressEntity.initLevel;
      progress.subLevel = ProgressEntity.initSubLevel;
      progress.modified = DateTimeUtil.now();
      await _progressRepository.merge(progress);
    }
  }
}
