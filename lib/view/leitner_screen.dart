import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/entity/card_entity.dart';
import 'package:leitner_cards/entity/progress_entity.dart';
import 'package:leitner_cards/service/card_service.dart';
import 'package:leitner_cards/repository/card_repository.dart';
import 'package:leitner_cards/repository/progress_repository.dart';
import 'package:leitner_cards/view/widget/icon_button_widget.dart';

import '../config/route_config.dart';
import '../enums/language_code.dart';
import '../enums/group_code.dart';
import '../enums/level_direction.dart';
import '../service/route_service.dart';
import '../service/tts_service.dart';
import '../util/date_time_util.dart';
import 'widget/animated_gradient_background.dart';
import 'widget/animated_button.dart';
import 'widget/animated_flag.dart';
import 'widget/description_sheet.dart';

/// The main flashcard study view implementing the Leitner interaction loop.
///
/// [level] controls which cards are loaded:
/// - [allLevel] (-1): runs the full Leitner algorithm via [CardService].
/// - [allLimitedLevel] (-2): shows every card in the deck regardless of schedule.
/// - Any positive int: shows only cards at that exact level.
///
/// Vertical swipe toggles between the two language sides of the card.
/// Thumb-up promotes the card to the next level; thumb-down resets to level 0.
///
/// Burn-in protection for AMOLED screens:
/// - Whole view shifts ±2 px every 30 s (pixel shifting).
/// - After 2 min of inactivity a black overlay dims the screen; tap to wake.
class LeitnerScreen extends StatefulWidget {
  /// Sentinel: load today's cards via the Leitner algorithm.
  static const int allLevel = -1;

  /// Sentinel: load all cards in the deck (ignores the schedule).
  static const int allLimitedLevel = -2;

  final GroupCode groupCode;
  final int level;

  const LeitnerScreen({
    super.key,
    required this.groupCode,
    required this.level,
  });

  @override
  State<LeitnerScreen> createState() => _LeitnerScreenState();
}

class _LeitnerScreenState extends State<LeitnerScreen> {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final ProgressRepository _progressRepository = Get.find<ProgressRepository>();
  final CardService _cardService = Get.find<CardService>();
  final TtsService _ttsService = Get.find<TtsService>();
  final PageController _pageController =
      PageController(initialPage: 0, keepPage: true);

  late List<(CardEntity, ProgressEntity)> _pairs;
  late CardEntity _cardEntity;
  late ProgressEntity _progressEntity;
  int _index = 0;
  int _level = 1;
  late LanguageCode _languageCode;

  // Tracks whether the like/dislike button has been tapped for each card id.
  final Map<int, LevelDirection?> _levelChangedMap = {};
  final Set<int> _orderChangedSet = {};

  // Burn-in protection
  Timer? _idleTimer;
  Timer? _pixelShiftTimer;
  bool _isDimmed = false;
  double _shiftX = 0;
  double _shiftY = 0;
  final _rng = Random();

  static const _dimAfter = Duration(minutes: 2);
  static const _shiftInterval = Duration(seconds: 30);
  static const _maxShift = 2.0;

  @override
  void initState() {
    super.initState();
    _languageCode = _getInitialLanguageCode();
    _loadCards();
    if (_pairs.isNotEmpty) {
      _cardEntity = _pairs[0].$1;
      _progressEntity = _pairs[0].$2;
      _level = _progressEntity.level;
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
    _ttsService.stop();
    super.dispose();
  }

  void _startBurnInProtection() {
    _resetIdleTimer();
    _pixelShiftTimer = Timer.periodic(_shiftInterval, (_) => _shiftPixels());
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_isDimmed) setState(() => _isDimmed = false);
    _idleTimer = Timer(_dimAfter, () {
      if (mounted) setState(() => _isDimmed = true);
    });
  }

  void _shiftPixels() {
    if (!mounted) return;
    setState(() {
      _shiftX = (_rng.nextDouble() * _maxShift * 2) - _maxShift;
      _shiftY = (_rng.nextDouble() * _maxShift * 2) - _maxShift;
    });
  }

  LanguageCode _getInitialLanguageCode() {
    switch (widget.groupCode) {
      case GroupCode.faEn:
        return LanguageCode.fa;
      case GroupCode.enDe:
      case GroupCode.visual:
        return LanguageCode.en;
    }
  }

  void _loadCards() {
    switch (widget.level) {
      case LeitnerScreen.allLevel:
        _pairs = _cardService.findAllBasedOnLeitner(widget.groupCode);
        break;
      case LeitnerScreen.allLimitedLevel:
        final cards = _cardRepository.findAllByGroupCode(widget.groupCode);
        _pairs = cards
            .map((c) => (c, _progressRepository.findOrCreate(c.id)))
            .toList();
        break;
      default:
        final cards = _cardRepository.findAllByGroupCode(widget.groupCode);
        _pairs = cards
            .map((c) => (c, _progressRepository.findOrCreate(c.id)))
            .where((pair) => pair.$2.level == widget.level)
            .toList();
        break;
    }
  }

  /// Increments [order] the first time a card is shown in this session.
  void _modifyOrder() async {
    if (!_orderChangedSet.contains(_cardEntity.id)) {
      _progressEntity.order++;
      _orderChangedSet.add(_cardEntity.id);
      await _progressRepository.merge(_progressEntity);
    }
  }

  void _changeValue(int index, LanguageCode languageCode) {
    setState(() {
      _cardEntity = _pairs[index].$1;
      _progressEntity = _pairs[index].$2;
      _languageCode = languageCode;
      _level = _progressEntity.level;
    });
  }

  void _onPageChanged(int value) {
    _ttsService.stop();
    _index = value;
    _changeValue(_index, _getInitialLanguageCode());
    _modifyOrder();
  }

  /// Persists the new level/subLevel, updates local state, then advances the
  /// [PageView] to the next card (if one exists).
  void _changePage(int level, LevelDirection direction) async {
    _progressEntity.level = level;
    _progressEntity.subLevel = ProgressEntity.initSubLevel;
    _progressEntity.modified = DateTimeUtil.now();
    await _progressRepository.merge(_progressEntity);
    setState(() {
      _level = _progressEntity.level;
      _levelChangedMap[_cardEntity.id] = direction;
    });

    if (_index < _pairs.length - 1) {
      _pageController.animateToPage(
        _index + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Returns the text currently shown on the card (matches [_getTextChild] logic).
  String get _currentText {
    switch (widget.groupCode) {
      case GroupCode.faEn:
        return _languageCode == LanguageCode.fa
            ? _cardEntity.fa
            : _cardEntity.en;
      case GroupCode.enDe:
      case GroupCode.visual:
        return _languageCode == LanguageCode.en
            ? _cardEntity.en
            : _cardEntity.de;
    }
  }

  /// Copies the currently visible card text to the clipboard and shows a snackbar.
  void _copyCurrentText(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _currentText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _ttsService.stop();
    switch (widget.groupCode) {
      case GroupCode.faEn:
        _languageCode = _languageCode == LanguageCode.en
            ? LanguageCode.fa
            : LanguageCode.en;
        break;
      case GroupCode.enDe:
      case GroupCode.visual:
        _languageCode = _languageCode == LanguageCode.de
            ? LanguageCode.en
            : LanguageCode.de;
        break;
    }
    _changeValue(_index, _languageCode);
  }

  Widget _getTextChild({required BuildContext context}) {
    String message = '';

    switch (widget.groupCode) {
      case GroupCode.faEn:
        message =
            _languageCode == LanguageCode.fa ? _cardEntity.fa : _cardEntity.en;
        break;
      case GroupCode.enDe:
      case GroupCode.visual:
        message =
            _languageCode == LanguageCode.en ? _cardEntity.en : _cardEntity.de;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: SingleChildScrollView(
        child: Obx(() {
          final speaking = _ttsService.isSpeaking.value;
          final start = _ttsService.wordStart.value;
          final end = _ttsService.wordEnd.value;
          final highlighted = speaking && end > start && end <= message.length;

          // Always Text.rich so the widget type never changes — no layout shift.
          return Text.rich(
            TextSpan(
              children: highlighted
                  ? [
                      TextSpan(text: message.substring(0, start)),
                      TextSpan(
                        text: message.substring(start, end),
                        style: TextStyle(
                          background: Paint()
                            ..color = Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.35),
                        ),
                      ),
                      TextSpan(text: message.substring(end)),
                    ]
                  : [TextSpan(text: message)],
            ),
            textDirection: _languageCode.direction,
            textAlign: _languageCode.direction == TextDirection.rtl
                ? TextAlign.right
                : TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 28.0,
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _bottomBar() {
    final levelChanged = _levelChangedMap[_cardEntity.id];

    final result = [
      // Dislike
      AnimatedButton(
        icon: const Icon(Icons.thumb_down_outlined,
            size: 30, color: Colors.white),
        isActive: levelChanged == LevelDirection.down,
        activeColor: Colors.redAccent,
        onPressed: levelChanged == LevelDirection.down
            ? null
            : () => _changePage(ProgressEntity.initLevel, LevelDirection.down),
        key: const ValueKey("dislike"),
      ),
      // Description
      IconButtonWidget(
        const Icon(Icons.light_mode_outlined, size: 30),
        onPressed: _cardEntity.desc.isEmpty
            ? null
            : () => DescriptionSheet.show(context,
                card: _cardEntity, groupCode: widget.groupCode),
        key: const ValueKey("desc"),
      ),
      // Like
      AnimatedButton(
        icon: const Icon(Icons.thumb_up_alt_outlined,
            size: 30, color: Colors.white),
        isActive: levelChanged == LevelDirection.up,
        activeColor: Colors.green,
        onPressed: levelChanged == LevelDirection.up
            ? null
            : () => _changePage(_progressEntity.level + 1, LevelDirection.up),
        key: const ValueKey("like"),
      ),
    ];

    // Remove buttons that shouldn't show (skip widgets with no key)
    result.removeWhere((element) {
      if (element.key == null) return false;
      final keyValue = (element.key as ValueKey).value;
      return (keyValue == 'desc' && _cardEntity.desc.isEmpty) ||
          (keyValue == 'like' && widget.level != LeitnerScreen.allLevel);
    });

    return result;
  }

  Widget _buildCardPage(CardEntity card, int pageIndex) {
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
      child: _buildCardContent(),
    );
  }

  Widget _buildCardContent() {
    return Builder(
      builder: (context) => AnimatedGradientBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 2),
              child:
                  Text('Level: $_level', style: const TextStyle(fontSize: 30)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 2),
              child: AnimatedFlag(
                  imagePath: 'assets/flags/${_languageCode.name}.png'),
            ),
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(_languageCode),
                    child: _getTextChild(context: context),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28.0),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _bottomBar(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Item ${_index + 1} of ${_pairs.length}'),
        centerTitle: false,
        leading: InkWell(
          child: const Icon(Icons.arrow_back_ios),
          onTap: () async =>
              await Get.find<RouteService>().pushReplacementNamed(
            RouteConfig.level,
            arguments: {"groupCode": widget.groupCode},
          ),
        ),
        actions: [
          Obx(() => IconButton(
                icon: Icon(_ttsService.isSpeaking.value
                    ? Icons.stop_circle_outlined
                    : Icons.volume_up_outlined),
                tooltip: 'Speak',
                onPressed: () async {
                  if (_ttsService.isSpeaking.value) {
                    _ttsService.stop();
                  } else {
                    final ok =
                        await _ttsService.speak(_currentText, _languageCode);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'TTS not available for this language. Install it via Settings → General management → Text-to-speech.'),
                          duration: Duration(seconds: 4),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              )),
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
            // Pixel-shifted content
            Transform.translate(
              offset: Offset(_shiftX, _shiftY),
              child: GestureDetector(
                onVerticalDragEnd: _onVerticalDragEnd,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pairs.length,
                  itemBuilder: (context, index) =>
                      _buildCardPage(_pairs[index].$1, index),
                ),
              ),
            ),
            // Dim overlay — appears after 2 min of no interaction
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
