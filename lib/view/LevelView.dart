import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/enums/GroupCode.dart';
import 'package:leitner_cards/repository/CardRepository.dart';
import 'package:leitner_cards/view/LeitnerView.dart';

import '../config/RouteConfig.dart';
import '../service/RouteService.dart';

class LevelView extends StatefulWidget {
  final GroupCode groupCode;

  const LevelView({super.key, required this.groupCode});

  @override
  State<LevelView> createState() => _LevelViewState();
}

class _LevelViewState extends State<LevelView> {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  late int _count;
  late Map<int, int> _levelMap;

  bool get _isEnglish => widget.groupCode == GroupCode.english;
  Color get _accentColor => _isEnglish ? Colors.blue.shade600 : Colors.orange.shade700;
  List<Color> get _gradient => _isEnglish
      ? [const Color(0xFF1565C0), const Color(0xFF42A5F5)]
      : [const Color(0xFFE65100), const Color(0xFFFFB74D)];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    _count = _cardRepository.findAllByGroupCode(widget.groupCode).length;
    _levelMap = _cardRepository.findAllLevelBasedByGroupCode(widget.groupCode);
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
            child: Text(_levelEmoji(level), style: const TextStyle(fontSize: 22)),
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
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: _gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Row(
        children: [
          Image.asset(
            'assets/flags/${_isEnglish ? 'en' : 'de'}.png',
            width: 48,
            height: 48,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.groupCode.title,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                '$_count card${_count == 1 ? '' : 's'} total',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard(int level, int count) {
    final color = _levelColor(level);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        await Get.find<RouteService>().pushReplacementNamed(
          RouteConfig.leitner,
          arguments: {"groupCode": widget.groupCode, "level": level},
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level $level',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withAlpha(80)),
                        ),
                        child: Text(
                          '$count item${count == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
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
    final levels = _levelMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.groupCode.title} Levels'),
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
                await Get.find<RouteService>().pushReplacementNamed(
                  RouteConfig.leitner,
                  arguments: {"groupCode": widget.groupCode, "level": LeitnerView.allLimitedLevel},
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: levels.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.layers_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No cards yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: levels.length,
                    itemBuilder: (context, index) => _buildLevelCard(levels[index].key, levels[index].value),
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
                await Get.find<RouteService>().pushReplacementNamed(
                  RouteConfig.leitner,
                  arguments: {"groupCode": widget.groupCode, "level": LeitnerView.allLevel},
                );
              },
            ),
    );
  }
}
