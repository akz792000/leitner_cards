import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:leitner_cards/entity/card_entity.dart';
import 'package:leitner_cards/entity/visual_card_entity.dart';
import 'package:leitner_cards/enums/group_code.dart';
import '../repository/card_repository.dart';
import '../repository/visual_card_repository.dart';
import 'package:leitner_cards/util/date_time_util.dart';

/// Manual re-download screen for card decks.
///
/// Each deck row has an "Override" toggle. When off, only cards with changed
/// content are updated and local progress (level/subLevel/order) is preserved.
/// When on, every card in that deck is reset to level 0 — useful after a
/// major content update in the GitHub source JSON.
class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final VisualCardRepository _visualCardRepository = Get.find<VisualCardRepository>();

  static const String _baseUrl =
      'https://raw.githubusercontent.com/akz792000/Dictionary/main';

  final List<Map<String, dynamic>> _items = [
    {
      "name": "English / Farsi",
      "icon": "en",
      "toggle": false,
      "url": "$_baseUrl/en_fa.json",
      "visual": false,
    },
    {
      "name": "Deutsch / English",
      "icon": "de",
      "toggle": false,
      "url": "$_baseUrl/de_en.json",
      "visual": false,
    },
    {
      "name": "Visual / English",
      "icon": "vi",
      "toggle": false,
      "url": "$_baseUrl/vi_en.json",
      "visual": true,
    },
  ];

  bool _loading = false;

  Future<void> _persistCard(Map<String, dynamic> element, bool override) async {
    final id = element["id"] as int? ?? 0;
    final existing = _cardRepository.findById(id);

    final entity = CardEntity(
      id: id,
      created: existing?.created ?? DateTimeUtil.now(),
      modified: existing?.modified ?? DateTimeUtil.now(),
      level: (override || existing == null) ? CardEntity.initLevel : existing.level,
      subLevel: (override || existing == null) ? CardEntity.initSubLevel : existing.subLevel,
      order: (override || existing == null) ? 0 : existing.order,
      fa: element["fa"] ?? "",
      en: element["en"] ?? "",
      de: element["de"] ?? "",
      desc: element["desc"] ?? "",
      groupCode: GroupCode.values[element["groupCode"] ?? GroupCode.english.index],
    );

    final contentChanged = existing == null ||
        existing.fa != entity.fa ||
        existing.en != entity.en ||
        existing.de != entity.de ||
        existing.desc != entity.desc;

    if (override || contentChanged) {
      await _cardRepository.merge(entity);
    }
  }

  Future<void> _persistVisualCard(Map<String, dynamic> element, bool override) async {
    final id = element["id"] as int? ?? 0;
    final existing = _visualCardRepository.findById(id);

    final entity = VisualCardEntity(
      id: id,
      created: existing?.created ?? DateTimeUtil.now(),
      modified: existing?.modified ?? DateTimeUtil.now(),
      level: (override || existing == null) ? VisualCardEntity.initLevel : existing.level,
      subLevel: (override || existing == null) ? VisualCardEntity.initSubLevel : existing.subLevel,
      order: (override || existing == null) ? 0 : existing.order,
      image: element["image"] ?? "",
      en: element["en"] ?? "",
      de: element["de"] ?? "",
    );

    final contentChanged = existing == null ||
        existing.image != entity.image ||
        existing.en != entity.en ||
        existing.de != entity.de;

    if (override || contentChanged) {
      await _visualCardRepository.merge(entity);
    }
  }

  Future<void> _download(Map<String, dynamic> item) async {
    final response = await http.get(Uri.parse(item['url'] as String));
    if (response.statusCode != 200) {
      throw Exception('Failed to download ${item['name']}: HTTP ${response.statusCode}');
    }
    final List<dynamic> rows = json.decode(response.body);
    final bool isVisual = item['visual'] as bool;
    final bool override = item['toggle'] as bool;
    for (final row in rows) {
      if (isVisual) {
        await _persistVisualCard(row as Map<String, dynamic>, override);
      } else {
        await _persistCard(row as Map<String, dynamic>, override);
      }
    }
  }

  Future<void> _downloadAll() async {
    setState(() => _loading = true);
    try {
      for (final item in _items) {
        await _download(item);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download complete'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
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
                  child: Icon(Icons.cloud_download_outlined, color: Colors.blue.shade600, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Download from GitHub',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text(
                        'Enable "Override" to reset card progress and replace with latest content.',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'DECKS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Deck cards
          ..._items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final isEnglish = item['icon'] == 'en';
            final isVisual = item['icon'] == 'vi';
            final accentColor = isEnglish
                ? Colors.blue.shade600
                : isVisual
                    ? Colors.teal.shade600
                    : Colors.orange.shade700;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isVisual
                      ? Icon(Icons.image_outlined, color: accentColor, size: 32)
                      : Image.asset('assets/flags/${item['icon']}.png', width: 32, height: 32),
                ),
                title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  item['toggle'] ? 'Override ON — resets progress' : 'Override OFF — keeps local progress',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                trailing: Switch(
                  value: item['toggle'],
                  activeColor: accentColor,
                  onChanged: (value) => setState(() => _items[i]['toggle'] = value),
                ),
              ),
            );
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading ? null : _downloadAll,
                icon: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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

