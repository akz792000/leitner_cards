import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/repository/CardRepository.dart';

import '../config/RouteConfig.dart';
import '../entity/CardEntity.dart';
import '../enums/GroupCode.dart';
import '../service/RouteService.dart';
import '../service/SyncService.dart';
import '../util/DialogUtil.dart';

class DataView extends StatefulWidget {
  final GroupCode groupCode;

  const DataView({super.key, required this.groupCode});

  @override
  _DataViewState createState() => _DataViewState();
}

class _DataViewState extends State<DataView> {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final SyncService _syncService = Get.find<SyncService>();
  late List<CardEntity> _cardEntities;

  bool get _isEnglish => widget.groupCode == GroupCode.english;
  Color get _accentColor => _isEnglish ? Colors.blue.shade600 : Colors.orange.shade700;

  void _initialize() {
    setState(() {
      _cardEntities = _cardRepository.findAllByGroupCode(widget.groupCode);
    });
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Color _levelColor(int level) {
    if (level == 0) return Colors.red.shade400;
    if (level <= 2) return Colors.orange.shade400;
    if (level <= 4) return Colors.amber.shade600;
    return Colors.green.shade500;
  }

  void _onRemove(CardEntity cardEntity) {
    DialogUtil.okCancel(
      context,
      title: "Delete Card",
      description: "Delete '${cardEntity.en}'?",
      onOk: () async {
        try {
          await _syncService.removeCard(cardEntity);
          _initialize();
        } catch (e) {
          if (mounted) DialogUtil.error(context, e);
        }
      },
    );
  }

  void _onRemoveAll() {
    if (_cardEntities.isEmpty) {
      DialogUtil.ok(context, title: "Nothing to delete", description: "There are no cards in this deck.");
      return;
    }
    DialogUtil.okCancel(
      context,
      title: "Delete All",
      description: "Delete all ${_cardEntities.length} cards?",
      onOk: () async {
        try {
          await _syncService.removeCards(_cardEntities);
          _initialize();
        } catch (e) {
          if (mounted) DialogUtil.error(context, e);
        }
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.style_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No cards yet', style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('Tap + to add your first card', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildCardRow(CardEntity card, int index) {
    final color = _levelColor(card.level);
    final secondaryText = _isEnglish ? card.fa : card.de;

    return InkWell(
      onTap: () => Get.find<RouteService>()
          .pushNamed(RouteConfig.merge, arguments: {"cardEntity": card})
          .then((_) => _initialize()),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 64,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.en,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (secondaryText.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        secondaryText,
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        textDirection: _isEnglish ? TextDirection.rtl : TextDirection.ltr,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withAlpha(80)),
              ),
              child: Text('L${card.level}', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
              onPressed: () => _onRemove(card),
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
        title: Text('${widget.groupCode.title} Cards'),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: InkWell(
          child: const Icon(Icons.arrow_back_ios),
          onTap: () => Get.find<RouteService>().pushReplacementNamed(
            RouteConfig.level,
            arguments: {"groupCode": widget.groupCode},
          ),
        ),
        actions: [
          if (_cardEntities.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Delete all',
              onPressed: _onRemoveAll,
            ),
        ],
      ),
      body: _cardEntities.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                Container(
                  color: _accentColor.withAlpha(20),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.style_outlined, size: 16, color: _accentColor),
                      const SizedBox(width: 6),
                      Text(
                        '${_cardEntities.length} card${_cardEntities.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: _cardEntities.length,
                    itemBuilder: (context, index) => _buildCardRow(_cardEntities[index], index),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'Add',
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        onPressed: () => Get.find<RouteService>()
            .pushNamed(RouteConfig.persist, arguments: {"groupCode": widget.groupCode})
            .then((_) => _initialize()),
        child: const Icon(Icons.add),
      ),
    );
  }
}
