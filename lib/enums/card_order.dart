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

  String get subtitle {
    switch (this) {
      case highFirst:
        return 'Most mastered cards appear first';
      case lowFirst:
        return 'Least mastered cards appear first';
      case random:
        return 'Cards are shuffled each session';
    }
  }
}
