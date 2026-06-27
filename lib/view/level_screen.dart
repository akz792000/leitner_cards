import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/enums/group_code.dart';
import 'package:leitner_cards/repository/card_repository.dart';
import 'package:leitner_cards/repository/deck_repository.dart';
import 'package:leitner_cards/repository/progress_repository.dart';
import 'package:leitner_cards/view/leitner_screen.dart';
import '../config/route_config.dart';
import '../entity/card_entity.dart';
import '../entity/deck_entity.dart';
import '../service/route_service.dart';
import '../util/color_util.dart';

/// Level picker for a single deck.
///
/// Accepts either a legacy [GroupCode] or a [DeckEntity] (or both for legacy
/// decks that have been seeded). Lists all Leitner levels with at least one
/// card. The FAB launches "Play All", AppBar actions offer "Play Limited",
/// "Edit cards" (→ [DeckDetailScreen]), and "Edit deck" (name/icon/color).
class LevelScreen extends StatefulWidget {
  final GroupCode? groupCode;
  final String? deckId;

  const LevelScreen({super.key, this.groupCode, this.deckId})
      : assert(groupCode != null || deckId != null,
            'Either groupCode or deckId must be provided');

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> with RouteAware {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final ProgressRepository _progressRepository = Get.find<ProgressRepository>();
  final DeckRepository _deckRepository = Get.find<DeckRepository>();
  late int _count;
  late Map<int, int> _levelMap;

  DeckEntity? get _deck =>
      widget.deckId != null ? _deckRepository.findById(widget.deckId!) : null;

  Color get _accentColor {
    final deck = _deck;
    if (deck != null) return Color(deck.colorValue);
    if (widget.groupCode == GroupCode.faEn) return Colors.blue.shade600;
    if (widget.groupCode == GroupCode.visual) return Colors.green.shade700;
    return Colors.orange.shade700;
  }

  String get _title {
    final deck = _deck;
    if (deck != null) return deck.name;
    return widget.groupCode?.title ?? 'Deck';
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Get.find<RouteService>()
        .routeObserver
        .subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    setState(_initialize);
  }

  @override
  void dispose() {
    Get.find<RouteService>().routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// The raw groupCode string to query cards — either legacy code or deckId.
  String get _cardCode => widget.groupCode?.code ?? widget.deckId ?? '';

  List<CardEntity> _queryCards() {
    return _cardRepository.findAllByCode(_cardCode);
  }

  void _initialize() {
    final cards = _queryCards();
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
          arguments: {
            "groupCode": _cardCode,
            "level": level,
            "deck": _deck,
          },
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

  Widget _buildHeaderIcon() {
    final deck = _deck;
    if (deck != null) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(51),
          borderRadius: BorderRadius.circular(6),
        ),
        // ignore: non_const_argument_for_const_parameter
        child: Icon(
          IconData(deck.iconCodePoint, fontFamily: 'MaterialIcons'),
          color: Colors.white,
          size: 18,
        ),
      );
    }
    if (widget.groupCode == GroupCode.visual) {
      return const Icon(Icons.photo_library_outlined,
          color: Colors.white, size: 26);
    }
    final flagName = widget.groupCode == GroupCode.faEn ? 'en' : 'de';
    return Image.asset('assets/flags/$flagName.png', width: 26, height: 26);
  }

  @override
  Widget build(BuildContext context) {
    final levels = _levelMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _buildHeaderIcon(),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                _title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
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
          // View / edit cards.
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: 'View / edit cards',
            onPressed: () async {
              if (widget.deckId != null) {
                await Get.find<RouteService>().pushNamed(
                  RouteConfig.deckDetail,
                  arguments: {'deckId': widget.deckId!},
                );
              } else {
                await Get.find<RouteService>().pushReplacementNamed(
                  RouteConfig.data,
                  arguments: {"groupCode": widget.groupCode!},
                );
              }
              setState(() => _initialize());
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
                        const SizedBox(height: 4),
                        Text('Tap the list icon to add cards',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 13)),
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
                    "groupCode": _cardCode,
                    "level": LeitnerScreen.allLevel,
                    "deck": _deck,
                  },
                );
              },
            ),
    );
  }
}
