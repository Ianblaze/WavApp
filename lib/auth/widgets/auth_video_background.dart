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
    // Lock background to full screen dimensions to prevent "gap" or "jump" 
    // when the keyboard resizes the Scaffold body.
    final screenSize = MediaQuery.of(context).size;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Static Background Layer ──
        Positioned(
          top: 0,
          left: 0,
          width: screenSize.width,
          height: screenSize.height,
          child: Image.asset(
            'assets/images/bgstatic.png',
            fit: BoxFit.cover,
          ),
        ),

        // ── Dark Overlay ──
        Positioned(
          top: 0,
          left: 0,
          width: screenSize.width,
          height: screenSize.height,
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
