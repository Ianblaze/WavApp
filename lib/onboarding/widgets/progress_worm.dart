// lib/onboarding/widgets/progress_worm.dart
import 'package:flutter/material.dart';

class ProgressWorm extends StatelessWidget {
  final int currentStep;   // 0-indexed
  final int totalSteps;

  const ProgressWorm({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / totalSteps;
    return LayoutBuilder(builder: (ctx, constraints) {
      return Stack(
        children: [
          // Track
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Fill — animates width
          AnimatedContainer(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOutCubic,
            height: 5,
            width: constraints.maxWidth * progress,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              // Slight scale on the leading edge for the "worm" feel
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.6),
                  blurRadius: 4,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}
