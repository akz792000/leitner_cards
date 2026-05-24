import 'dart:ui';

enum LanguageCode {
  fa,
  en,
  de;

  TextDirection getDirection() {
    return this == LanguageCode.fa ? TextDirection.rtl : TextDirection.ltr;
  }
}
