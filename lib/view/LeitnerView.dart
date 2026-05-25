import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/entity/CardEntity.dart';
import 'package:leitner_cards/service/CardService.dart';
import 'package:leitner_cards/repository/CardRepository.dart';
import 'package:leitner_cards/view/widget/IconButtonWidget.dart';

import '../config/RouteConfig.dart';
import '../enums/LanguageCode.dart';
import '../enums/GroupCode.dart';
import '../enums/LevelDirection.dart';
import '../service/RouteService.dart';
import '../service/SyncService.dart';
import '../util/DateTimeUtil.dart';
import '../util/DialogUtil.dart';
import 'widget/animated_gradient_background.dart';
import 'widget/animated_button.dart';
import 'widget/animated_flag.dart';

class LeitnerView extends StatefulWidget {
  static const int allLevel = -1;
  static const int allLimitedLevel = -2;

  final GroupCode groupCode;
  final int level;

  const LeitnerView({
    super.key,
    required this.groupCode,
    required this.level,
  });

  @override
  State<LeitnerView> createState() => _LeitnerViewState();
}

class _LeitnerViewState extends State<LeitnerView> {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final CardService _cardService = Get.find<CardService>();
  final PageController _pageController = PageController(initialPage: 0, keepPage: true);

  late List<CardEntity> _cards;
  late CardEntity _cardEntity;
  int _index = 0;
  int _level = 1;
  late LanguageCode _languageCode;

  // Per-card transient UI state (not persisted)
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
    if (_cards.isNotEmpty) {
      _cardEntity = _cards[0];
      _level = _cardEntity.level;
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
      case GroupCode.english:
        return LanguageCode.fa;
      case GroupCode.deutsch:
        return LanguageCode.en;
    }
  }

  void _loadCards() {
    switch (widget.level) {
      case LeitnerView.allLevel:
        _cards = _cardService.findAllBasedOnLeitner(widget.groupCode);
        break;
      case LeitnerView.allLimitedLevel:
        _cards = _cardRepository.findAllByGroupCode(widget.groupCode);
        break;
      default:
        _cards = _cardRepository.findAllByLevelAndGroupCode(widget.level, widget.groupCode);
        break;
    }
  }

  void _modifyOrder() async {
    if (!_orderChangedSet.contains(_cardEntity.id)) {
      _cardEntity.order++;
      _orderChangedSet.add(_cardEntity.id);
      await _cardRepository.merge(_cardEntity);
    }
  }

  void _changeValue(int index, LanguageCode languageCode) {
    setState(() {
      _cardEntity = _cards[index];
      _languageCode = languageCode;
      _level = _cardEntity.level;
    });
  }

  void _onPageChanged(int value) {
    _index = value;
    _changeValue(_index, _getInitialLanguageCode());
    _modifyOrder();
  }

  void _changePage(int level, LevelDirection direction) async {
    _cardEntity.level = level;
    _cardEntity.subLevel = CardEntity.initSubLevel;
    _cardEntity.modified = DateTimeUtil.now();
    await _cardRepository.merge(_cardEntity);
    setState(() {
      _level = _cardEntity.level;
      _levelChangedMap[_cardEntity.id] = direction;
    });

    // Silently push progress to Supabase in the background
    Get.find<SyncService>().pushProgress(_cardEntity);

    if (_index < _cards.length - 1) {
      _pageController.animateToPage(
        _index + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    switch (widget.groupCode) {
      case GroupCode.english:
        _languageCode = _languageCode == LanguageCode.en ? LanguageCode.fa : LanguageCode.en;
        break;
      case GroupCode.deutsch:
        _languageCode = _languageCode == LanguageCode.de ? LanguageCode.en : LanguageCode.de;
        break;
    }
    _changeValue(_index, _languageCode);
  }

  Widget _getTextChild({required BuildContext context}) {
    String message = '';

    switch (widget.groupCode) {
      case GroupCode.english:
        message = _languageCode == LanguageCode.fa ? _cardEntity.fa : _cardEntity.en;
        break;
      case GroupCode.deutsch:
        message = _languageCode == LanguageCode.en ? _cardEntity.en : _cardEntity.de;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: SingleChildScrollView(
        child: Text(
          message,
          textDirection: _languageCode.direction,
          textAlign: _languageCode.direction == TextDirection.rtl
              ? TextAlign.right
              : TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 28.0,
          ),
        ),
      ),
    );
  }

  List<Widget> _bottomBar() {
    final levelChanged = _levelChangedMap[_cardEntity.id];

    final result = [
      // Dislike
      AnimatedButton(
        icon: const Icon(Icons.thumb_down_outlined, size: 30, color: Colors.white),
        isActive: levelChanged == LevelDirection.down,
        activeColor: Colors.redAccent,
        onPressed: levelChanged == LevelDirection.down
            ? null
            : () => _changePage(CardEntity.initLevel, LevelDirection.down),
        key: const ValueKey("dislike"),
      ),
      // Description
      IconButtonWidget(
        const Icon(Icons.light_mode_outlined, size: 30),
        onPressed: _cardEntity.desc.isEmpty
            ? null
            : () => DialogUtil.ok(context, title: "Description", description: _cardEntity.desc),
        key: const ValueKey("desc"),
      ),
      // Like
      AnimatedButton(
        icon: const Icon(Icons.thumb_up_alt_outlined, size: 30, color: Colors.white),
        isActive: levelChanged == LevelDirection.up,
        activeColor: Colors.green,
        onPressed: levelChanged == LevelDirection.up
            ? null
            : () => _changePage(_cardEntity.level + 1, LevelDirection.up),
        key: const ValueKey("like"),
      ),
    ];

    // Remove buttons that shouldn't show
    result.removeWhere((element) {
      final keyValue = (element.key as ValueKey).value;
      return (keyValue == 'desc' && _cardEntity.desc.isEmpty) ||
          (keyValue == 'like' && widget.level != LeitnerView.allLevel);
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
            child: Text('Level: $_level', style: const TextStyle(fontSize: 30)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 2),
            child: AnimatedFlag(imagePath: 'assets/flags/${_languageCode.name}.png'),
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
        title: Text('Item ${_index + 1} of ${_cards.length}'),
        centerTitle: true,
        leading: InkWell(
          child: const Icon(Icons.arrow_back_ios),
          onTap: () async => await Get.find<RouteService>().pushReplacementNamed(
            RouteConfig.level,
            arguments: {"groupCode": widget.groupCode},
          ),
        ),
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
                  itemCount: _cards.length,
                  itemBuilder: (context, index) => _buildCardPage(_cards[index], index),
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
