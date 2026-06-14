import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/entity/card_entity.dart';
import 'package:leitner_cards/entity/progress_entity.dart';
import 'package:leitner_cards/service/card_service.dart';
import 'package:leitner_cards/repository/card_repository.dart';
import 'package:leitner_cards/repository/progress_repository.dart';
import 'package:leitner_cards/view/widget/icon_button_widget.dart';

import '../enums/language_code.dart';
import '../enums/group_code.dart';
import '../enums/level_direction.dart';
import '../service/settings_service.dart';
import '../service/tts_service.dart';
import '../service/stt_service.dart';
import '../util/date_time_util.dart';
import '../enums/card_order.dart';
import 'widget/animated_gradient_background.dart';
import 'widget/animated_button.dart';
import 'widget/animated_flag.dart';
import 'widget/description_sheet.dart';

/// Paints rounded highlight boxes behind the currently spoken word.
/// Reads box positions directly from the [RenderParagraph] of [textKey] so
/// highlight placement is pixel-perfect regardless of text alignment or scale.
class _WordHighlightPainter extends CustomPainter {
  final GlobalKey textKey;
  final int start;
  final int end;
  final Color fillColor;
  final Color borderColor;

  const _WordHighlightPainter({
    required this.textKey,
    required this.start,
    required this.end,
    required this.fillColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final renderObject = textKey.currentContext?.findRenderObject();
    if (renderObject is! RenderParagraph) return;
    final boxes = renderObject.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
    final fill = Paint()..color = fillColor;
    final border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final box in boxes) {
      final rect =
          Rect.fromLTRB(box.left - 4, box.top, box.right + 4, box.bottom);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(7));
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, border);
    }
  }

  @override
  bool shouldRepaint(_WordHighlightPainter old) =>
      old.start != start || old.end != end;
}

///
/// Handles all deck types: FA_EN, EN_DE, and VISUAL. Cards with a non-empty
/// [CardEntity.image] field use an image-first reveal flow — the image is shown
/// in full until the user taps to reveal bilingual text and thumb buttons.
/// Cards without an image use the standard text flow with vertical-swipe language
/// toggle.
///
/// [level] controls which cards are loaded:
/// - [allLevel] (-1): runs the full Leitner algorithm via [CardService].
/// - [allLimitedLevel] (-2): shows every card in the deck regardless of schedule.
/// - Any positive int: shows only cards at that exact level.
///
/// Vertical swipe toggles between the two language sides of the card (text cards
/// only — disabled for image cards, which use an EN/DE tab bar instead).
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
  static const String _imageBaseUrl =
      'https://raw.githubusercontent.com/akz792000/Dictionary/main/images';

  final CardRepository _cardRepository = Get.find<CardRepository>();
  final ProgressRepository _progressRepository = Get.find<ProgressRepository>();
  final CardService _cardService = Get.find<CardService>();
  final TtsService _ttsService = Get.find<TtsService>();
  final SttService _sttService = Get.find<SttService>();
  final SettingsService _settingsService = Get.find<SettingsService>();
  final PageController _pageController =
      PageController(initialPage: 0, keepPage: true);
  final Map<int, ScrollController> _textScrollControllers = {};
  // One GlobalKey per page index — placed on Text.rich OUTSIDE Obx so it
  // never duplicates during reactive rebuilds.
  final Map<int, GlobalKey> _textKeys = {};

  ScrollController _scrollControllerForIndex(int index) =>
      _textScrollControllers.putIfAbsent(index, ScrollController.new);

  GlobalKey _textKeyForIndex(int index) =>
      _textKeys.putIfAbsent(index, GlobalKey.new);

  late List<(CardEntity, ProgressEntity)> _pairs;
  late CardEntity _cardEntity;
  late ProgressEntity _progressEntity;
  int _index = 0;
  int _level = 1;
  late LanguageCode _languageCode;

  // Tracks whether the like/dislike button has been tapped for each card id.
  final Map<int, LevelDirection?> _levelChangedMap = {};
  // Snapshot of each card's level at the moment this session started —
  // used to prevent re-grading the same card if the screen is recreated.
  final Map<int, int> _initialLevels = {};
  final Set<int> _orderChangedSet = {};

  // Image-card state: which cards have been tapped to reveal, and per-card language tab.
  final Set<int> _revealedSet = {};
  final Map<int, int> _langTabMap = {};

  // Burn-in protection
  Timer? _idleTimer;
  Timer? _pixelShiftTimer;
  Worker? _ttsScrollWorker;
  bool _isDimmed = false;
  double _shiftX = 0;
  double _shiftY = 0;
  bool _micPulseFlip =
      false; // toggled each pulse cycle to keep animation running
  final _rng = Random();

  /// Dynamic dim delay driven by [SettingsService.dimDelayMin].
  Duration get _dimAfter =>
      Duration(minutes: _settingsService.dimDelayMin.value);
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
    _ttsScrollWorker = ever(_ttsService.wordStart, _scrollToHighlightedWord);
  }

  @override
  void dispose() {
    _ttsScrollWorker?.dispose();
    for (final c in _textScrollControllers.values) {
      c.dispose();
    }
    _idleTimer?.cancel();
    _pixelShiftTimer?.cancel();
    _pageController.dispose();
    _ttsService.stop();
    super.dispose();
  }

  /// Scrolls the text area so the currently highlighted word stays visible.
  /// Uses [RenderParagraph.getOffsetForCaret] via [_textKeyForIndex] for
  /// pixel-perfect Y position — no TextPainter approximation needed.
  void _scrollToHighlightedWord(int wordStart) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _scrollControllerForIndex(_index);
      if (!controller.hasClients) return;
      final maxExtent = controller.position.maxScrollExtent;
      if (maxExtent <= 0) return;
      final renderObject =
          _textKeyForIndex(_index).currentContext?.findRenderObject();
      if (renderObject is RenderParagraph) {
        final offset = renderObject.getOffsetForCaret(
          TextPosition(offset: wordStart),
          Rect.zero,
        );
        final scrollOffset = (offset.dy - 100).clamp(0.0, maxExtent);
        controller.animateTo(
          scrollOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startBurnInProtection() {
    _resetIdleTimer();
    _pixelShiftTimer = Timer.periodic(_shiftInterval, (_) => _shiftPixels());
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_isDimmed) setState(() => _isDimmed = false);
    // Only schedule dim timer when AMOLED dim protection is enabled.
    if (!_settingsService.amoledDim.value) return;
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
      case GroupCode.enDeVerbs:
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
    // Apply card order from settings.
    switch (_settingsService.cardOrder.value) {
      case CardOrder.highFirst:
        _pairs.sort((a, b) => b.$2.level.compareTo(a.$2.level));
        break;
      case CardOrder.lowFirst:
        _pairs.sort((a, b) => a.$2.level.compareTo(b.$2.level));
        break;
      case CardOrder.random:
        _pairs.shuffle();
        break;
    }
    // Snapshot initial levels so we can detect re-grading if the screen is
    // recreated after the user navigates away mid-session.
    for (final pair in _pairs) {
      _initialLevels[pair.$1.id] = pair.$2.level;
    }
    // Pre-populate _levelChangedMap for any card already graded this session.
    // A card is considered graded if its persisted level differs from the
    // snapshot — meaning _changePage was called in a previous screen instance.
    for (final pair in _pairs) {
      final cardId = pair.$1.id;
      final currentLevel = pair.$2.level;
      final initialLevel = _initialLevels[cardId]!;
      if (currentLevel > initialLevel) {
        _levelChangedMap[cardId] = LevelDirection.up;
      } else if (currentLevel < initialLevel) {
        _levelChangedMap[cardId] = LevelDirection.down;
      }
    }
  }

  /// Returns true when [card] has an image that should drive the reveal-first UX.
  bool _isImageCard(CardEntity card) => card.image.isNotEmpty;

  /// Toggles the revealed state for [card] and resets the idle timer.
  void _toggleReveal(CardEntity card) {
    setState(() {
      if (_revealedSet.contains(card.id)) {
        _revealedSet.remove(card.id);
      } else {
        _revealedSet.add(card.id);
      }
    });
    _resetIdleTimer();
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
    // Auto-speak the card when the page changes, if enabled.
    if (_settingsService.autoSpeak.value &&
        _settingsService.speakEnabled.value) {
      final lang = _isImageCard(_cardEntity)
          ? ((_langTabMap[_cardEntity.id] ?? 0) == 0
              ? LanguageCode.en
              : LanguageCode.de)
          : languageCode;
      _ttsService.speak(_currentText, lang);
    }
  }

  void _onPageChanged(int value) {
    _ttsService.stop();
    _index = value;
    _changeValue(_index, _getInitialLanguageCode());
    _modifyOrder();
  }

  /// Persists the new level/subLevel, updates local state, then advances the
  /// [PageView] to the next card (if one exists).
  void _changePage(int level, LevelDirection? direction) async {
    _progressEntity.level = level;
    _progressEntity.subLevel = ProgressEntity.initSubLevel;
    _progressEntity.modified = DateTimeUtil.now();
    await _progressRepository.merge(_progressEntity);
    setState(() {
      _level = _progressEntity.level;
      if (direction != null) _levelChangedMap[_cardEntity.id] = direction;
    });

    if (_index < _pairs.length - 1) {
      _pageController.animateToPage(
        _index + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // Last card — show completion dialog instead of closing the screen.
      if (!mounted) return;
      _showSessionCompleteDialog(context);
    }
  }

  /// Shows a "session complete" dialog at the end of the card deck.
  /// Offers to go back or stay on the last card.
  void _showSessionCompleteDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🎉', style: TextStyle(fontSize: 28)),
            SizedBox(width: 8),
            Text('Session Complete!'),
          ],
        ),
        content: Text(
          'You\'ve gone through all ${_pairs.length} card${_pairs.length == 1 ? '' : 's'} in this session.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  /// Returns the text currently shown on the card (matches [_getTextChild] / image-tab logic).
  String get _currentText {
    if (_isImageCard(_cardEntity)) {
      return (_langTabMap[_cardEntity.id] ?? 0) == 0
          ? _cardEntity.en
          : _cardEntity.de;
    }
    switch (widget.groupCode) {
      case GroupCode.faEn:
        return _languageCode == LanguageCode.fa
            ? _cardEntity.fa
            : _cardEntity.en;
      case GroupCode.enDe:
      case GroupCode.enDeVerbs:
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

  /// Returns the language the user should speak for this deck.
  /// faEn → always EN (learning English), enDe/enDeVerbs → always DE (learning German).
  /// Visual → matches the currently selected lang tab.
  LanguageCode get _sttLanguage {
    switch (widget.groupCode) {
      case GroupCode.faEn:
        return LanguageCode.en;
      case GroupCode.enDe:
      case GroupCode.enDeVerbs:
        return LanguageCode.de;
      case GroupCode.visual:
        return (_langTabMap[_cardEntity.id] ?? 0) == 0
            ? LanguageCode.en
            : LanguageCode.de;
    }
  }

  /// Returns the expected answer text matching [_sttLanguage].
  String get _sttExpected {
    switch (widget.groupCode) {
      case GroupCode.faEn:
        return _cardEntity.en;
      case GroupCode.enDe:
      case GroupCode.enDeVerbs:
        return _cardEntity.de;
      case GroupCode.visual:
        return (_langTabMap[_cardEntity.id] ?? 0) == 0
            ? _cardEntity.en
            : _cardEntity.de;
    }
  }

  /// Shows the live listening overlay dialog, starts STT, then evaluates result.
  Future<void> _onMicPressed(BuildContext context) async {
    if (_sttService.isListening.value) {
      await _sttService.stop();
      return;
    }
    if (_ttsService.isSpeaking.value) await _ttsService.stop();

    final expected = _sttExpected;
    final lang = _sttLanguage;

    final recognised = await _sttService.listen(
      lang,
      pauseMs: _settingsService.sttPauseMs.value,
    );

    if (!mounted) return;

    if (recognised == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not hear anything. Try again.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (sttMatches(recognised, expected,
        threshold: _settingsService.sttThreshold.value)) {
      // Only Play All grades the card (thumbs-up + level change).
      // Play Limited and per-level play just advance to the next card.
      final isGradedMode = widget.level == LeitnerScreen.allLevel;
      if (isGradedMode) {
        _changePage(_progressEntity.level + 1, LevelDirection.up);
      } else {
        _changePage(_progressEntity.level, null);
      }
      // Auto-restart listening for the next card — only if autoListen is on.
      if (!mounted) return;
      if (_settingsService.autoListen.value) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted &&
            _sttService.isAvailable &&
            !_sttService.isListening.value) {
          if (context.mounted) _onMicPressed(context);
        }
      }
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You said:  "$recognised"',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Text('Expected: "$expected"',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
      case GroupCode.enDeVerbs:
      case GroupCode.visual:
        _languageCode = _languageCode == LanguageCode.de
            ? LanguageCode.en
            : LanguageCode.de;
        break;
    }
    _changeValue(_index, _languageCode);
  }

  Widget _getTextChild(
      {required BuildContext context, required int pageIndex}) {
    String message = '';

    switch (widget.groupCode) {
      case GroupCode.faEn:
        message =
            _languageCode == LanguageCode.fa ? _cardEntity.fa : _cardEntity.en;
        break;
      case GroupCode.enDe:
      case GroupCode.enDeVerbs:
      case GroupCode.visual:
        message =
            _languageCode == LanguageCode.en ? _cardEntity.en : _cardEntity.de;
        break;
    }

    final textStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 28.0,
    );
    final textAlign = _languageCode.direction == TextDirection.rtl
        ? TextAlign.right
        : TextAlign.center;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: SingleChildScrollView(
        controller: _scrollControllerForIndex(pageIndex),
        child: Stack(
          children: [
            // Plain text with stable GlobalKey — OUTSIDE Obx so key never duplicates.
            Text.rich(
              key: _textKeyForIndex(pageIndex),
              TextSpan(text: message),
              textDirection: _languageCode.direction,
              textAlign: textAlign,
              style: textStyle,
            ),
            // Highlight overlay — reads boxes from the RenderParagraph above.
            Obx(() {
              final speaking = _ttsService.isSpeaking.value;
              final start = _ttsService.wordStart.value;
              final end = _ttsService.wordEnd.value;
              if (!speaking || end <= start || end > message.length) {
                return const SizedBox.shrink();
              }
              final primary = Theme.of(context).colorScheme.primary;
              return Positioned.fill(
                child: CustomPaint(
                  painter: _WordHighlightPainter(
                    textKey: _textKeyForIndex(pageIndex),
                    start: start,
                    end: end,
                    fillColor: primary.withValues(alpha: 0.28),
                    borderColor: primary.withValues(alpha: 0.55),
                  ),
                ),
              );
            }),
          ],
        ),
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
      return (keyValue == 'desc' &&
              (_cardEntity.desc.isEmpty ||
                  !_settingsService.descEnabled.value)) ||
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
      child: _isImageCard(card)
          ? _buildImageCardContent(card, pageIndex)
          : _buildCardContent(pageIndex),
    );
  }

  Widget _buildCardContent(int pageIndex) {
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
                // AnimatedSwitcher removed: keeping old+new _getTextChild alive
                // simultaneously causes duplicate GlobalKey and ScrollController
                // multi-attach errors (both share the same pageIndex-keyed resources).
                child: _getTextChild(context: context, pageIndex: pageIndex),
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

  /// Renders the image with a "tap to reveal" hint overlay before reveal, and
  /// a "tap to expand" hint badge after reveal.
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

  /// Builds the full card layout for an image card (Visual deck).
  ///
  /// Before reveal: image fills the card. After tap, the image shrinks to 45%
  /// and bilingual text + thumb buttons appear below.
  Widget _buildImageCardContent(CardEntity card, int pageIndex) {
    final progress = _pairs[pageIndex].$2;
    final revealed = _revealedSet.contains(card.id);
    final levelChanged = _levelChangedMap[card.id];
    final imageUrl = '$_imageBaseUrl/${card.image}';

    return Builder(
      builder: (context) => AnimatedGradientBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                // ── Image ──────────────────────────────────────────────────
                if (revealed)
                  GestureDetector(
                    onTap: () => _toggleReveal(card),
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
                      onTap: () => _toggleReveal(card),
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

                // ── Language toggle + scrollable text (after reveal) ───────
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
                    // AnimatedSwitcher intentionally removed: it kept both old and
                    // new SingleChildScrollView alive during the 250ms transition,
                    // causing duplicate GlobalKey and ScrollController multi-attach
                    // errors. Tab switching is instant with no perceptible delay.
                    child: SingleChildScrollView(
                      controller: _scrollControllerForIndex(pageIndex),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Builder(builder: (context) {
                        final message = (_langTabMap[card.id] ?? 0) == 0
                            ? card.en
                            : card.de;
                        final primary = Theme.of(context).colorScheme.primary;
                        // Text with GlobalKey is OUTSIDE Obx — key is stable
                        // across TTS rebuilds, preventing duplicate-key errors.
                        return Stack(
                          children: [
                            Text(
                              key: _textKeyForIndex(pageIndex),
                              message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.6,
                              ),
                            ),
                            Obx(() {
                              final speaking = _ttsService.isSpeaking.value;
                              final start = _ttsService.wordStart.value;
                              final end = _ttsService.wordEnd.value;
                              if (!speaking ||
                                  end <= start ||
                                  end > message.length) {
                                return const SizedBox.shrink();
                              }
                              return Positioned.fill(
                                child: CustomPaint(
                                  painter: _WordHighlightPainter(
                                    textKey: _textKeyForIndex(pageIndex),
                                    start: start,
                                    end: end,
                                    fillColor: primary.withValues(alpha: 0.28),
                                    borderColor:
                                        primary.withValues(alpha: 0.55),
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      }),
                    ),
                  ),
                ] else
                  const SizedBox.shrink(),

                // ── Thumb buttons (only shown after reveal) ────────────────
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
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => _settingsService.counterVisible.value
            ? Text(
                '${_index + 1} / ${_pairs.length}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              )
            : const SizedBox.shrink()),
        titleSpacing: 4,
        centerTitle: false,
        leading: InkWell(
          child: const Icon(Icons.arrow_back_ios),
          onTap: () => Navigator.of(context).pop(),
        ),
        actions: [
          Obx(() {
            if (!_settingsService.speakEnabled.value) {
              return const SizedBox.shrink();
            }
            final isImage = _isImageCard(_cardEntity);
            final revealed = !isImage || _revealedSet.contains(_cardEntity.id);
            return IconButton(
              icon: Icon(_ttsService.isSpeaking.value
                  ? Icons.stop_circle_outlined
                  : Icons.volume_up_outlined),
              tooltip: 'Speak',
              onPressed: revealed
                  ? () async {
                      if (_ttsService.isSpeaking.value) {
                        _ttsService.stop();
                      } else {
                        final lang = isImage
                            ? ((_langTabMap[_cardEntity.id] ?? 0) == 0
                                ? LanguageCode.en
                                : LanguageCode.de)
                            : _languageCode;
                        final ok = await _ttsService.speak(_currentText, lang);
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
                    }
                  : null,
            );
          }),
          Obx(() {
            if (!_settingsService.copyEnabled.value) {
              return const SizedBox.shrink();
            }
            final isImage = _isImageCard(_cardEntity);
            final revealed = !isImage || _revealedSet.contains(_cardEntity.id);
            return IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copy',
              onPressed: revealed ? () => _copyCurrentText(context) : null,
            );
          }),
          // Mic button — pulses red while listening, idle when not.
          Obx(() {
            if (!_settingsService.micEnabled.value) {
              return const SizedBox.shrink();
            }
            final isImage = _isImageCard(_cardEntity);
            final revealed = !isImage || _revealedSet.contains(_cardEntity.id);
            final listening = _sttService.isListening.value;
            final available = _sttService.isAvailable;
            final enabled = revealed && available;
            // _micPulse toggles between true/false on each animation end
            // to create a continuous oscillation only while listening.
            return TweenAnimationBuilder<double>(
              key: ValueKey(listening),
              tween: Tween(
                begin: listening ? (_micPulseFlip ? 1.4 : 1.0) : 1.0,
                end: listening ? (_micPulseFlip ? 1.0 : 1.4) : 1.0,
              ),
              duration: Duration(milliseconds: listening ? 550 : 200),
              curve: Curves.easeInOut,
              onEnd: listening
                  ? () => setState(() => _micPulseFlip = !_micPulseFlip)
                  : null,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: IconButton(
                icon: Icon(
                  listening ? Icons.mic : Icons.mic_none_outlined,
                  color: listening ? Colors.redAccent : null,
                ),
                tooltip: listening ? 'Stop listening' : 'Speak to answer',
                onPressed: enabled ? () => _onMicPressed(context) : null,
              ),
            );
          }),
        ],
      ),
      body: Listener(
        onPointerDown: (_) => _resetIdleTimer(),
        child: Stack(
          children: [
            // Pixel-shifted content — eases smoothly to new position over 3s
            TweenAnimationBuilder<Offset>(
              tween: Tween(end: Offset(_shiftX, _shiftY)),
              duration: const Duration(seconds: 3),
              curve: Curves.easeInOut,
              builder: (context, offset, child) =>
                  Transform.translate(offset: offset, child: child),
              child: GestureDetector(
                onVerticalDragEnd:
                    _isImageCard(_cardEntity) ? null : _onVerticalDragEnd,
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
