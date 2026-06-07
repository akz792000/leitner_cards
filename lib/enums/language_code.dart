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
}
