import 'package:flutter/material.dart';

/// A circular flag avatar with a looping float-and-scale animation.
///
/// Used in [LeitnerScreen] to show which language is currently displayed.
/// The gentle bobbing draws the eye without distracting from the card text.
class AnimatedFlag extends StatefulWidget {
  final String imagePath;
  const AnimatedFlag({super.key, required this.imagePath});

  @override
  State<AnimatedFlag> createState() => _AnimatedFlagState();
}

class _AnimatedFlagState extends State<AnimatedFlag>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _floatAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller =
    AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);

    _floatAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, 0.08), // float down 8%
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.12)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _floatAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          elevation: 8,
          shape: const CircleBorder(),
          shadowColor: Colors.black45,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.lightBlueAccent, Colors.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: CircleAvatar(
              backgroundImage: AssetImage(widget.imagePath),
            ),
          ),
        ),
      ),
    );
  }
}
