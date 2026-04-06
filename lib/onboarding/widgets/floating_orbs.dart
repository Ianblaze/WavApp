// lib/onboarding/widgets/floating_orbs.dart
import 'dart:math';
import 'package:flutter/material.dart';

/// Three floating gradient orbs matching the landing reference image.
/// Drop this behind your existing content with a [Stack].
class FloatingOrbs extends StatefulWidget {
  const FloatingOrbs({super.key});

  @override
  State<FloatingOrbs> createState() => _FloatingOrbsState();
}

class _FloatingOrbsState extends State<FloatingOrbs>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  // Orb specs: [color, diameter, baseTop%, baseLeft%, duration-ms, delay-ms]
  static const _orbs = [
    [0xFFFFB3D9, 80.0, 0.20, 0.14, 3200, 0],
    [0xFFC9B3FF, 86.0, 0.17, 0.50, 2800, 400],
    [0xFFA8D4FF, 78.0, 0.22, 0.82, 3600, 200],
  ];

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(_orbs.length, (i) => AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _orbs[i][4] as int),
    )..repeat(reverse: true));

    _anims = List.generate(_orbs.length, (i) => Tween<double>(
      begin: -10.0, end: 10.0,
    ).animate(CurvedAnimation(
      parent: _ctrls[i],
      curve: Curves.easeInOut,
    )));
  }

  @override
  void dispose() {
    for (final c in _ctrls) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      return Stack(
        children: List.generate(_orbs.length, (i) {
          final orb  = _orbs[i];
          final d    = orb[1] as double;
          final topF = orb[2] as double;
          final lftF = orb[3] as double;
          return AnimatedBuilder(
            animation: _anims[i],
            builder: (_, __) => Positioned(
              top:  h * topF + _anims[i].value,
              left: w * lftF - d / 2,
              child: Container(
                width: d, height: d,
                decoration: BoxDecoration(
                  color: Color(orb[0] as int),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      );
    });
  }
}
