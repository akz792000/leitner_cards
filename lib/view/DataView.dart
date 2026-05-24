import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/repository/CardRepository.dart';

import '../config/RouteConfig.dart';
import '../entity/CardEntity.dart';
import '../enums/GroupCode.dart';
import '../helper/ListNotifierHelper.dart';
import '../service/RouteService.dart';
import '../util/DialogUtil.dart';

class DataView extends StatefulWidget {
  final GroupCode groupCode;

  const DataView({super.key, required this.groupCode});

  @override
  _DataViewState createState() => _DataViewState();
}

class _DataViewState extends State<DataView> {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  late List<CardEntity> _cardEntities;

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

  void _onRemove(CardEntity cardEntity) {
    DialogUtil.okCancel(
      context,
      title: "Delete Item",
      description: "Do you want to delete '${cardEntity.en}'?",
      onOk: () async {
        await _cardRepository.remove(cardEntity);
        _initialize();
      },
    );
  }

  void _onRemoveAll() {
    if (_cardEntities.isEmpty) {
      DialogUtil.ok(
        context,
        title: "Alert",
        description: "There is no item to remove",
      );
      return;
    }

    DialogUtil.okCancel(
      context,
      title: "Delete All",
      description: "Do you want to delete all items?",
      onOk: () async {
        await _cardRepository.removeList(_cardEntities);
        _initialize();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            "${widget.groupCode.getTitle()} Data Cards: ${_cardEntities.length}"),
        leading: InkWell(
          child: const Icon(Icons.arrow_back_ios),
          onTap: () => Get.find<RouteService>().pushReplacementNamed(
            RouteConfig.level,
            arguments: {"groupCode": widget.groupCode},
          ),
        ),
      ),
      body: ValueListenableBuilder<List>(
        valueListenable: ListNotifierHelper(_cardEntities),
        builder: (context, cardEntities, _) {
          if (cardEntities.isEmpty) {
            return const Center(child: Text('Empty'));
          }

          return ListView.builder(
            itemCount: cardEntities.length,
            itemBuilder: (context, index) {
              final card = cardEntities[index];
              return Container(
                color: (index % 2 == 0) ? Colors.white : Colors.blue[100],
                child: InkWell(
                  onTap: () => Get.find<RouteService>()
                      .pushNamed(RouteConfig.merge, arguments: {
                    "cardEntity": card,
                  }).then((_) => _initialize()),
                  child: ListTile(
                    title: Text(card.en),
                    subtitle: Text(
                        "Level: ${card.level} - SubLevel: ${card.subLevel} - Order: ${card.order}"),
                    trailing: IconButton(
                      onPressed: () => _onRemove(card),
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        heroTag: 'Add',
        onPressed: () => Get.find<RouteService>()
            .pushNamed(RouteConfig.persist, arguments: {
          "groupCode": widget.groupCode,
        }).then((_) => _initialize()),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
              child: TextButton(
                onPressed: _onRemoveAll,
                child: const Icon(Icons.delete, color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
