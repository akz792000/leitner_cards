enum GroupCode {
  english,
  deutsch;

  String getTitle() {
    switch (this) {
      case english:
        return "English";
      case deutsch:
        return "Deutsch";
    }
  }
}
