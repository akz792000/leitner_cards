import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../entity/CardEntity.dart';
import '../enums/GroupCode.dart';
import '../repository/CardRepository.dart';
import '../util/DateTimeUtil.dart';

class SyncService {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final _client = Supabase.instance.client;

  /// Saves a card to both Hive and Supabase.
  /// If Supabase fails → rolls back Hive. All or nothing.
  Future<void> saveCard(CardEntity card) async {
    final existing = _cardRepository.findById(card.id);
    await _cardRepository.merge(card);
    try {
      await pushCard(card);
    } catch (e) {
      // Rollback Hive
      if (existing == null) {
        await _cardRepository.remove(card);
      } else {
        await _cardRepository.merge(existing);
      }
      rethrow;
    }
  }

  /// Removes a card from both Hive and Supabase.
  /// If Supabase fails → rolls back Hive. All or nothing.
  Future<void> removeCard(CardEntity card) async {
    await _cardRepository.remove(card);
    try {
      await deleteCard(card.id);
    } catch (e) {
      await _cardRepository.merge(card); // Rollback Hive
      rethrow;
    }
  }

  /// Removes multiple cards from both Hive and Supabase.
  /// If Supabase fails → rolls back Hive. All or nothing.
  Future<void> removeCards(List<CardEntity> cards) async {
    if (cards.isEmpty) return;
    await _cardRepository.removeList(cards);
    try {
      await deleteCards(cards.map((c) => c.id).toList());
    } catch (e) {
      // Rollback Hive
      for (final card in cards) {
        await _cardRepository.merge(card);
      }
      rethrow;
    }
  }

  /// Upserts a card's content to Supabase `cards` table.
  Future<void> pushCard(CardEntity card) async {
    await _client.from('cards').upsert({
      'id': card.id,
      'fa': card.fa,
      'en': card.en,
      'de': card.de,
      'description': card.desc,
      'group_code': card.groupCode.index,
      'modified': card.modified.toUtc().toIso8601String(),
    });
  }

  /// Deletes a single card from Supabase (progress cascades).
  Future<void> deleteCard(int id) async {
    await _client.from('cards').delete().eq('id', id);
  }

  /// Deletes multiple cards from Supabase (progress cascades).
  Future<void> deleteCards(List<int> ids) async {
    if (ids.isEmpty) return;
    await _client.from('cards').delete().inFilter('id', ids);
  }

  /// Called on app startup — bidirectional sync of content and progress.
  Future<void> syncOnStartup(void Function(String) onStatus) async {
    try {
      onStatus('Syncing card content...');
      await _syncCardContent();

      onStatus('Syncing progress...');
      await _syncProgress();
    } catch (e) {
      debugPrint('Sync error: $e');
    }
  }

  /// Pulls card content from Supabase. Updates local only if remote is newer.
  /// Always preserves local progress (level, subLevel, order).
  Future<void> _syncCardContent() async {
    final rows = await _client.from('cards').select();

    for (final row in rows) {
      final remoteModified = DateTime.parse(row['modified']).toUtc();
      final existing = _cardRepository.findById(row['id'] as int);

      if (existing == null || remoteModified.isAfter(existing.modified.toUtc())) {
        await _cardRepository.merge(CardEntity(
          id: row['id'] as int,
          created: existing?.created ?? DateTimeUtil.now(),
          modified: tz.TZDateTime.from(remoteModified, tz.local),
          level: existing?.level ?? CardEntity.initLevel,
          subLevel: existing?.subLevel ?? CardEntity.initSubLevel,
          order: existing?.order ?? 0,
          fa: row['fa'] ?? '',
          en: row['en'] ?? '',
          de: row['de'] ?? '',
          desc: row['description'] ?? '',
          groupCode: GroupCode.values[row['group_code'] ?? 0],
        ));
      }
    }
  }

  /// Bidirectional progress sync:
  ///   - Remote newer → update local
  ///   - Local newer  → push to remote (catches offline changes)
  Future<void> _syncProgress() async {
    final rows = await _client.from('progress').select();

    final remoteMap = <int, Map<String, dynamic>>{
      for (final row in rows) row['card_id'] as int: row,
    };

    // Pull: apply remote progress that is newer than local
    for (final row in rows) {
      final cardId = row['card_id'] as int;
      final remoteModified = DateTime.parse(row['modified']).toUtc();
      final existing = _cardRepository.findById(cardId);

      if (existing != null && remoteModified.isAfter(existing.modified.toUtc())) {
        existing.level = row['level'] as int;
        existing.subLevel = row['sub_level'] as int;
        existing.order = row['order'] as int;
        existing.modified = tz.TZDateTime.from(remoteModified, tz.local);
        await _cardRepository.merge(existing);
      }
    }

    // Push: send local progress that is newer than remote (or not yet on remote)
    final allCards = _cardRepository.findAll().cast<CardEntity>();

    for (final card in allCards) {
      final remoteRow = remoteMap[card.id];
      final shouldPush = remoteRow == null ||
          card.modified.toUtc().isAfter(DateTime.parse(remoteRow['modified']).toUtc());

      if (shouldPush) {
        await pushProgress(card);
      }
    }
  }

  /// Silently pushes a single card's progress after a level change.
  Future<void> pushProgress(CardEntity card) async {
    try {
      await _client.from('progress').upsert({
        'card_id': card.id,
        'level': card.level,
        'sub_level': card.subLevel,
        'order': card.order,
        'modified': card.modified.toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Push progress error: $e');
    }
  }
}
