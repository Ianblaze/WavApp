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
    // Get the full height including the keyboard area (viewInsets.bottom)
    final mediaQuery = MediaQuery.of(context);
    final totalHeight = mediaQuery.size.height + mediaQuery.viewInsets.bottom;
    final totalWidth = mediaQuery.size.width;
    
    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Static Background Layer ──
          Positioned(
            top: 0,
            left: 0,
            width: totalWidth,
            height: totalHeight,
            child: Image.asset(
              'assets/images/bgstatic.png',
              fit: BoxFit.cover,
            ),
          ),
  
          // ── Dark Overlay ──
          Positioned(
            top: 0,
            left: 0,
            width: totalWidth,
            height: totalHeight,
            child: ColoredBox(
              color: Colors.black.withOpacity(overlayOpacity),
            ),
          ),
  
          // ── Content ──
          child,
        ],
      ),
    );
  }
}
