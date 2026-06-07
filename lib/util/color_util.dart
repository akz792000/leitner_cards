import 'package:flutter/material.dart';

/// Shared gradient and colour helpers used across the app.
class ColorUtil {
  /// Predefined gradients
  static const LinearGradient whiteToGrey = LinearGradient(
    colors: [Colors.white, Colors.grey],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static const LinearGradient whiteToBlue = LinearGradient(
    colors: [Colors.white, Color(0xff7ba2ef)],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static const List<LinearGradient> gradients = [
    whiteToGrey,
    whiteToBlue,
  ];

  static LinearGradient gradientFromColors({
    required Color start,
    required Color end,
    Alignment begin = Alignment.bottomLeft,
    Alignment endAlign = Alignment.topRight,
  }) {
    return LinearGradient(
      colors: [start, end],
      begin: begin,
      end: endAlign,
    );
  }
}
