import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../entity/card_entity.dart';
import '../enums/group_code.dart';
import '../repository/card_repository.dart';
import '../util/date_time_util.dart';

class SyncService {
  final CardRepository _cardRepository = Get.find<CardRepository>();

  static const String _baseUrl =
      'https://raw.githubusercontent.com/akz792000/Dictionary/main';

  static const List<Map<String, dynamic>> _sources = [
    {'url': '$_baseUrl/en_fa.json'},
    {'url': '$_baseUrl/de_en.json'},
  ];

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
    for (final source in _sources) {
      try {
        onStatus('Downloading cards...');
        final response = await http.get(Uri.parse(source['url'] as String));
        if (response.statusCode != 200) continue;

        final List<dynamic> rows = json.decode(response.body);
        onStatus('Saving ${rows.length} cards...');
        for (final row in rows) {
          await _persistCard(row as Map<String, dynamic>);
        }
      } catch (_) {
        // Offline or fetch failed — skip silently, use cached Hive data
      }
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
}
