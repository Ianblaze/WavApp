import 'package:flutter/material.dart';

class AuthVideoBackground extends StatelessWidget {
  final Widget child;
  final double overlayOpacity;

  const AuthVideoBackground({
    super.key,
    required this.child,
    this.overlayOpacity = 0.2,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Static Background Layer ──
        Positioned.fill(
          child: Image.asset(
            'assets/images/bgstatic.png',
            fit: BoxFit.cover,
          ),
        ),

        // ── Dark Overlay ──
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withOpacity(overlayOpacity),
          ),
        ),

        // ── Content ──
        child,
      ],
    );
  }
}
