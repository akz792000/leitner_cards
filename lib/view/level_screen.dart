import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/enums/group_code.dart';
import 'package:leitner_cards/repository/card_repository.dart';
import 'package:leitner_cards/repository/progress_repository.dart';
import 'package:leitner_cards/view/leitner_screen.dart';
import 'package:leitner_cards/view/visual_leitner_screen.dart';

import '../config/route_config.dart';
import '../service/route_service.dart';

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

class _LevelScreenState extends State<LevelScreen> {
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

  void _initialize() {
    final cards = _cardRepository.findAllByGroupCode(widget.groupCode);
    _count = cards.length;
    _levelMap = <int, int>{};
    for (final card in cards) {
      final level = _progressRepository.findOrCreate(card.id).level;
      _levelMap[level] = (_levelMap[level] ?? 0) + 1;
    }
  }

  Color _levelColor(int level) {
    const colors = [
      Color(0xFFF44336), // 0  red
      Color(0xFFFF5722), // 1  deep orange
      Color(0xFFFF9800), // 2  orange
      Color(0xFFFFC107), // 3  amber
      Color(0xFFFFEB3B), // 4  yellow
      Color(0xFFCDDC39), // 5  lime
      Color(0xFF8BC34A), // 6  light green
      Color(0xFF4CAF50), // 7  green
      Color(0xFF009688), // 8  teal
      Color(0xFF00BCD4), // 9  cyan
      Color(0xFF03A9F4), // 10 light blue
      Color(0xFF2196F3), // 11 blue
      Color(0xFF3F51B5), // 12 indigo
      Color(0xFF673AB7), // 13 deep purple
      Color(0xFF9C27B0), // 14 purple
      Color(0xFFE91E63), // 15 pink
    ];
    return colors[level.clamp(0, colors.length - 1)];
  }

  String _levelEmoji(int level) {
    const emojis = [
      '🥚', // 0  – not started
      '🐣', // 1  – hatching
      '🐥', // 2  – chick
      '🌱', // 3  – seedling
      '🌿', // 4  – growing
      '🌳', // 5  – tree
      '⚡', // 6  – energised
      '🔥', // 7  – on fire
      '💡', // 8  – bright idea
      '🎯', // 9  – focused
      '⭐', // 10 – star
      '🌟', // 11 – glowing star
      '💫', // 12 – shooting star
      '🏆', // 13 – trophy
      '👑', // 14 – crown
      '💎', // 15 – diamond
    ];
    return emojis[level.clamp(0, emojis.length - 1)];
  }

  Widget _levelBadge(int level) {
    final color = _levelColor(level);
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

  Widget _buildLevelCard(int level, int count) {
    final color = _levelColor(level);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        // Visual deck navigates to VisualLeitnerScreen; language decks to LeitnerScreen.
        if (_isVisual) {
          await Get.find<RouteService>().pushReplacementNamed(
            RouteConfig.visualLeitner,
            arguments: {"level": level},
          );
        } else {
          await Get.find<RouteService>().pushReplacementNamed(
            RouteConfig.leitner,
            arguments: {"groupCode": widget.groupCode, "level": level},
          );
        }
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
            _levelBadge(level),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Level $level',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
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
                          fontSize: 12,
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              '· $_count card${_count == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
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
                // Visual deck goes to VisualLeitnerScreen; language decks to LeitnerScreen.
                if (_isVisual) {
                  await Get.find<RouteService>().pushReplacementNamed(
                    RouteConfig.visualLeitner,
                    arguments: {"level": VisualLeitnerScreen.allLimitedLevel},
                  );
                } else {
                  await Get.find<RouteService>().pushReplacementNamed(
                    RouteConfig.leitner,
                    arguments: {
                      "groupCode": widget.groupCode,
                      "level": LeitnerScreen.allLimitedLevel
                    },
                  );
                }
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
                    itemBuilder: (context, index) =>
                        _buildLevelCard(levels[index].key, levels[index].value),
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
                // Visual deck goes to VisualLeitnerScreen; language decks to LeitnerScreen.
                if (_isVisual) {
                  await Get.find<RouteService>().pushReplacementNamed(
                    RouteConfig.visualLeitner,
                    arguments: {"level": VisualLeitnerScreen.allLevel},
                  );
                } else {
                  await Get.find<RouteService>().pushReplacementNamed(
                    RouteConfig.leitner,
                    arguments: {
                      "groupCode": widget.groupCode,
                      "level": LeitnerScreen.allLevel
                    },
                  );
                }
              },
            ),
    );
  }
}
