import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:uuid/uuid.dart';

import '../entity/card_entity.dart';
import '../entity/deck_entity.dart';
import '../entity/progress_entity.dart';
import '../repository/card_repository.dart';
import '../repository/deck_repository.dart';
import '../repository/progress_repository.dart';
import '../util/date_time_util.dart';
import 'drive_service.dart';

/// Result of a sync (download or upload) operation for a single deck.
class DriveSyncResult {
  final String deckName;
  final int uploaded;
  final int downloaded;
  final int updated;
  final int inserted;
  final int progressSynced;
  final String? error;

  const DriveSyncResult({
    required this.deckName,
    this.uploaded = 0,
    this.downloaded = 0,
    this.updated = 0,
    this.inserted = 0,
    this.progressSynced = 0,
    this.error,
  });

  bool get hasError => error != null;
}

/// Orchestrates sync between local Hive DB and Google Drive.
///
/// Upload: serialises local cards + progress → Drive JSON files.
/// Download: fetches Drive JSON files → diffs with local → merges.
class DriveSyncService {
  final CardRepository _cardRepo = Get.find<CardRepository>();
  final ProgressRepository _progressRepo = Get.find<ProgressRepository>();
  final DriveService _driveService = Get.find<DriveService>();

  /// Unified code for both local card queries and Drive folder naming.
  /// Uses groupCode if set, otherwise derives SOURCELANG_TARGETLANG.
  String deckCode(DeckEntity deck) {
    if (deck.groupCode.isNotEmpty) return deck.groupCode;
    final src = deck.sourceLang.toUpperCase();
    final tgt = deck.targetLang.toUpperCase();
    return '${src}_$tgt';
  }

  /// Alias kept for backward compatibility with callers.
  String cardCode(DeckEntity deck) => deckCode(deck);
  String driveFolderName(DeckEntity deck) => deckCode(deck);

  // ──────────────────────────────── UPLOAD ────────────────────────────────

  /// Uploads deck metadata + cards + progress to Google Drive.
  Future<DriveSyncResult> uploadDeck(DeckEntity deck) async {
    try {
      final code = cardCode(deck);
      final folderId =
          await _driveService.ensureDeckFolder(driveFolderName(deck));

      // Deck metadata
      await _driveService.uploadJson(folderId, 'deck.json', _deckToJson(deck));

      final cards = _cardRepo.findAllByCode(code);
      final cardList = cards.map(_cardToJson).toList();
      await _driveService.uploadJson(folderId, 'cards.json', cardList);

      final progressList = cards.map((c) {
        final p = _progressRepo.findOrCreate(c.id);
        return _progressToJson(p);
      }).toList();
      await _driveService.uploadJson(folderId, 'progress.json', progressList);

      debugPrint(
          'DriveSyncService: uploaded ${cards.length} cards for ${deck.name}');
      return DriveSyncResult(
        deckName: deck.name,
        uploaded: cards.length,
        progressSynced: progressList.length,
      );
    } catch (e) {
      return DriveSyncResult(deckName: deck.name, error: e.toString());
    }
  }

  // ──────────────────────────────── DOWNLOAD ─────────────────────────────

  /// Downloads deck metadata + cards + progress from Google Drive and merges.
  ///
  /// Cards: changed content → update + reset progress to 0. New → insert.
  /// Progress: if local card exists and content matches, adopt the higher
  /// level (cloud wins only if cloud level > local level).
  Future<DriveSyncResult> downloadDeck(DeckEntity deck,
      {bool resetProgress = false}) async {
    try {
      final code = cardCode(deck);
      final folderId =
          await _driveService.ensureDeckFolder(driveFolderName(deck));

      // ── Deck metadata ──
      await _applyDeckMetadata(deck, folderId);

      // ── Cards ──
      final rawCards = await _driveService.downloadJson(folderId, 'cards.json');
      if (rawCards == null) {
        return DriveSyncResult(
            deckName: deck.name, error: 'No cards.json found on Drive');
      }
      final remoteCards = (rawCards as List).cast<Map<String, dynamic>>();

      int updated = 0;
      int inserted = 0;
      final now = DateTimeUtil.now();

      for (final rc in remoteCards) {
        final id = rc['id'] as int? ?? 0;
        if (id == 0) continue;
        final existing = _cardRepo.findById(id);

        if (existing != null && existing.groupCode == code) {
          final changed = existing.en != (rc['en'] ?? '') ||
              existing.fa != (rc['fa'] ?? '') ||
              existing.de != (rc['de'] ?? '') ||
              existing.image != (rc['image'] ?? '') ||
              existing.desc != (rc['desc'] ?? '');

          if (changed || resetProgress) {
            await _cardRepo.merge(CardEntity(
              id: id,
              created: existing.created,
              modified: now,
              groupCode: code,
              image: rc['image'] ?? '',
              en: rc['en'] ?? '',
              fa: rc['fa'] ?? '',
              de: rc['de'] ?? '',
              desc: rc['desc'] ?? '',
            ));
            final p = _progressRepo.findOrCreate(id);
            p.level = 0;
            p.subLevel = 1;
            p.modified = now;
            await _progressRepo.merge(p);
            updated++;
          }
        } else if (existing == null) {
          await _cardRepo.merge(CardEntity(
            id: id,
            created: now,
            modified: now,
            groupCode: code,
            image: rc['image'] ?? '',
            en: rc['en'] ?? '',
            fa: rc['fa'] ?? '',
            de: rc['de'] ?? '',
            desc: rc['desc'] ?? '',
          ));
          inserted++;
        }
      }

      // ── Progress ──
      int progressSynced = 0;
      final rawProgress =
          await _driveService.downloadJson(folderId, 'progress.json');
      if (rawProgress != null) {
        final remoteProgress =
            (rawProgress as List).cast<Map<String, dynamic>>();
        for (final rp in remoteProgress) {
          final cardId = rp['cardId'] as int? ?? 0;
          final card = _cardRepo.findById(cardId);
          if (card == null || card.groupCode != code) continue;

          final local = _progressRepo.findOrCreate(cardId);
          final remoteLevel = rp['level'] as int? ?? 0;

          if (remoteLevel > local.level) {
            local.level = remoteLevel;
            local.subLevel = rp['subLevel'] as int? ?? 1;
            local.order = rp['order'] as int? ?? local.order;
            local.modified = now;
            await _progressRepo.merge(local);
            progressSynced++;
          }
        }
      }

      debugPrint('DriveSyncService: downloaded ${deck.name} '
          '— $updated updated, $inserted inserted, $progressSynced progress');
      return DriveSyncResult(
        deckName: deck.name,
        downloaded: remoteCards.length,
        updated: updated,
        inserted: inserted,
        progressSynced: progressSynced,
      );
    } catch (e) {
      return DriveSyncResult(deckName: deck.name, error: e.toString());
    }
  }

  // ─────────────────────── DOWNLOAD FROM CLOUD FOLDER ─────────────────────

  /// Downloads cards from a Drive folder that has no local deck yet.
  /// Creates a new local deck and imports all cards + progress.
  Future<DriveSyncResult> downloadCloudFolder(String folderName) async {
    try {
      final folderId = await _driveService.ensureDeckFolder(folderName);

      final rawCards = await _driveService.downloadJson(folderId, 'cards.json');
      if (rawCards == null) {
        return DriveSyncResult(
            deckName: folderName, error: 'No cards.json found on Drive');
      }
      final remoteCards = (rawCards as List).cast<Map<String, dynamic>>();
      if (remoteCards.isEmpty) {
        return DriveSyncResult(
            deckName: folderName, error: 'cards.json is empty');
      }

      // Try to read deck metadata from Drive
      final rawDeck = await _driveService.downloadJson(folderId, 'deck.json');
      final deckMeta = rawDeck is Map<String, dynamic> ? rawDeck : null;

      // Derive source/target lang from metadata or folder name
      final parts = folderName.split('_');
      final srcLang = deckMeta?['sourceLang'] as String? ??
          (parts.isNotEmpty ? parts[0].toLowerCase() : '');
      final tgtLang = deckMeta?['targetLang'] as String? ??
          (parts.length > 1 ? parts[1].toLowerCase() : '');

      // Create a new local deck with cloud metadata
      final now = DateTimeUtil.now();
      final deckId = const Uuid().v4();
      final deck = DeckEntity(
        id: deckId,
        name: deckMeta?['name'] as String? ?? folderName,
        sourceLang: srcLang,
        targetLang: tgtLang,
        groupCode: folderName,
        iconCodePoint: deckMeta?['iconCodePoint'] as int? ?? 0xe06d,
        colorValue: deckMeta?['colorValue'] as int? ?? 0xFF1565C0,
        sortOrder: deckMeta?['sortOrder'] as int? ?? 0,
        createdAt: now,
        modifiedAt: now,
      );
      await Get.find<DeckRepository>().merge(deck);

      // Import cards
      int inserted = 0;
      for (final rc in remoteCards) {
        final id = rc['id'] as int? ?? 0;
        if (id == 0) continue;
        await _cardRepo.merge(CardEntity(
          id: id,
          created: now,
          modified: now,
          groupCode: folderName,
          image: rc['image'] ?? '',
          en: rc['en'] ?? '',
          fa: rc['fa'] ?? '',
          de: rc['de'] ?? '',
          desc: rc['desc'] ?? '',
        ));
        inserted++;
      }

      // Import progress
      int progressSynced = 0;
      final rawProgress =
          await _driveService.downloadJson(folderId, 'progress.json');
      if (rawProgress != null) {
        final remoteProgress =
            (rawProgress as List).cast<Map<String, dynamic>>();
        for (final rp in remoteProgress) {
          final cardId = rp['cardId'] as int? ?? 0;
          final card = _cardRepo.findById(cardId);
          if (card == null) continue;
          final local = _progressRepo.findOrCreate(cardId);
          local.level = rp['level'] as int? ?? 0;
          local.subLevel = rp['subLevel'] as int? ?? 1;
          local.order = rp['order'] as int? ?? local.order;
          local.modified = now;
          await _progressRepo.merge(local);
          progressSynced++;
        }
      }

      debugPrint('DriveSyncService: imported $folderName — $inserted cards');
      return DriveSyncResult(
        deckName: folderName,
        downloaded: remoteCards.length,
        inserted: inserted,
        progressSynced: progressSynced,
      );
    } catch (e) {
      return DriveSyncResult(deckName: folderName, error: e.toString());
    }
  }

  // ──────────────────────────── RESET PROGRESS ───────────────────────────

  /// Resets all progress for [deck] to level 0.
  Future<int> resetProgress(DeckEntity deck) async {
    final code = cardCode(deck);
    final cards = _cardRepo.findAllByCode(code);
    final now = DateTimeUtil.now();
    int count = 0;
    for (final card in cards) {
      final p = _progressRepo.findOrCreate(card.id);
      if (p.level != 0) {
        p.level = 0;
        p.subLevel = 1;
        p.modified = now;
        await _progressRepo.merge(p);
        count++;
      }
    }
    return count;
  }

  // ──────────────────────────── DECK METADATA ─────────────────────────────

  /// Applies deck metadata from Drive (deck.json) to the local deck.
  Future<void> _applyDeckMetadata(DeckEntity deck, String folderId) async {
    final raw = await _driveService.downloadJson(folderId, 'deck.json');
    if (raw == null || raw is! Map<String, dynamic>) return;

    bool changed = false;
    if (raw['name'] is String && raw['name'] != deck.name) {
      deck.name = raw['name'];
      changed = true;
    }
    if (raw['iconCodePoint'] is int &&
        raw['iconCodePoint'] != deck.iconCodePoint) {
      deck.iconCodePoint = raw['iconCodePoint'];
      changed = true;
    }
    if (raw['colorValue'] is int && raw['colorValue'] != deck.colorValue) {
      deck.colorValue = raw['colorValue'];
      changed = true;
    }
    if (raw['sourceLang'] is String && raw['sourceLang'] != deck.sourceLang) {
      deck.sourceLang = raw['sourceLang'];
      changed = true;
    }
    if (raw['targetLang'] is String && raw['targetLang'] != deck.targetLang) {
      deck.targetLang = raw['targetLang'];
      changed = true;
    }
    if (raw['sortOrder'] is int && raw['sortOrder'] != deck.sortOrder) {
      deck.sortOrder = raw['sortOrder'];
      changed = true;
    }
    if (changed) {
      deck.modifiedAt = DateTimeUtil.now();
      await Get.find<DeckRepository>().merge(deck);
      debugPrint('DriveSyncService: updated deck metadata for ${deck.name}');
    }
  }

  // ──────────────────────────── SERIALISATION ────────────────────────────

  Map<String, dynamic> _deckToJson(DeckEntity d) => _compact({
        'name': d.name,
        'sourceLang': d.sourceLang,
        'targetLang': d.targetLang,
        'groupCode': deckCode(d),
        'iconCodePoint': d.iconCodePoint,
        'colorValue': d.colorValue,
        'sortOrder': d.sortOrder,
      });

  Map<String, dynamic> _cardToJson(CardEntity c) => _compact({
        'id': c.id,
        'en': c.en,
        'fa': c.fa,
        'de': c.de,
        'image': c.image,
        'desc': c.desc,
      });

  Map<String, dynamic> _progressToJson(ProgressEntity p) => _compact({
        'cardId': p.cardId,
        'level': p.level,
        'subLevel': p.subLevel,
        'order': p.order,
      });

  /// Remove entries whose value is null or empty string.
  Map<String, dynamic> _compact(Map<String, dynamic> m) {
    m.removeWhere((_, v) => v == null || v == '');
    return m;
  }
}
