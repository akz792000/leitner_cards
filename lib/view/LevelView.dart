import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/enums/GroupCode.dart';
import 'package:leitner_cards/model/OptionModel.dart';
import 'package:leitner_cards/repository/CardRepository.dart';
import 'package:leitner_cards/view/LeitnerView.dart';

import '../config/RouteConfig.dart';
import '../service/RouteService.dart';

class LevelView extends StatefulWidget {
  final GroupCode groupCode;

  const LevelView({super.key, required this.groupCode});

  @override
  State<LevelView> createState() => _LevelViewState();
}

class _LevelViewState extends State<LevelView> {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  late int _count;
  int _selectedOption = 0;
  late final List<OptionModel> _optionModels;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    _count = _cardRepository.findAllByGroupCode(widget.groupCode).length;
    final levelMap = _cardRepository.findAllLevelBasedByGroupCode(widget.groupCode);

    _optionModels = levelMap.entries.map((entry) {
      return OptionModel(
        level: entry.key,
        image: Image.asset('assets/levels/${entry.key}.png'),
        title: "Level ${entry.key}",
        subtitle: "Items: ${entry.value}",
      );
    }).toList();
  }

  List<Widget> _buildBottomBar() {
    final buttons = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
        child: TextButton(
          onPressed: () async {
            await Get.find<RouteService>().pushReplacementNamed(
              RouteConfig.data,
              arguments: {"groupCode": widget.groupCode},
            );
          },
          child: const Icon(Icons.text_snippet_outlined, color: Colors.lightBlue, size: 26),
        ),
      ),
    ];

    if (_count > 0) {
      buttons.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
          child: TextButton(
            onPressed: () async {
              await Get.find<RouteService>().pushReplacementNamed(
                RouteConfig.leitner,
                arguments: {
                  "groupCode": widget.groupCode,
                  "level": LeitnerView.allLimitedLevel,
                },
              );
            },
            child: const Icon(Icons.play_circle, color: Colors.lightBlue, size: 26),
          ),
        ),
      );
    }

    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.groupCode.title} Level Cards: $_count"),
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios),
        ),
      ),
      body: ListView.builder(
        itemCount: _optionModels.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) return const SizedBox(height: 15);
          if (index == _optionModels.length + 1) return const SizedBox(height: 100);

          final option = _optionModels[index - 1];
          final isSelected = _selectedOption == index - 1;

          return Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? Border.all(color: Colors.black26) : null,
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: ListTile(
              leading: option.image,
              title: Text(
                option.title,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.grey[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                option.subtitle,
                style: TextStyle(color: isSelected ? Colors.black87 : Colors.grey[600]),
              ),
              selected: isSelected,
              onTap: () => setState(() => _selectedOption = index - 1),
              trailing: IconButton(
                icon: const Icon(Icons.play_circle),
                onPressed: () async {
                  await Get.find<RouteService>().pushReplacementNamed(
                    RouteConfig.leitner,
                    arguments: {
                      "groupCode": widget.groupCode,
                      "level": option.level,
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _count == 0
          ? null
          : FloatingActionButton(
        heroTag: 'Play',
        child: const Icon(Icons.play_arrow),
        onPressed: () async {
          await Get.find<RouteService>().pushReplacementNamed(
            RouteConfig.leitner,
            arguments: {"groupCode": widget.groupCode, "level": LeitnerView.allLevel},
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: _buildBottomBar()),
      ),
    );
  }
}
