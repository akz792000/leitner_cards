import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';

/// Quick script to export progress from local Hive DB to JSON.
/// Run from project root: dart run tool/export_progress.dart
void main() async {
  final hivePath =
      '/Users/KarimizandiA/Library/Containers/com.flashmind.app/Data/Documents';

  Hive.init(hivePath);

  // Register a minimal adapter for ProgressEntity (typeId 2)
  Hive.registerAdapter(_ProgressAdapter());

  final box = await Hive.openBox<_Progress>('progress');
  print('Found ${box.length} progress entries');

  final list = <Map<String, dynamic>>[];
  for (final key in box.keys) {
    final p = box.get(key);
    if (p != null) {
      list.add({
        'cardId': p.cardId,
        'level': p.level,
        'subLevel': p.subLevel,
        'order': p.order,
      });
    }
  }

  final outPath = '$hivePath/progress_export.json';
  File(outPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(list));
  print('Exported to $outPath');

  await box.close();
}

// Minimal Hive adapter matching ProgressEntity (typeId 2, fields 0-5)
class _Progress {
  int cardId = 0;
  int level = 0;
  int subLevel = 1;
  int order = 0;
  DateTime created = DateTime.now();
  DateTime modified = DateTime.now();
}

class _ProgressAdapter extends TypeAdapter<_Progress> {
  @override
  final int typeId = 2;

  @override
  _Progress read(BinaryReader reader) {
    final p = _Progress();
    final numFields = reader.readByte();
    for (int i = 0; i < numFields; i++) {
      final field = reader.readByte();
      switch (field) {
        case 0:
          p.cardId = reader.read() as int;
        case 1:
          p.level = reader.read() as int;
        case 2:
          p.subLevel = reader.read() as int;
        case 3:
          p.order = reader.read() as int;
        case 4:
          p.created = reader.read() as DateTime;
        case 5:
          p.modified = reader.read() as DateTime;
        default:
          reader.read(); // skip unknown
      }
    }
    return p;
  }

  @override
  void write(BinaryWriter writer, _Progress obj) {}
}
