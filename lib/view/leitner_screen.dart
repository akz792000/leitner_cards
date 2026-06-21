import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
import '../service/study_log_service.dart';
import '../service/tts_service.dart';
import '../service/stt_service.dart';
import '../util/color_util.dart';
import '../util/date_time_util.dart';
import '../util/string_util.dart';
import '../enums/card_order.dart';
import 'widget/animated_gradient_background.dart';
import 'widget/animated_button.dart';
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
/// Handles all deck types: FA_EN, EN_DE, EN_DE_VERBS, and VISUAL.
///
/// [level] controls which cards are loaded:
/// - [allLevel] (-1): runs the full Leitner algorithm via [CardService].
/// - [allLimitedLevel] (-2): shows every card in the deck regardless of schedule.
/// - Any positive int: shows only cards at that exact level.
///
/// A language tab bar is shown on every card (unified for all deck types).
/// Tapping a tab switches the displayed language; the tab resets to the first
/// language on every card change. Visual-deck cards additionally show an image
/// that shrinks when tapped to reveal detail.
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

class _LeitnerScreenState extends State<LeitnerScreen>
    with WidgetsBindingObserver {
  static const String _imageBaseUrl =
      'https://raw.githubusercontent.com/akz792000/Dictionary/main/images';

  final CardRepository _cardRepository = Get.find<CardRepository>();
  final ProgressRepository _progressRepository = Get.find<ProgressRepository>();
  final CardService _cardService = Get.find<CardService>();
  final TtsService _ttsService = Get.find<TtsService>();
  final SttService _sttService = Get.find<SttService>();
  final SettingsService _settingsService = Get.find<SettingsService>();
  final StudyLogService _studyLogService = Get.find<StudyLogService>();
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
  int _activeTabIndex = 0; // index into _tabs; resets to 0 on each card change

  // Tracks whether the like/dislike button has been tapped for each card id.
  final Map<int, LevelDirection?> _levelChangedMap = {};
  // Snapshot of each card's level at the moment this session started —
  // used to prevent re-grading the same card if the screen is recreated.
  final Map<int, int> _initialLevels = {};
  final Set<int> _orderChangedSet = {};

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

  // Study-time tracking — paused when app goes to background.
  // _sessionStart is null while backgrounded; _accumulatedSecs holds time
  // already elapsed before the last background event.
  DateTime? _sessionStart;
  int _accumulatedSecs = 0;

  /// Date string (YYYY-MM-DD) when this study session began — used so that a
  /// session that started on day N and is persisted after midnight is still
  /// attributed to day N.
  late String _studyDate;

  /// True while the continuous STT loop is running (mic toggled on).
  bool _continuousMode = false;

  /// Dynamic dim delay driven by [SettingsService.dimDelayMin].
  Duration get _dimAfter =>
      Duration(minutes: _settingsService.dimDelayMin.value);
  static const _shiftInterval = Duration(seconds: 30);
  static const _maxShift = 2.0;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now(); // study-time: clock starts
    _studyDate = _studyLogService
        .dateKey(DateTimeUtil.now()); // lock date at session start
    WidgetsBinding.instance.addObserver(this);
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

  /// Moves elapsed foreground time into [_accumulatedSecs] and clears the
  /// start timestamp. Called on background and before saving in dispose().
  void _flushElapsed() {
    if (_sessionStart != null) {
      _accumulatedSecs += DateTime.now().difference(_sessionStart!).inSeconds;
      _sessionStart = null;
    }
  }

  /// Persists accumulated study time to both [SettingsService] (cumulative
  /// total) and [StudyLogService] (per-session log), then resets the counter.
  /// Resetting prevents double-counting if called from both [paused] and
  /// [dispose] within the same session.
  void _persistStudyTime() {
    if (_accumulatedSecs < 1) return;
    _settingsService.addStudyTime(
        widget.groupCode, Duration(seconds: _accumulatedSecs));
    _studyLogService.logSession(widget.groupCode, _accumulatedSecs,
        date: _studyDate);
    _accumulatedSecs = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Persist immediately so force-killing the app never loses study time.
      _flushElapsed();
      _persistStudyTime();
    } else if (state == AppLifecycleState.resumed) {
      // App returned to foreground — resume the timer.
      _sessionStart = DateTime.now();
    }
  }

  @override
  void dispose() {
    _continuousMode = false;
    WidgetsBinding.instance.removeObserver(this);
    // Flush and persist any remaining time (normal back-navigation, no pause).
    _flushElapsed();
    _persistStudyTime();
    _ttsScrollWorker?.dispose();
    for (final c in _textScrollControllers.values) {
      c.dispose();
    }
    _idleTimer?.cancel();
    _pixelShiftTimer?.cancel();
    _pageController.dispose();
    _ttsService.stop();
    _sttService.stop();
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
    // Apply two-level ordering from settings.
    // Primary: by level (cardOrder). Secondary: by subLevel within each level (subLevelOrder).
    final levelOrder = _settingsService.cardOrder.value;
    final subOrder = _settingsService.subLevelOrder.value;

    if (levelOrder == CardOrder.random) {
      // Random at the top level → shuffle everything.
      _pairs.shuffle();
    } else {
      // Sort by level first.
      _pairs.sort((a, b) => levelOrder == CardOrder.highFirst
          ? b.$2.level.compareTo(a.$2.level)
          : a.$2.level.compareTo(b.$2.level));

      if (subOrder == CardOrder.random) {
        // Random within each level group — shuffle each group in place.
        final Map<int, List<(CardEntity, ProgressEntity)>> byLevel = {};
        for (final p in _pairs) {
          (byLevel[p.$2.level] ??= []).add(p);
        }
        _pairs = [];
        final keys = byLevel.keys.toList()
          ..sort((a, b) => levelOrder == CardOrder.highFirst
              ? b.compareTo(a)
              : a.compareTo(b));
        for (final key in keys) {
          _pairs.addAll(byLevel[key]!..shuffle());
        }
      } else {
        // Sort by level then subLevel.
        _pairs.sort((a, b) {
          final levelCmp = levelOrder == CardOrder.highFirst
              ? b.$2.level.compareTo(a.$2.level)
              : a.$2.level.compareTo(b.$2.level);
          if (levelCmp != 0) return levelCmp;
          return subOrder == CardOrder.highFirst
              ? b.$2.subLevel.compareTo(a.$2.subLevel)
              : a.$2.subLevel.compareTo(b.$2.subLevel);
        });
      }
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

  /// Toggles the revealed state for [card] and resets the idle timer.
  // ── Language tab helpers ────────────────────────────────────────────────────

  /// Languages available as tabs for the current deck, in display order.
  List<LanguageCode> get _tabs {
    switch (widget.groupCode) {
      case GroupCode.faEn:
        return [LanguageCode.fa, LanguageCode.en];
      case GroupCode.enDe:
      case GroupCode.enDeVerbs:
      case GroupCode.visual:
        return [LanguageCode.en, LanguageCode.de];
    }
  }

  /// The language currently shown on the card.
  LanguageCode get _activeLanguage => _tabs[_activeTabIndex];

  /// The language the user is learning — always the last tab.
  /// EN for faEn, DE for enDe / enDeVerbs / visual.
  LanguageCode get _learningLanguage => _tabs.last;

  /// Accent colour for the active deck, used by the tab bar highlight.
  Color get _accentColor {
    switch (widget.groupCode) {
      case GroupCode.faEn:
        return Colors.blue.shade600;
      case GroupCode.enDe:
      case GroupCode.enDeVerbs:
        return Colors.orange.shade700;
      case GroupCode.visual:
        return Colors.teal.shade600;
    }
  }

  String _flagEmoji(LanguageCode lang) {
    switch (lang) {
      case LanguageCode.fa:
        return '🇮🇷';
      case LanguageCode.en:
        return '🇬🇧';
      case LanguageCode.de:
        return '🇩🇪';
    }
  }

  String _langLabel(LanguageCode lang) {
    switch (lang) {
      case LanguageCode.fa:
        return 'فارسی';
      case LanguageCode.en:
        return 'English';
      case LanguageCode.de:
        return 'Deutsch';
    }
  }

  /// Full-width pill-style tab bar for switching between languages.
  Widget _buildTabBar() {
    // Build individual tab items
    List<Widget> items = [];
    for (int i = 0; i < _tabs.length; i++) {
      final active = _activeTabIndex == i;
      final isFirst = i == 0;
      final isLast = i == _tabs.length - 1;

      items.add(
        Expanded(
          child: GestureDetector(
            onTap: () {
              _ttsService.stop();
              setState(() => _activeTabIndex = i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: active ? _accentColor : Colors.transparent,
                borderRadius: BorderRadius.horizontal(
                  left: isFirst ? const Radius.circular(8) : Radius.zero,
                  right: isLast ? const Radius.circular(8) : Radius.zero,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_flagEmoji(_tabs[i]),
                      style: TextStyle(fontSize: active ? 18 : 14)),
                  const SizedBox(width: 6),
                  Text(
                    _langLabel(_tabs[i]),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      color: active
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Insert level badge between the first and second tab
      if (i == 0 && _tabs.length > 1) {
        final base = _levelColor(_level);
        items.add(
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: base, width: 1.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_levelEmoji(_level), style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 5),
                Text(
                  'LVL $_level',
                  style: TextStyle(
                    color: base,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _accentColor.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: items),
      ),
    );
  }

  /// Increments [order] the first time a card is shown in this session.
  void _modifyOrder() async {
    if (!_orderChangedSet.contains(_cardEntity.id)) {
      _progressEntity.order++;
      _orderChangedSet.add(_cardEntity.id);
      await _progressRepository.merge(_progressEntity);
    }
  }

  void _changeValue(int index) {
    setState(() {
      _cardEntity = _pairs[index].$1;
      _progressEntity = _pairs[index].$2;
      _activeTabIndex = 0; // reset to first tab for every new card
      _level = _progressEntity.level;
    });
    // Auto-speak the card when the page changes, if enabled.
    if (_settingsService.autoSpeak.value &&
        _settingsService.speakEnabled.value) {
      _ttsService.speak(
          StringUtil.stripMarkdown(_currentText), _activeLanguage);
    }
  }

  void _onPageChanged(int value) {
    _ttsService.stop();
    _index = value;
    _changeValue(_index);
    _modifyOrder();
  }

  /// Programmatically moves to an adjacent language tab.
  /// [delta] is +1 (next tab) or -1 (previous tab), wrapping around.
  void _cycleTab(int delta) {
    if (_tabs.isEmpty) return;
    _ttsService.stop();
    setState(() {
      _activeTabIndex = (_activeTabIndex + delta + _tabs.length) % _tabs.length;
    });
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

  /// Returns the text currently shown on the card (driven by [_activeLanguage]).
  String get _currentText {
    switch (_activeLanguage) {
      case LanguageCode.fa:
        return _cardEntity.fa;
      case LanguageCode.en:
        return _cardEntity.en;
      case LanguageCode.de:
        return _cardEntity.de;
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
  /// Always targets [_learningLanguage]: EN for faEn, DE for enDe/enDeVerbs/visual.
  LanguageCode get _sttLanguage => _learningLanguage;

  /// Returns the expected answer text matching [_sttLanguage].
  String get _sttExpected {
    final raw = switch (_learningLanguage) {
      LanguageCode.en => _cardEntity.en,
      LanguageCode.fa => _cardEntity.fa,
      LanguageCode.de => _cardEntity.de,
    };
    // Strip markdown so STT compares against plain spoken words.
    return StringUtil.stripMarkdown(raw);
  }

  /// Toggles the continuous STT loop on/off.
  ///
  /// First press → starts the loop (keeps listening card-by-card until stopped).
  /// Second press → stops the loop and any active listen immediately.
  Future<void> _onMicPressed() async {
    if (_continuousMode) {
      setState(() => _continuousMode = false);
      await _sttService.stop();
      return;
    }
    if (_ttsService.isSpeaking.value) await _ttsService.stop();
    if (!mounted) return;
    setState(() => _continuousMode = true);
    await _runContinuousLoop();
  }

  /// Continuous STT loop — runs until [_continuousMode] is set to false or the
  /// deck ends.
  ///
  /// Correct answer: grade (Play All) or skip (other modes) → advance → next card.
  /// Wrong answer: show snackbar → advance without grading → next card.
  /// Nothing heard: brief pause and retry for the same card.
  Future<void> _runContinuousLoop() async {
    while (_continuousMode && mounted) {
      // Ensure TTS is silent before listening.
      if (_ttsService.isSpeaking.value) await _ttsService.stop();

      final expected = _sttExpected;
      final lang = _sttLanguage;

      final recognised = await _sttService.listen(
        lang,
        pauseMs: _settingsService.sttPauseMs.value,
        stabilityMs: _settingsService.sttStabilityMs.value,
      );

      if (!mounted || !_continuousMode) break;

      if (recognised == null || recognised.trim().isEmpty) {
        // Nothing heard — short pause, then retry same card.
        await Future.delayed(const Duration(milliseconds: 300));
        continue;
      }

      final matched = sttMatches(
        recognised,
        expected,
        threshold: _settingsService.sttThreshold.value,
        containsMode: _settingsService.containsMode.value,
      );

      final isLastCard = _index >= _pairs.length - 1;

      if (matched) {
        final isGradedMode = widget.level == LeitnerScreen.allLevel;
        if (isGradedMode) {
          _changePage(_progressEntity.level + 1, LevelDirection.up);
        } else {
          _changePage(_progressEntity.level, null);
        }
        if (isLastCard) {
          // _changePage already shows the session-complete dialog.
          setState(() => _continuousMode = false);
          break;
        }
        // Wait for the page-flip animation + _onPageChanged to update state.
        await Future.delayed(const Duration(milliseconds: 700));
      } else {
        // Wrong — show snackbar, stop the loop, stay on the same card.
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ));
        }
        // Stop the continuous loop — user must press mic again to continue.
        setState(() => _continuousMode = false);
        break;
      }
    }

    if (mounted) setState(() => _continuousMode = false);
  }

  Widget _getTextChild(
      {required BuildContext context, required int pageIndex}) {
    final message = _currentText;
    final cs = Theme.of(context).colorScheme;
    final isRtl = _activeLanguage.direction == TextDirection.rtl;
    final hasMarkdown = StringUtil.containsMarkdown(message);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: SingleChildScrollView(
        controller: _scrollControllerForIndex(pageIndex),
        child: hasMarkdown
            ? Directionality(
                textDirection: _activeLanguage.direction,
                child: MarkdownBody(
                  data: message,
                  styleSheet:
                      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: TextStyle(
                      color: cs.onSurface,
                      fontSize: 24.0,
                    ),
                    tableHead: TextStyle(
                      color: cs.onSurface,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                    tableBody: TextStyle(
                      color: cs.onSurface,
                      fontSize: 18.0,
                    ),
                    tableBorder: TableBorder.all(
                      color: cs.outlineVariant,
                      width: 1,
                    ),
                    tableColumnWidth: const FlexColumnWidth(),
                    blockquoteDecoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border(left: BorderSide(color: cs.primary, width: 3)),
                    ),
                  ),
                  selectable: true,
                ),
              )
            : Stack(
                children: [
                  // Plain text with stable GlobalKey for word-highlight painter.
                  Text.rich(
                    key: _textKeyForIndex(pageIndex),
                    TextSpan(text: message),
                    textDirection: _activeLanguage.direction,
                    textAlign: isRtl ? TextAlign.right : TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 28.0,
                    ),
                  ),
                  // Word-highlight overlay (TTS progress).
                  Obx(() {
                    final speaking = _ttsService.isSpeaking.value;
                    final start = _ttsService.wordStart.value;
                    final end = _ttsService.wordEnd.value;
                    if (!speaking || end <= start || end > message.length) {
                      return const SizedBox.shrink();
                    }
                    final primary = cs.primary;
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

    // Remove buttons that shouldn't show
    result.removeWhere((element) {
      if (element.key == null) return false;
      final keyValue = (element.key as ValueKey).value;
      return keyValue == 'like' && widget.level != LeitnerScreen.allLevel;
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
      child: _buildCardContent(card, pageIndex),
    );
  }

  /// Unified card layout for all deck types.
  ///
  /// Returns the animal emoji for a given level (weakest→strongest).
  String _levelEmoji(int level) {
    const emojis = [
      '🐛',
      '🐌',
      '🐁',
      '🐇',
      '🦔',
      '🦊',
      '🐺',
      '🐗',
      '🐆',
      '🦁',
      '🐯',
      '🦅',
      '🦈',
      '🦏',
      '🐘',
      '🐉',
    ];
    return emojis[level.clamp(0, emojis.length - 1)];
  }

  /// Returns the accent colour for a given level (16-step rainbow palette),
  /// adapted to current theme brightness for readability.
  Color _levelColor(int level) =>
      ColorUtil.levelColor(level, Theme.of(context).brightness);

  /// Builds the card content — identical layout for all decks:
  /// tab bar → image (visual only) → text → thumb buttons.
  /// The GestureDetector wraps the whole page so vertical swipes anywhere
  /// cycle the language tab; horizontal swipes go to the PageView.
  Widget _buildCardContent(CardEntity card, int pageIndex) {
    return Builder(
      builder: (context) => GestureDetector(
        onVerticalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -300) _cycleTab(1); // swipe up   → next tab
          if (v > 300) _cycleTab(-1); // swipe down → prev tab
        },
        child: AnimatedGradientBackground(
          child: Column(
            children: [
              // Language tab bar with level badge — same for all decks
              _buildTabBar(),

              // Image (Visual deck only) — shown above the translation
              if (card.image.isNotEmpty)
                Container(
                  height: 180,
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    '$_imageBaseUrl/${card.image}',
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
                    errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.white38)),
                  ),
                ),

              // Card text
              Expanded(
                child: Center(
                  child: _getTextChild(context: context, pageIndex: pageIndex),
                ),
              ),

              // Thumb buttons
              Padding(
                padding: const EdgeInsets.all(28.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _bottomBar(),
                ),
              ),
            ],
          ),
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
          // Description — only shown when card has a desc
          if (_cardEntity.desc.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Description',
              onPressed: () => DescriptionSheet.show(context,
                  card: _cardEntity, groupCode: widget.groupCode),
            ),
          Obx(() {
            if (!_settingsService.speakEnabled.value) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: Icon(_ttsService.isSpeaking.value
                  ? Icons.stop_circle_outlined
                  : Icons.volume_up_outlined),
              tooltip: 'Speak',
              onPressed: () async {
                if (_ttsService.isSpeaking.value) {
                  _ttsService.stop();
                } else {
                  final ok = await _ttsService.speak(
                      StringUtil.stripMarkdown(_currentText), _activeLanguage);
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
            );
          }),
          // Mic button — red/pulsing while continuous loop is active or actively listening.
          Obx(() {
            if (!_settingsService.micEnabled.value) {
              return const SizedBox.shrink();
            }
            final listening = _sttService.isListening.value;
            final active = _continuousMode || listening;
            final available = _sttService.isAvailable;
            // _micPulse toggles between true/false on each animation end
            // to create a continuous oscillation only while active.
            return TweenAnimationBuilder<double>(
              key: ValueKey(active),
              tween: Tween(
                begin: active ? (_micPulseFlip ? 1.4 : 1.0) : 1.0,
                end: active ? (_micPulseFlip ? 1.0 : 1.4) : 1.0,
              ),
              duration: Duration(milliseconds: active ? 550 : 200),
              curve: Curves.easeInOut,
              onEnd: active
                  ? () => setState(() => _micPulseFlip = !_micPulseFlip)
                  : null,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: IconButton(
                icon: Icon(
                  active ? Icons.mic : Icons.mic_none_outlined,
                  color: active ? Colors.redAccent : null,
                ),
                tooltip: _continuousMode ? 'Stop listening' : 'Speak to answer',
                onPressed: available ? () => _onMicPressed() : null,
              ),
            );
          }),
          Obx(() {
            if (!_settingsService.copyEnabled.value) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copy',
              onPressed: () => _copyCurrentText(context),
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
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pairs.length,
                itemBuilder: (context, index) =>
                    _buildCardPage(_pairs[index].$1, index),
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
