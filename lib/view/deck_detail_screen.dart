import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/route_config.dart';
import '../entity/card_entity.dart';
import '../entity/deck_entity.dart';
import '../enums/group_code.dart';
import '../repository/card_repository.dart';
import '../repository/deck_repository.dart';
import '../repository/progress_repository.dart';
import '../service/route_service.dart';
import '../service/sync_service.dart';
import '../util/color_util.dart';
import '../util/dialog_util.dart';

/// Detail screen for a single deck — lists cards with add, edit, delete.
///
/// Reuses [PersistScreen] for adding and [MergeScreen] for editing cards.
/// Tap the edit icon in the AppBar to rename, change icon, or change color.
/// For legacy decks, cards are queried by [GroupCode]; for user-created
/// decks, cards are queried by deckId stored in [CardEntity.groupCode].
class DeckDetailScreen extends StatefulWidget {
  final String deckId;

  const DeckDetailScreen({super.key, required this.deckId});

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  final _cardRepo = Get.find<CardRepository>();
  final _deckRepo = Get.find<DeckRepository>();
  final _progressRepo = Get.find<ProgressRepository>();
  final _syncService = Get.find<SyncService>();

  DeckEntity? get _deck => _deckRepo.findById(widget.deckId);

  late List<CardEntity> _cards;
  late Map<int, int> _levelMap;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final deck = _deck;
    if (deck == null) {
      _cards = [];
      _levelMap = {};
      return;
    }
    if (deck.groupCode.isNotEmpty) {
      _cards = _cardRepo.findAllByGroupCode(GroupCode.fromCode(deck.groupCode));
    } else {
      _cards = _cardRepo
          .findAll()
          .where((c) => c.groupCode == widget.deckId)
          .toList();
    }
    _levelMap = {
      for (final c in _cards) c.id: _progressRepo.findOrCreate(c.id).level
    };
  }

  Color get _deckColor => Color(_deck?.colorValue ?? 0xFF1565C0);

  void _navigateToAdd() {
    final deck = _deck;
    if (deck == null) return;
    Get.find<RouteService>().pushNamed(RouteConfig.persist,
        arguments: {'deck': deck}).then((_) => setState(() => _refresh()));
  }

  void _navigateToEdit(CardEntity card) {
    final deck = _deck;
    if (deck == null) return;
    Get.find<RouteService>().pushNamed(RouteConfig.merge, arguments: {
      'cardEntity': card,
      'deck': deck
    }).then((_) => setState(() => _refresh()));
  }

  Future<void> _onRemoveAll() async {
    if (_cards.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All'),
        content: Text(
            'Delete all ${_cards.length} cards and their progress?\n\nThis cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _syncService.removeCards(_cards, withProgress: true);
      setState(() => _refresh());
    } catch (e) {
      if (mounted) DialogUtil.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deck = _deck;
    if (deck == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Deck not found')),
        body: const Center(child: Text('This deck no longer exists.')),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(deck.name),
        backgroundColor: _deckColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if (_cards.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Delete all cards',
              onPressed: _onRemoveAll,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'AddCard',
        backgroundColor: _deckColor,
        foregroundColor: Colors.white,
        onPressed: _navigateToAdd,
        child: const Icon(Icons.add),
      ),
      body: _cards.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.note_add_outlined,
                        size: 72, color: cs.outlineVariant),
                    const SizedBox(height: 20),
                    Text('No cards yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        )),
                    const SizedBox(height: 8),
                    Text('Tap + to add your first flashcard',
                        style: TextStyle(
                            fontSize: 14, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  color: _deckColor.withAlpha(20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.style_outlined, size: 16, color: _deckColor),
                      const SizedBox(width: 6),
                      Text(
                        '${_cards.length} card${_cards.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _deckColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 6, bottom: 88),
                    itemCount: _cards.length,
                    itemBuilder: (context, index) =>
                        _buildCardRow(_cards[index], index),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCardRow(CardEntity card, int index) {
    final deck = _deck!;
    final level = _levelMap[card.id] ?? 0;
    final color = ColorUtil.levelColor(level, Theme.of(context).brightness);
    final front = _frontText(card, deck);
    final back = _backText(card, deck);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(front,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  if (back.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      back,
                      style: TextStyle(
                          fontSize: 14,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      textDirection: deck.targetLang == 'fa'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withAlpha(80)),
            ),
            child: Text('L$level',
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.edit_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20),
            onPressed: () => _navigateToEdit(card),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  String _frontText(CardEntity card, DeckEntity deck) {
    if (deck.sourceLang == 'fa') return card.fa.isNotEmpty ? card.fa : card.en;
    if (deck.sourceLang == 'de') return card.de.isNotEmpty ? card.de : card.en;
    return card.en;
  }

  String _backText(CardEntity card, DeckEntity deck) {
    if (deck.targetLang == 'fa') return card.fa.isNotEmpty ? card.fa : card.en;
    if (deck.targetLang == 'de') return card.de.isNotEmpty ? card.de : card.en;
    if (deck.targetLang == 'en') return card.en;
    return card.desc.isNotEmpty ? card.desc : card.en;
  }
}
