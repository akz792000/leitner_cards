import 'package:flutter/material.dart';

class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;
  const AnimatedGradientBackground({super.key, required this.child});

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends State<AnimatedGradientBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Alignment> _beginAnimation;
  late Animation<Alignment> _endAnimation;

  @override
  void initState() {
    super.initState();

    _controller =
    AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat(reverse: true);

    _beginAnimation = Tween<Alignment>(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _endAnimation = Tween<Alignment>(
      begin: Alignment.bottomRight,
      end: Alignment.topLeft,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Deep muted slate palette — easy on eyes, AMOLED-friendly, professional
    // Dark mode: near-black navy shimmer
    // Light mode: soft cool-grey with a hint of blue
    final darkColors = const [
      Color(0xFF0D1B2A), // midnight navy
      Color(0xFF152232), // deep slate blue
      Color(0xFF1A2B3C), // slate
      Color(0xFF0F1923), // near black
    ];

    final lightColors = const [
      Color(0xFFE8EDF2), // cool white
      Color(0xFFD6DFE8), // light silver-blue
      Color(0xFFCDD8E3), // muted sky
      Color(0xFFD8E3EC), // pale slate
    ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: _beginAnimation.value,
              end: _endAnimation.value,
              colors: isDark ? darkColors : lightColors,
              stops: const [0.0, 0.35, 0.7, 1.0],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}
