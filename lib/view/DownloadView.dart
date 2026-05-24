import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/entity/CardEntity.dart';
import 'package:leitner_cards/enums/GroupCode.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/RouteConfig.dart';
import '../repository/CardRepository.dart';
import '../service/RouteService.dart';
import 'package:leitner_cards/util/DateTimeUtil.dart';

class DownloadView extends StatefulWidget {
  const DownloadView({super.key});

  @override
  State<DownloadView> createState() => _DownloadViewState();
}

class _DownloadViewState extends State<DownloadView> {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final _client = Supabase.instance.client;

  final List<Map<String, dynamic>> _items = [
    {"name": "English Cards", "toggle": false, "groupCode": 0},
    {"name": "Deutsch Cards", "toggle": false, "groupCode": 1},
  ];

  bool _toggle = false;
  int _selectedIndex = 0;

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
      final rows = await _client
          .from('cards')
          .select()
          .eq('group_code', item['groupCode']);
      for (final row in rows) {
        await _persistCard(row, item['toggle']);
      }
    } catch (e) {
      debugPrint('Download error: $e');
    }
  }

  Future<void> _downloadAll() async {
    final routeService = Get.find<RouteService>();
    routeService.pushNamed(RouteConfig.loading);
    try {
      for (final item in _items) {
        await _download(item);
      }
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  void _toggleAll() {
    setState(() {
      _toggle = !_toggle;
      for (final item in _items) {
        item["toggle"] = _toggle;
      }
    });
  }

  void _onBottomNavTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        _downloadAll();
        break;
      case 1:
        _toggleAll();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Download')),
      body: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 4.0),
            child: Card(
              child: SwitchListTile(
                title: Text(item["name"]),
                value: item["toggle"],
                onChanged: (value) {
                  setState(() => item["toggle"] = value);
                },
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.download),
            label: 'Download',
          ),
          BottomNavigationBarItem(
            icon: Icon(_toggle ? Icons.toggle_on : Icons.toggle_off),
            label: 'Override',
          ),
        ],
      ),
    );
  }
}
