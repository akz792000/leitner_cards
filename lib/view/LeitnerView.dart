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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.linear,
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

  TextSpan _buildWordSpan(String word) {
    return TextSpan(
      text: word,
      style: const TextStyle(color: Colors.black, fontSize: 30.0),
    );
  }

  Widget _getTextChild() {
    String message = '';

    switch (widget.groupCode) {
      case GroupCode.english:
        message = _languageCode == LanguageCode.fa ? _cardEntity.fa : _cardEntity.en;
        break;
      case GroupCode.deutsch:
        message = _languageCode == LanguageCode.en ? _cardEntity.en : _cardEntity.de;
        break;
    }

    final words = message.split(' ');
    final children = <TextSpan>[];

    for (var i = 0; i < words.length; i++) {
      if (i != 0) children.add(const TextSpan(text: ' '));
      children.add(_buildWordSpan(words[i]));
    }

    return RichText(
      textDirection: _languageCode.direction,
      text: TextSpan(children: children),
    );
  }

  List<Widget> _bottomBar() {
    final levelChanged = _levelChangedMap[_cardEntity.id];

    final result = [
      // Dislike
      AnimatedButton(
        icon: levelChanged == LevelDirection.up
            ? const Icon(Icons.thumb_down, size: 30, color: Colors.red)
            : const Icon(Icons.thumb_down_outlined, size: 30),
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
        icon: levelChanged == LevelDirection.down
            ? const Icon(Icons.thumb_up_alt, size: 30, color: Colors.green)
            : const Icon(Icons.thumb_up_alt_outlined, size: 30),
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

  Widget _buildCardPage(CardEntity card) {
    return AnimatedGradientBackground(
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
            child: Center(child: _getTextChild()),
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
      body: GestureDetector(
        onVerticalDragEnd: _onVerticalDragEnd,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: _cards.length,
          itemBuilder: (context, index) => _buildCardPage(_cards[index]),
        ),
      ),
    );
  }
}
