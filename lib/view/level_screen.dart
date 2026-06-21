import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/enums/group_code.dart';
import 'package:leitner_cards/repository/card_repository.dart';
import 'package:leitner_cards/repository/progress_repository.dart';
import 'package:leitner_cards/view/leitner_screen.dart';

import '../config/route_config.dart';
import '../service/route_service.dart';
import '../util/color_util.dart';

/// Level picker for a single language deck.
///
/// Lists all Leitner levels that have at least one card, each with its own
/// colour and emoji badge. The FAB launches "Play All" (full Leitner schedule)
/// and the AppBar actions offer "Play Limited" (all cards, no schedule) and
/// a link to [DataScreen].
class LevelScreen extends StatefulWidget {
  final GroupCode groupCode;

  const LevelScreen({super.key, required this.groupCode});

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> with RouteAware {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final ProgressRepository _progressRepository = Get.find<ProgressRepository>();
  late int _count;
  late Map<int, int> _levelMap;

  bool get _isEnglish => widget.groupCode == GroupCode.faEn;
  bool get _isVisual => widget.groupCode == GroupCode.visual;

  // Accent colour adapts per deck type (also used for AppBar and FAB).
  Color get _accentColor {
    if (_isEnglish) return Colors.blue.shade600;
    if (_isVisual) return Colors.green.shade700;
    return Colors.orange.shade700;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route events so we refresh when navigating back from
    // LeitnerScreen — level counts change after cards are graded.
    Get.find<RouteService>()
        .routeObserver
        .subscribe(this, ModalRoute.of(context)!);
  }

  /// Called by [RouteObserver] when this screen comes back into view.
  @override
  void didPopNext() {
    setState(_initialize);
  }

  @override
  void dispose() {
    Get.find<RouteService>().routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _initialize() {
    final cards = _cardRepository.findAllByGroupCode(widget.groupCode);
    _count = cards.length;
    _levelMap = <int, int>{};
    for (final card in cards) {
      final level = _progressRepository.findOrCreate(card.id).level;
      _levelMap[level] = (_levelMap[level] ?? 0) + 1;
    }
  }

  Color _levelColor(int level, BuildContext context) =>
      ColorUtil.levelColor(level, Theme.of(context).brightness);

  String _levelEmoji(int level) {
    const emojis = [
      '🐛', // 0  – caterpillar (tiny, helpless)
      '🐌', // 1  – snail (slow starter)
      '🐁', // 2  – mouse (small but alive)
      '🐇', // 3  – rabbit (getting quicker)
      '🦔', // 4  – hedgehog (has some defence)
      '🦊', // 5  – fox (smart & cunning)
      '🐺', // 6  – wolf (pack hunter)
      '🐗', // 7  – boar (fierce & tough)
      '🐆', // 8  – leopard (fast predator)
      '🦁', // 9  – lion (king of savanna)
      '🐯', // 10 – tiger (apex predator)
      '🦅', // 11 – eagle (rules the sky)
      '🦈', // 12 – shark (rules the sea)
      '🦏', // 13 – rhino (unstoppable force)
      '🐘', // 14 – elephant (wise & mighty)
      '🐉', // 15 – dragon (beyond nature — legendary)
    ];
    return emojis[level.clamp(0, emojis.length - 1)];
  }

  Widget _levelBadge(int level, BuildContext context) {
    final color = _levelColor(level, context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child:
                Text(_levelEmoji(level), style: const TextStyle(fontSize: 22)),
          ),
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '$level',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelCard(int level, int count, BuildContext context) {
    final color = _levelColor(level, context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        await Get.find<RouteService>().pushNamed(
          RouteConfig.leitner,
          arguments: {"groupCode": widget.groupCode, "level": level},
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 72,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 16),
            _levelBadge(level, context),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Level $level',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withAlpha(80)),
                    ),
                    child: Text(
                      '$count item${count == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 14,
                          color: color,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_circle_filled, color: _accentColor, size: 32),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final levels = _levelMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        // Title shows deck name + card count — no separate gradient header needed.
        title: Row(
          children: [
            // Visual deck uses a camera icon; language decks use their flag.
            _isVisual
                ? const Icon(Icons.photo_library_outlined,
                    color: Colors.white, size: 26)
                : Image.asset(
                    'assets/flags/${_isEnglish ? 'en' : 'de'}.png',
                    width: 26,
                    height: 26,
                  ),
            const SizedBox(width: 10),
            Text(
              widget.groupCode.title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              '· $_count card${_count == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 15, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: 'View cards',
            onPressed: () async {
              await Get.find<RouteService>().pushReplacementNamed(
                RouteConfig.data,
                arguments: {"groupCode": widget.groupCode},
              );
            },
          ),
          if (_count > 0)
            IconButton(
              icon: const Icon(Icons.skip_next_outlined),
              tooltip: 'Play limited',
              onPressed: () async {
                await Get.find<RouteService>().pushNamed(
                  RouteConfig.leitner,
                  arguments: {
                    "groupCode": widget.groupCode,
                    "level": LeitnerScreen.allLimitedLevel
                  },
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: levels.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.layers_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No cards yet',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: levels.length,
                    itemBuilder: (context, index) => _buildLevelCard(
                        levels[index].key, levels[index].value, context),
                  ),
          ),
        ],
      ),
      floatingActionButton: _count == 0
          ? null
          : FloatingActionButton.extended(
              heroTag: 'PlayAll',
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play All'),
              onPressed: () async {
                await Get.find<RouteService>().pushNamed(
                  RouteConfig.leitner,
                  arguments: {
                    "groupCode": widget.groupCode,
                    "level": LeitnerScreen.allLevel
                  },
                );
              },
            ),
    );
  }
}
