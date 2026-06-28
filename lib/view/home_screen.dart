import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_theme.dart';
import '../config/route_config.dart';
import '../entity/card_entity.dart';
import '../entity/deck_entity.dart';
import '../enums/group_code.dart';
import '../repository/card_repository.dart';
import '../repository/deck_repository.dart';
import '../service/route_service.dart';
import 'app_drawer.dart';

/// App home screen — displays the user's decks dynamically from Hive.
///
/// Intentionally has no [AppBar]; the gradient header contains the burger-menu
/// button. Decks are read from [DeckRepository] and rendered as cards.
/// A floating action button allows creating new decks.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Get.find<RouteService>().pushNamed(RouteConfig.createDeck),
        icon: const Icon(Icons.add),
        label: const Text('New Deck'),
      ),
      body: Builder(
        builder: (context) => Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ValueListenableBuilder<Box<DeckEntity>>(
                valueListenable: Get.find<DeckRepository>().listenable(),
                builder: (context, deckBox, _) {
                  return ValueListenableBuilder<Box<CardEntity>>(
                    valueListenable: Get.find<CardRepository>().listenable(),
                    builder: (context, cardBox, _) {
                      final decks = Get.find<DeckRepository>().findAll();
                      if (decks.isEmpty) {
                        return _buildEmptyState(context);
                      }
                      return _buildDeckList(context, decks);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckList(BuildContext context, List<DeckEntity> decks) {
    final cardRepo = Get.find<CardRepository>();
    final deckRepo = Get.find<DeckRepository>();
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.all(20),
      itemCount: decks.length + 1, // +1 for bottom spacer
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          elevation: 4,
          borderRadius: BorderRadius.circular(16),
          child: child,
        );
      },
      onReorderItem: (oldIndex, newIndex) {
        if (oldIndex >= decks.length || newIndex >= decks.length) return;
        final moved = decks.removeAt(oldIndex);
        decks.insert(newIndex, moved);
        for (var i = 0; i < decks.length; i++) {
          decks[i].sortOrder = i;
          deckRepo.merge(decks[i]);
        }
      },
      itemBuilder: (context, index) {
        if (index == decks.length) {
          return SizedBox(key: const ValueKey('_spacer'), height: 80);
        }
        return Padding(
          key: ValueKey(decks[index].id),
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildDeckCard(context, decks[index], cardRepo, index),
        );
      },
    );
  }

  Widget _buildDeckCard(BuildContext context, DeckEntity deck,
      CardRepository cardRepo, int index) {
    final color = Color(deck.colorValue);
    final lighterColor = Color.lerp(color, Colors.white, 0.3) ?? color;

    // Card count: legacy decks use GroupCode, user-created decks use deckId.
    final int cardCount;
    if (deck.groupCode.isNotEmpty) {
      final gc = GroupCode.fromCode(deck.groupCode);
      cardCount = cardRepo.findAllByGroupCode(gc).length;
    } else {
      cardCount =
          cardRepo.findAll().where((c) => c.groupCode == deck.id).length;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, lighterColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(100),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Deck body — tap to open, long-press to drag/reorder.
          Expanded(
            child: ReorderableDelayedDragStartListener(
              index: index,
              child: GestureDetector(
                onTap: () => _onDeckTap(deck),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        // ignore: non_const_argument_for_const_parameter
                        child: Icon(
                          IconData(deck.iconCodePoint,
                              fontFamily: 'MaterialIcons'),
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deck.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$cardCount cards · ${deck.groupCode.isNotEmpty ? deck.groupCode : '${deck.sourceLang.toUpperCase()}_${deck.targetLang.toUpperCase()}'}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Edit button.
          GestureDetector(
            onTap: () => Get.find<RouteService>().pushNamed(
              RouteConfig.editDeck,
              arguments: {'deckId': deck.id},
            ),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_outlined,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDeckTap(DeckEntity deck) {
    // Legacy decks pass GroupCode for full play support;
    // all decks pass deckId for card editing and deck-aware UI.
    final groupCode =
        deck.groupCode.isNotEmpty ? GroupCode.fromCode(deck.groupCode) : null;
    Get.find<RouteService>().pushNamed(
      RouteConfig.level,
      arguments: {
        if (groupCode != null) 'groupCode': groupCode,
        'deckId': deck.id,
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style_outlined, size: 80, color: cs.outlineVariant),
            const SizedBox(height: 24),
            Text(
              'No decks yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "New Deck" to create your first flashcard deck',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: topPadding, left: 8, right: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SizedBox(
        height: AppTheme.toolbarHeight,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 26),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Menu',
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.school, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to learn today?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Hold to reorder',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
