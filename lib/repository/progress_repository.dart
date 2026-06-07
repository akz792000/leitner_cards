import 'package:hive_flutter/hive_flutter.dart';

import '../entity/progress_entity.dart';
import '../util/date_time_util.dart';

/// Hive CRUD for the "progress" box.
///
/// Progress is keyed by [ProgressEntity.cardId] — one record per card.
/// This box is the single source of truth for Leitner scheduling and
/// can be exported/imported for cross-device sync.
class ProgressRepository {
  static const String boxId = 'progress';

  Box<ProgressEntity> get _box => Hive.box<ProgressEntity>(boxId);

  /// Insert or update progress for a card (upsert by cardId).
  Future<void> merge(ProgressEntity progress) async =>
      await _box.put(progress.cardId, progress);

  /// Returns progress for the given cardId, or null if not yet studied.
  ProgressEntity? findByCardId(int cardId) => _box.get(cardId);

  /// Returns existing progress or creates a default new-card record (not persisted).
  ProgressEntity findOrCreate(int cardId) {
    return _box.get(cardId) ??
        ProgressEntity(
          cardId: cardId,
          level: ProgressEntity.initLevel,
          subLevel: ProgressEntity.initSubLevel,
          order: 0,
          created: DateTimeUtil.now(),
          modified: DateTimeUtil.now(),
        );
  }

  List<ProgressEntity> findAll() => _box.values.toList();

  Future<void> removeAll() async => await _box.deleteAll(_box.keys);

  /// Returns all progress records as a list of plain maps — for JSON export.
  List<Map<String, dynamic>> exportAll() => _box.values
      .map((p) => {
            'cardId': p.cardId,
            'level': p.level,
            'subLevel': p.subLevel,
            'order': p.order,
            'created': p.created.toIso8601String(),
            'modified': p.modified.toIso8601String(),
          })
      .toList();
}
