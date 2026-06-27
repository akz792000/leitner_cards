import 'dart:ui';

/// The languages used in card content.
///
/// [fa] is RTL; [en] and [de] are LTR. The [direction] getter drives
/// text alignment in study views without scattering conditional logic.
enum LanguageCode {
  fa,
  en,
  de;

  TextDirection get direction {
    return this == LanguageCode.fa ? TextDirection.rtl : TextDirection.ltr;
  }

  /// Resolve from a two-letter lang string ("fa", "en", "de").
  static LanguageCode fromLang(String lang) {
    switch (lang.toLowerCase()) {
      case 'fa':
        return LanguageCode.fa;
      case 'de':
        return LanguageCode.de;
      default:
        return LanguageCode.en;
    }
  }
}
