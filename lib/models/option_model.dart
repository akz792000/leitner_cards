import 'package:flutter/material.dart';

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
