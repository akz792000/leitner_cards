import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/enums/GroupCode.dart';

import '../config/RouteConfig.dart';
import '../model/OptionModel.dart';
import '../service/RouteService.dart';
import 'DrawerWidgetView.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedOption = 0;

  late final List<OptionModel> _optionModels;

  @override
  void initState() {
    super.initState();
    debugPrint("HomeView initialize");

    _optionModels = [
      OptionModel(
        level: 0,
        image: Image.asset('assets/flags/en.png'),
        title: 'English',
        subtitle: 'Learn English sentences.',
        onTap: () async {
          await Get.find<RouteService>().pushNamed(
            RouteConfig.level,
            arguments: {"groupCode": GroupCode.english},
          );
        },
      ),
      OptionModel(
        level: 1,
        image: Image.asset('assets/flags/de.png'),
        title: 'Deutsch',
        subtitle: 'Englische Sätze lernen.',
        onTap: () async {
          await Get.find<RouteService>().pushNamed(
            RouteConfig.level,
            arguments: {"groupCode": GroupCode.deutsch},
          );
        },
      ),
      OptionModel(
        level: 2,
        image: Image.asset('assets/database.png'),
        title: 'Download',
        subtitle: 'Download sentences',
        onTap: () async {
          await Get.find<RouteService>().pushNamed(RouteConfig.download);
        },
      ),
    ];
  }

  @override
  void dispose() {
    debugPrint("HomeView dispose");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Home")),
      drawer: const DrawerWidget(),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? Border.all(color: Colors.black26) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: option.image,
              title: Text(
                option.title,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                option.subtitle,
                style: TextStyle(
                  color: isSelected ? Colors.black87 : Colors.grey[600],
                ),
              ),
              selected: isSelected,
              onTap: () {
                setState(() {
                  _selectedOption = index - 1;
                });
                option.onTap?.call();
              },
            ),
          );
        },
      ),
    );
  }
}
