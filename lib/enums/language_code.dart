import 'dart:ui';

enum LanguageCode {
  fa,
  en,
  de;

  TextDirection get direction {
    return this == LanguageCode.fa ? TextDirection.rtl : TextDirection.ltr;
  }
}
