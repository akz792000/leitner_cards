import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:leitner_cards/entity/card_entity.dart';
import 'package:leitner_cards/entity/deck_entity.dart';
import 'package:leitner_cards/enums/group_code.dart';
import '../repository/card_repository.dart';
import '../repository/deck_repository.dart';
import '../repository/progress_repository.dart';
import 'package:leitner_cards/util/date_time_util.dart';

/// Full-screen view for manually downloading card decks from GitHub.
///
/// Smart sync strategy:
///   Pass 1 (all rows)  — existing cards with changed content are updated and
///                         their progress reset to level 0 (correction detected).
///   Pass 2 (last N)    — cards not yet in the local DB are added, but only
///                         the most-recent [_newCardsLimit] items so the level-0
///                         queue never becomes overwhelming.
///   Override toggle    — resets ALL progress for that deck regardless of
///                         content changes (useful for a full resync).
class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final ProgressRepository _progressRepository = Get.find<ProgressRepository>();

  static const String _baseUrl =
      'https://raw.githubusercontent.com/akz792000/Dictionary/main';

  /// GitHub JSON URLs for legacy GroupCode decks.
  static const Map<String, String> _groupCodeUrls = {
    'FA_EN': '$_baseUrl/fa_en.json',
    'EN_DE': '$_baseUrl/en_de.json',
    'EN_DE_VERBS': '$_baseUrl/en_de_verbs.json',
    'VISUAL': '$_baseUrl/visual.json',
  };

  /// Maximum number of NEW (not yet local) cards added per deck per sync.
  int _newCardsLimit = 100;

  /// Built dynamically from DeckRepository — only decks with a sync URL.
  late final List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    final decks = Get.find<DeckRepository>().findAll();
    _items = decks
        .where((d) =>
            d.groupCode.isNotEmpty && _groupCodeUrls.containsKey(d.groupCode))
        .map((d) => <String, dynamic>{
              'deck': d,
              'toggle': false,
              'url': _groupCodeUrls[d.groupCode]!,
              'groupCode': GroupCode.fromCode(d.groupCode),
            })
        .toList();
  }

  bool _loading = false;

  /// Pass 1: update an existing card if its content has changed.
  /// Returns true if the card was updated (triggers progress reset).
  Future<bool> _updateExisting(
      Map<String, dynamic> element, GroupCode groupCode, bool override) async {
    final id = element["id"] as int? ?? 0;
    final existing = _cardRepository.findById(id);
    if (existing == null) return false; // new card — handled in pass 2
    // Ignore cross-deck ID collisions (same epoch ID in a different deck).
    if (existing.groupCode != groupCode.code) return false;

    final contentChanged = existing.image != (element["image"] ?? "") ||
        existing.en != (element["en"] ?? "") ||
        existing.fa != (element["fa"] ?? "") ||
        existing.de != (element["de"] ?? "") ||
        existing.desc != (element["desc"] ?? "");

    if (!contentChanged && !override) return false;

    await _cardRepository.merge(CardEntity(
      id: id,
      created: existing.created,
      modified: DateTimeUtil.now(),
      groupCode: groupCode.code,
      image: element["image"] ?? "",
      en: element["en"] ?? "",
      fa: element["fa"] ?? "",
      de: element["de"] ?? "",
      desc: element["desc"] ?? "",
    ));

    // Content correction or override → restart learning from level 0.
    final progress = _progressRepository.findOrCreate(id);
    progress.level = 0;
    progress.subLevel = 1;
    progress.modified = DateTimeUtil.now();
    await _progressRepository.merge(progress);
    return true;
  }

  /// Pass 2: add a card that does not yet exist locally.
  Future<bool> _addNew(
      Map<String, dynamic> element, GroupCode groupCode) async {
    final id = element["id"] as int? ?? 0;
    if (_cardRepository.findById(id) != null) return false;

    await _cardRepository.merge(CardEntity(
      id: id,
      created: DateTimeUtil.now(),
      modified: DateTimeUtil.now(),
      groupCode: groupCode.code,
      image: element["image"] ?? "",
      en: element["en"] ?? "",
      fa: element["fa"] ?? "",
      de: element["de"] ?? "",
      desc: element["desc"] ?? "",
    ));
    return true;
  }

  /// Downloads one deck and returns `(updated, inserted, remaining, total)` counts.
  ///
  /// Pass 1 scans ALL remote rows and updates any existing card whose content
  /// has changed (resetting its progress to level 0).
  /// Pass 2 iterates ALL rows, skips cards already in the local DB, and inserts
  /// up to [_newCardsLimit] new ones — then counts how many are still pending
  /// for the next sync. This means each sync continues exactly where the last
  /// one left off without relying on a fragile positional offset.
  Future<({int updated, int inserted, int remaining, int total})> _download(
      Map<String, dynamic> item) async {
    final response = await http.get(Uri.parse(item['url'] as String));
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to download ${item['name']}: HTTP ${response.statusCode}');
    }
    final List<dynamic> rows = json.decode(response.body);
    final GroupCode groupCode = item['groupCode'] as GroupCode;
    final bool override = item['toggle'] as bool;

    int updated = 0;
    int inserted = 0;
    int remaining = 0;

    // Pass 1 — corrections: scan ALL rows, update content if changed.
    for (final row in rows) {
      if (await _updateExisting(
          row as Map<String, dynamic>, groupCode, override)) {
        updated++;
      }
    }

    // Pass 2 — new cards: iterate ALL rows in order, skip already-local IDs,
    // insert up to _newCardsLimit new ones. Count remaining for next sync.
    bool limitReached = false;
    for (final rawRow in rows) {
      final row = rawRow as Map<String, dynamic>;
      final id = row['id'] as int? ?? 0;
      if (_cardRepository.findById(id) != null) continue; // already local
      if (limitReached) {
        remaining++; // count cards deferred to next sync
        continue;
      }
      if (await _addNew(row, groupCode)) {
        inserted++;
        if (inserted >= _newCardsLimit) limitReached = true;
      }
    }

    return (
      updated: updated,
      inserted: inserted,
      remaining: remaining,
      total: rows.length
    );
  }

  Future<void> _downloadAll() async {
    setState(() => _loading = true);
    final List<Map<String, dynamic>> results = [];
    try {
      for (final item in _items) {
        final r = await _download(item);
        final deck = item['deck'] as DeckEntity;
        results.add({
          'name': deck.name,
          'color': Color(deck.colorValue),
          'updated': r.updated,
          'inserted': r.inserted,
          'remaining': r.remaining,
          'total': r.total,
        });
      }
      if (mounted) _showResults(results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showResults(List<Map<String, dynamic>> results) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Sync Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: results.map((r) {
            final color = r['color'] as Color;
            final updated = r['updated'] as int;
            final inserted = r['inserted'] as int;
            final remaining = r['remaining'] as int;
            final total = r['total'] as int;
            final String statusLine;
            if (updated == 0 && inserted == 0) {
              statusLine = remaining > 0
                  ? '$remaining pending  ($total total)'
                  : 'Up to date  ($total total)';
            } else {
              final parts = <String>[];
              if (updated > 0) parts.add('↑ $updated updated');
              if (inserted > 0) parts.add('+$inserted inserted');
              if (remaining > 0) parts.add('$remaining pending');
              statusLine = '${parts.join('  ')}  ($total total)';
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['name'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                          statusLine,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context), // close dialog only
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Cards'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            color: cs.surfaceContainerHighest,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.cloud_download_outlined,
                      color: Colors.blue.shade600, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Smart Sync from GitHub',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text(
                        'Corrections to existing cards are always applied (level reset to 0). '
                        'Only the last N new cards are added to avoid flooding level 0.',
                        style:
                            TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Scrollable middle: new-cards control + deck list
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Max new cards control
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Text('Max new cards per sync:',
                            style: TextStyle(
                                fontSize: 13, color: cs.onSurfaceVariant)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _newCardsLimit > 10
                              ? () => setState(() => _newCardsLimit =
                                  (_newCardsLimit - 10).clamp(10, 500))
                              : null,
                        ),
                        SizedBox(
                          width: 44,
                          child: Text(
                            '$_newCardsLimit',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _newCardsLimit < 500
                              ? () => setState(() => _newCardsLimit =
                                  (_newCardsLimit + 10).clamp(10, 500))
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'DECKS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // Deck cards — dynamic from DeckRepository.
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No syncable decks. Legacy decks with a GitHub source will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 14),
                        ),
                      ),
                    ),
                  ..._items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final deck = item['deck'] as DeckEntity;
                    final accentColor = Color(deck.colorValue);
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 1))
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accentColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          // ignore: non_const_argument_for_const_parameter
                          child: Icon(
                            IconData(deck.iconCodePoint,
                                fontFamily: 'MaterialIcons'),
                            color: accentColor,
                            size: 32,
                          ),
                        ),
                        title: Text(deck.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          item['toggle']
                              ? 'Override ON — resets all progress'
                              : 'Override OFF — only corrections reset to 0',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                        trailing: Switch(
                          value: item['toggle'],
                          activeThumbColor: accentColor,
                          onChanged: (value) =>
                              setState(() => _items[i]['toggle'] = value),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // Download button — always pinned at the bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading ? null : _downloadAll,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download),
                label: Text(_loading ? 'Downloading…' : 'Download All Decks',
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
