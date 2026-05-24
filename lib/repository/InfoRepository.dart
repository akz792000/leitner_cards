import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:leitner_cards/enums/GroupCode.dart';
import '../entity/InfoEntity.dart';

class InfoRepository {
  static const String boxId = "info";

  Box<InfoEntity> get _box => Hive.box<InfoEntity>(boxId);

  ValueListenable<Box<InfoEntity>> listenable() => _box.listenable();

  Future<int> merge(InfoEntity info) async {
    if (info.id == 0) {
      info.id = await _box.add(info);
    }
    await _box.put(info.id, info);
    return info.id;
  }

  Future<void> remove(InfoEntity info) async => await _box.delete(info.id);

  Future<void> removeAll() async => await _box.deleteAll(_box.keys);

  Future<void> removeList(List<InfoEntity> infos) async {
    await Future.wait(infos.map((info) => _box.delete(info.id)));
  }

  InfoEntity? findById(int id) => _box.get(id);

  List<InfoEntity> findAll() => _box.values.toList();

  List<InfoEntity> findAllByGroupCode(GroupCode groupCode) =>
      _box.values.where((info) => info.groupCode == groupCode).toList();

  InfoEntity? findByGroupCodeAndKeyUpperCase(GroupCode groupCode, String key) {
    final upperKey = key.toUpperCase();
    final matches = _box.values.where(
      (info) => info.groupCode == groupCode && info.key.toUpperCase() == upperKey,
    );
    return matches.isNotEmpty ? matches.first : null;
  }
}
