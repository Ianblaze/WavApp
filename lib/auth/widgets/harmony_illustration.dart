import 'dart:math' as math;
import 'package:flutter/material.dart';

class HarmonyIllustration extends StatefulWidget {
  const HarmonyIllustration({super.key});

  @override
  State<HarmonyIllustration> createState() => _HarmonyIllustrationState();
}

class _HarmonyIllustrationState extends State<HarmonyIllustration>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _drifts;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 2500 + (i * 400)),
      )..repeat(reverse: true);
    });

    _drifts = _controllers.map((c) {
      return Tween<double>(begin: -8.0, end: 8.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOutSine),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 160,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 1. The Music (Vinyl) - Back Left
          AnimatedBuilder(
            animation: _drifts[0],
            builder: (context, child) => Positioned(
              left: 20,
              top: 10 + _drifts[0].value,
              child: _GlassSymbol(
                color: const Color(0xFFB3D9FF),
                icon: Icons.album_rounded,
                rotation: -0.15,
                delay: 0,
              ),
            ),
          ),

          // 2. The Connection (Pulse) - Back Right
          AnimatedBuilder(
            animation: _drifts[1],
            builder: (context, child) => Positioned(
              right: 20,
              top: 20 + _drifts[1].value,
              child: _GlassSymbol(
                color: const Color(0xFFFFB3D9),
                icon: Icons.favorite_rounded,
                rotation: 0.12,
                delay: 0.2,
              ),
            ),
          ),

          // 3. The Match (Avatar) - Front Centered
          AnimatedBuilder(
            animation: _drifts[2],
            builder: (context, child) => Positioned(
              top: 35 + _drifts[2].value,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD9B3FF), Color(0xFFB69CFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB69CFF).withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassSymbol extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double rotation;
  final double delay;

  const _GlassSymbol({
    required this.color,
    required this.icon,
    required this.rotation,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            color: color.withOpacity(0.1),
            child: Center(
              child: Icon(
                icon,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
