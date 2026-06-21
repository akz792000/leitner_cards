/// Controls the order in which cards are presented within a study session.
enum CardOrder {
  /// Higher-level cards first (most mastered → least mastered).
  highFirst,

  /// Lower-level cards first (least mastered → most mastered).
  lowFirst,

  /// Cards are randomly shuffled each session.
  random;

  /// Stored integer value persisted to Hive.
  int get code => index;

  static CardOrder fromCode(int code) =>
      CardOrder.values[code.clamp(0, CardOrder.values.length - 1)];

  String get label {
    switch (this) {
      case highFirst:
        return 'High level first';
      case lowFirst:
        return 'Low level first';
      case random:
        return 'Random';
    }
  }

  String get subtitle => levelSubtitle;

  String get levelSubtitle {
    switch (this) {
      case highFirst:
        return 'Higher Leitner levels appear first';
      case lowFirst:
        return 'Lower Leitner levels appear first';
      case random:
        return 'Level groups are shuffled each session';
    }
  }

  String get subLevelSubtitle {
    switch (this) {
      case highFirst:
        return 'Cards closer to their next review appear first';
      case lowFirst:
        return 'Freshly reviewed cards appear first';
      case random:
        return 'Cards within each level are shuffled';
    }
  }
}
