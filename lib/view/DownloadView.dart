import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert' as convert;
import 'package:http/http.dart' as http;
import 'package:leitner_cards/entity/CardEntity.dart';
import 'package:leitner_cards/enums/GroupCode.dart';
import '../config/RouteConfig.dart';
import '../entity/InfoEntity.dart';
import '../repository/CardRepository.dart';
import '../repository/InfoRepository.dart';
import '../service/RouteService.dart';
import 'package:leitner_cards/util/DateTimeUtil.dart';

class DownloadView extends StatefulWidget {
  const DownloadView({super.key});

  @override
  State<DownloadView> createState() => _DownloadViewState();
}

class _DownloadViewState extends State<DownloadView> {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final InfoRepository _infoRepository = Get.find<InfoRepository>();

  final List<Map<String, dynamic>> _items = [
    {"name": "File_0", "toggle": false, "type": "CARD"},
    {"name": "File_1", "toggle": false, "type": "CARD"},
    {"name": "File_2", "toggle": false, "type": "CARD"},
    {"name": "File_3", "toggle": false, "type": "CARD"},
    {"name": "Info_1", "toggle": false, "type": "INFO"},
  ];

  bool _toggle = false;
  int _selectedIndex = 0;

  Future<int> _persistInfo(Map<String, dynamic> element) async {
    final entity = InfoEntity(
      id: element["id"] ?? 0,
      created: DateTimeUtil.now(),
      modified: DateTimeUtil.now(),
      key: element["key"] ?? "",
      value: element["value"] ?? "",
      groupCode: GroupCode.values[element["groupCode"] ?? GroupCode.english.index],
    );
    return await _infoRepository.merge(entity);
  }

  Future<int> _persistCard(Map<String, dynamic> element) async {
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
      desc: element["desc"] ?? "",
      groupCode: GroupCode.values[element["groupCode"] ?? GroupCode.english.index],
    );
    return await _cardRepository.merge(entity);
  }

  Future<void> _download(Map<String, dynamic> item) async {
    final url = Uri.https(
      'raw.githubusercontent.com',
      '/akz792000/Dictionary/main/${item['name']}.json',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final extractedData = List<Map<String, dynamic>>.from(
          convert.jsonDecode(response.body),
        );

        for (final element in extractedData) {
          if (item['type'] == "CARD") {
            final existing = _cardRepository.findById(element["id"]);
            if (existing == null ||
                item["toggle"] ||
                existing.fa != (element["fa"] ?? existing.fa) ||
                existing.en != (element["en"] ?? existing.en) ||
                existing.de != (element["de"] ?? existing.de) ||
                existing.desc != (element["desc"] ?? existing.desc)) {
              await _persistCard(element);
            }
          } else {
            final existing = _infoRepository.findById(element["id"]);
            if (existing == null ||
                item["toggle"] ||
                existing.key != (element["key"] ?? existing.key) ||
                existing.value != (element["value"] ?? existing.value)) {
              await _persistInfo(element);
            }
          }
        }
      } else {
        debugPrint('Request failed: ${response.statusCode}');
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
      Navigator.pop(context); // Close loading screen
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
