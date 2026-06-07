/// The two language-learning decks available in the app.
///
/// [english] covers English ↔ Farsi (group_code = 0).
/// [deutsch] covers Deutsch ↔ English (group_code = 1).
enum GroupCode {
  english,
  deutsch;

  String get title {
    switch (this) {
      case english:
        return "English";
      case deutsch:
        return "Deutsch";
    }
  }
}
