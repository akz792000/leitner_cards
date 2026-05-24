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
