import 'package:flutter/material.dart';

/// A floating circular button with a continuous breathing animation.
///
/// When [isActive] is true the gradient switches to [activeColor], giving
/// immediate visual feedback that the thumb gesture has been registered.
/// The animation keeps running so the button stays lively even after the
/// state change.
class AnimatedButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color activeColor;

  const AnimatedButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.isActive = false,
    this.activeColor = Colors.blueAccent,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.12)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _floatAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, 0.08),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> gradientColors = widget.isActive
        ? [widget.activeColor, widget.activeColor.withValues(alpha: 0.75)]
        : [Colors.blueAccent, Colors.lightBlue];

    return SlideTransition(
      position: _floatAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          shape: const CircleBorder(),
          elevation: 8,
          shadowColor: Colors.black45,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onPressed,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: widget.icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
