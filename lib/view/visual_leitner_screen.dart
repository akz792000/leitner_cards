import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/entity/card_entity.dart';
import 'package:leitner_cards/entity/progress_entity.dart';
import 'package:leitner_cards/enums/group_code.dart';
import 'package:leitner_cards/repository/card_repository.dart';
import 'package:leitner_cards/repository/progress_repository.dart';
import 'package:leitner_cards/service/card_service.dart';
import 'package:leitner_cards/util/date_time_util.dart';

import '../config/route_config.dart';
import '../enums/level_direction.dart';
import '../service/route_service.dart';
import 'widget/animated_button.dart';
import 'widget/animated_gradient_background.dart';

/// Study screen for the visual (image-based) Leitner deck.
///
/// [level] controls which cards are loaded — same sentinel values as [LeitnerScreen]:
/// - [allLevel] (-1): runs the full Leitner algorithm.
/// - [allLimitedLevel] (-2): shows every visual card regardless of schedule.
/// - Any positive int: shows only cards at that exact level.
///
/// UX flow:
///   1. Full image shown — user tries to describe it mentally.
///   2. Tap image → reveals bilingual descriptions (EN + DE toggle).
///   3. Tap image again → collapses back to full image.
///   4. Thumb up (👍) → card advances one Leitner level.
///      Thumb down (👎) → card resets to level 0.
///   5. Thumb buttons are disabled until the card is revealed.
///
/// Burn-in protection (AMOLED):
///   - Pixel shift: entire view moves ±2px every 30s.
///   - Auto-dim: black overlay (85% opacity) after 2 minutes idle.
class VisualLeitnerScreen extends StatefulWidget {
  /// Sentinel: load today's cards via the Leitner algorithm.
  static const int allLevel = -1;

  /// Sentinel: load all visual cards (ignores the schedule).
  static const int allLimitedLevel = -2;

  final int level;

  const VisualLeitnerScreen({super.key, required this.level});

  @override
  State<VisualLeitnerScreen> createState() => _VisualLeitnerScreenState();
}

class _VisualLeitnerScreenState extends State<VisualLeitnerScreen> {
  static const String _imageBaseUrl =
      'https://raw.githubusercontent.com/akz792000/Dictionary/main/images';

  final ProgressRepository _progressRepository = Get.find<ProgressRepository>();
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final CardService _service = Get.find<CardService>();
  final PageController _pageController = PageController();

  late List<CardEntity> _cards;
  late Map<int, ProgressEntity> _progressMap;
  late CardEntity _cardEntity;
  late ProgressEntity _progressEntity;
  int _index = 0;

  final Map<int, LevelDirection?> _levelChangedMap = {};
  final Set<int> _orderChangedSet = {};
  final Set<int> _revealedSet = {};

  // ── Burn-in protection ────────────────────────────────────────────────────
  Timer? _idleTimer;
  Timer? _pixelShiftTimer;
  bool _isDimmed = false;
  double _shiftX = 0;
  double _shiftY = 0;
  final _rng = Random();

  static const _dimAfter = Duration(minutes: 2);
  static const _shiftInterval = Duration(seconds: 30);
  static const _maxShift = 2.0;

  /// Per-card language tab selection: 0 = English, 1 = Deutsch.
  final Map<int, int> _langTabMap = {};

  @override
  void initState() {
    super.initState();
    _loadCards();
    if (_cards.isNotEmpty) {
      _cardEntity = _cards[0];
      _progressEntity = _progressMap[_cardEntity.id]!;
      _modifyOrder();
    } else {
      _index = -1;
    }
    _startBurnInProtection();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _pixelShiftTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _loadCards() {
    // Load cards based on the level sentinel (same logic as LeitnerScreen).
    final List<(CardEntity, ProgressEntity)> pairs;
    switch (widget.level) {
      case VisualLeitnerScreen.allLevel:
        pairs = _service.findAllBasedOnLeitner(GroupCode.visual);
        break;
      case VisualLeitnerScreen.allLimitedLevel:
        final cards = _cardRepository.findAllByGroupCode(GroupCode.visual);
        pairs = cards
            .map((c) => (c, _progressRepository.findOrCreate(c.id)))
            .toList();
        break;
      default:
        // Specific level — filter by exact level
        final cards = _cardRepository.findAllByGroupCode(GroupCode.visual);
        pairs = cards
            .map((c) => (c, _progressRepository.findOrCreate(c.id)))
            .where((p) => p.$2.level == widget.level)
            .toList();
    }
    _cards = pairs.map((p) => p.$1).toList();
    _progressMap = {for (final p in pairs) p.$1.id: p.$2};
  }

  void _startBurnInProtection() {
    _resetIdleTimer();
    _pixelShiftTimer = Timer.periodic(_shiftInterval, (_) {
      if (!mounted) return;
      setState(() {
        _shiftX = (_rng.nextDouble() * _maxShift * 2) - _maxShift;
        _shiftY = (_rng.nextDouble() * _maxShift * 2) - _maxShift;
      });
    });
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_isDimmed) setState(() => _isDimmed = false);
    _idleTimer = Timer(_dimAfter, () {
      if (mounted) setState(() => _isDimmed = true);
    });
  }

  void _modifyOrder() async {
    if (!_orderChangedSet.contains(_cardEntity.id)) {
      _progressEntity.order++;
      _orderChangedSet.add(_cardEntity.id);
      await _progressRepository.merge(_progressEntity);
    }
  }

  void _onPageChanged(int value) {
    setState(() {
      _index = value;
      _cardEntity = _cards[value];
      _progressEntity = _progressMap[_cardEntity.id]!;
    });
    _modifyOrder();
  }

  /// Copies the currently visible card text to the clipboard and shows a snackbar.
  void _copyCurrentText(BuildContext context) {
    final text = (_langTabMap[_cardEntity.id] ?? 0) == 0
        ? _cardEntity.en
        : _cardEntity.de;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleReveal() {
    setState(() {
      if (_revealedSet.contains(_cardEntity.id)) {
        _revealedSet.remove(_cardEntity.id);
      } else {
        _revealedSet.add(_cardEntity.id);
      }
    });
    _resetIdleTimer();
  }

  void _changePage(int level, LevelDirection direction) async {
    _progressEntity.level = level;
    _progressEntity.subLevel = ProgressEntity.initSubLevel;
    _progressEntity.modified = DateTimeUtil.now();
    await _progressRepository.merge(_progressEntity);
    setState(() => _levelChangedMap[_cardEntity.id] = direction);
    _resetIdleTimer();

    if (_index < _cards.length - 1) {
      _pageController.animateToPage(
        _index + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildImageStack(bool revealed, String imageUrl) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : Container(
                  color: Colors.black12,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade800,
            child: const Center(
              child: Icon(Icons.broken_image_outlined,
                  size: 48, color: Colors.white38),
            ),
          ),
        ),
        if (!revealed)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_outlined,
                      color: Colors.white70, size: 18),
                  SizedBox(width: 6),
                  Text('Tap to reveal description',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ),
        if (revealed)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fullscreen, color: Colors.white70, size: 14),
                  SizedBox(width: 4),
                  Text('Tap to expand',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImageCard(CardEntity card, int pageIndex) {
    final progress = _progressMap[card.id] ?? _progressEntity;
    final revealed = _revealedSet.contains(card.id);
    final levelChanged = _levelChangedMap[card.id];
    final imageUrl = '$_imageBaseUrl/${card.image}';

    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double offset = 0;
        if (_pageController.hasClients && _pageController.page != null) {
          offset = (_pageController.page! - pageIndex).abs();
        }
        final scale = (1 - offset * 0.08).clamp(0.92, 1.0);
        final opacity = (1 - offset * 0.35).clamp(0.65, 1.0);
        return Transform.scale(
          scale: scale,
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: AnimatedGradientBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                // ── Image ──────────────────────────────────────────────────
                if (revealed)
                  GestureDetector(
                    onTap: _toggleReveal,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeInOut,
                      height: constraints.maxHeight * 0.45,
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 12,
                              offset: Offset(0, 4))
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildImageStack(revealed, imageUrl),
                    ),
                  )
                else
                  Expanded(
                    child: GestureDetector(
                      onTap: _toggleReveal,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black26,
                                blurRadius: 12,
                                offset: Offset(0, 4))
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildImageStack(revealed, imageUrl),
                      ),
                    ),
                  ),

                // ── Language toggle + Description (after reveal) ──────────
                if (revealed) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _langTabMap[card.id] = 0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: (_langTabMap[card.id] ?? 0) == 0
                                    ? Colors.blue.shade600
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(8)),
                                border: Border.all(
                                    color: Colors.blue.shade600
                                        .withValues(alpha: 0.6)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('🇺🇸',
                                      style: TextStyle(
                                          fontSize:
                                              (_langTabMap[card.id] ?? 0) == 0
                                                  ? 18
                                                  : 14)),
                                  const SizedBox(width: 6),
                                  Text('English',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              (_langTabMap[card.id] ?? 0) == 0
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                          color:
                                              (_langTabMap[card.id] ?? 0) == 0
                                                  ? Colors.white
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _langTabMap[card.id] = 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: (_langTabMap[card.id] ?? 0) == 1
                                    ? Colors.orange.shade700
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(8)),
                                border: Border.all(
                                    color: Colors.orange.shade700
                                        .withValues(alpha: 0.6)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('🇩🇪',
                                      style: TextStyle(
                                          fontSize:
                                              (_langTabMap[card.id] ?? 0) == 1
                                                  ? 18
                                                  : 14)),
                                  const SizedBox(width: 6),
                                  Text('Deutsch',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              (_langTabMap[card.id] ?? 0) == 1
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                          color:
                                              (_langTabMap[card.id] ?? 0) == 1
                                                  ? Colors.white
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: SingleChildScrollView(
                        key: ValueKey(_langTabMap[card.id] ?? 0),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: Text(
                          (_langTabMap[card.id] ?? 0) == 0 ? card.en : card.de,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else
                  const SizedBox.shrink(),

                // ── Bottom bar (only shown after reveal) ──────────────────
                if (revealed)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          AnimatedButton(
                            key: const ValueKey('dislike'),
                            icon: const Icon(Icons.thumb_down_outlined,
                                size: 30, color: Colors.white),
                            isActive: levelChanged == LevelDirection.down,
                            activeColor: Colors.redAccent,
                            onPressed: levelChanged == LevelDirection.down
                                ? null
                                : () => _changePage(ProgressEntity.initLevel,
                                    LevelDirection.down),
                          ),
                          AnimatedButton(
                            key: const ValueKey('like'),
                            icon: const Icon(Icons.thumb_up_alt_outlined,
                                size: 30, color: Colors.white),
                            isActive: levelChanged == LevelDirection.up,
                            activeColor: Colors.green,
                            onPressed: levelChanged == LevelDirection.up
                                ? null
                                : () => _changePage(
                                    progress.level + 1, LevelDirection.up),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Visual'),
          backgroundColor: Colors.teal.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_outlined, size: 72, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('No visual cards yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              Text('Download the Visual deck first',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${_index + 1} of ${_cards.length}'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: InkWell(
          child: const Icon(Icons.arrow_back_ios),
          onTap: () =>
              Get.find<RouteService>().pushReplacementNamed(RouteConfig.home),
        ),
        actions: [
          if (_revealedSet.contains(_cardEntity.id))
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copy',
              onPressed: () => _copyCurrentText(context),
            ),
        ],
      ),
      body: Listener(
        onPointerDown: (_) => _resetIdleTimer(),
        child: Stack(
          children: [
            Transform.translate(
              offset: Offset(_shiftX, _shiftY),
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _cards.length,
                itemBuilder: (context, index) =>
                    _buildImageCard(_cards[index], index),
              ),
            ),
            if (_isDimmed)
              GestureDetector(
                onTap: _resetIdleTimer,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.85),
                  child: const Center(
                    child: Text(
                      'Tap to wake',
                      style: TextStyle(color: Colors.white38, fontSize: 16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
