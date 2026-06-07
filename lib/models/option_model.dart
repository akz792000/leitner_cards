import 'package:flutter/material.dart';

/// Data model for a selectable option tile (e.g. a Leitner level card).
///
/// [image] is the leading widget (flag, emoji circle, etc.).
/// [onTap] is nullable so tiles can be rendered in a disabled state.
class OptionModel {
  final int level;
  final Widget image;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const OptionModel({
    required this.level,
    required this.image,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
}
