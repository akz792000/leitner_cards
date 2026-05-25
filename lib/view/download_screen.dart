import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/entity/card_entity.dart';
import 'package:leitner_cards/enums/group_code.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repository/card_repository.dart';
import 'package:leitner_cards/util/date_time_util.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final _client = Supabase.instance.client;

  final List<Map<String, dynamic>> _items = [
    {"name": "English / Farsi", "icon": "en", "toggle": false, "groupCode": 0},
    {"name": "Deutsch / English", "icon": "de", "toggle": false, "groupCode": 1},
  ];

  bool _loading = false;

  Future<void> _persistCard(Map<String, dynamic> element, bool override) async {
    final entity = CardEntity(
      id: element["id"] ?? 0,
      created: DateTimeUtil.now(),
      modified: DateTimeUtil.now(),
      level: CardEntity.initLevel,
      subLevel: CardEntity.initSubLevel,
      order: 0,
      fa: element["fa"] ?? "",
      en: element["en"] ?? "",
      de: element["de"] ?? "",
      desc: element["description"] ?? "",
      groupCode: GroupCode.values[element["group_code"] ?? GroupCode.english.index],
    );
    final existing = _cardRepository.findById(entity.id);
    if (existing == null ||
        override ||
        existing.fa != entity.fa ||
        existing.en != entity.en ||
        existing.de != entity.de ||
        existing.desc != entity.desc) {
      await _cardRepository.merge(entity);
    }
  }

  Future<void> _download(Map<String, dynamic> item) async {
    try {
      final rows = await _client.from('cards').select().eq('group_code', item['groupCode']);
      for (final row in rows) {
        await _persistCard(row, item['toggle']);
      }
    } catch (e) {
      debugPrint('Download error: $e');
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
                      const Text('Sync from Supabase',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text(
                        'Enable "Override" to replace existing cards with the remote version.',
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
            final isEnglish = item['groupCode'] == 0;
            final accentColor = isEnglish ? Colors.blue.shade600 : Colors.orange.shade700;

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
                  child: Image.asset('assets/flags/${item['icon']}.png', width: 32, height: 32),
                ),
                title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  item['toggle'] ? 'Override ON — remote wins' : 'Override OFF — keeps local progress',
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

