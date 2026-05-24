import 'package:flutter/material.dart';

class AnimatedButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback? onPressed;

  const AnimatedButton({super.key, required this.icon, this.onPressed});

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
              gradient: const LinearGradient(
                colors: [Colors.blueAccent, Colors.lightBlue],
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
