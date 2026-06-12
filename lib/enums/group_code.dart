/// Identifies the deck a card belongs to.
/// Stored as a string in Hive for readability and forward compatibility.
enum GroupCode {
  faEn('FA_EN'), // Farsi ↔ English
  enDe('EN_DE'), // English ↔ Deutsch (sentences)
  enDeVerbs('EN_DE_VERBS'), // English ↔ Deutsch (verbs)
  visual('VISUAL'); // Image-based bilingual cards (EN + DE)

  final String code;
  const GroupCode(this.code);

  /// Look up by stored string value; defaults to [faEn] if unrecognised.
  static GroupCode fromCode(String? code) => GroupCode.values
      .firstWhere((g) => g.code == code, orElse: () => GroupCode.faEn);

  String get title {
    switch (this) {
      case faEn:
        return 'English';
      case enDe:
        return 'Deutsch';
      case enDeVerbs:
        return 'Verbs';
      case visual:
        return 'Visual';
    }
  }
}
