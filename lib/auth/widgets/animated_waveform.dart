import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedWaveform extends StatefulWidget {
  final int barCount;
  final double maxHeight;
  final double minHeight;

  const AnimatedWaveform({
    super.key,
    this.barCount = 38,
    this.maxHeight = 60.0,
    this.minHeight = 8.0,
  });

  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<double> _phases;
  late List<double> _speeds;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(); // Loop continuously

    // Generate random seed values for phase offsets and speeds to keep the organic feel
    _phases = List.generate(widget.barCount, (i) => math.Random().nextDouble() * math.pi * 2);
    _speeds = List.generate(widget.barCount, (i) => 0.8 + math.Random().nextDouble() * 1.5);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getColorForIndex(int index, int total) {
    // 0.0 is dead center, 1.0 is the complete edge
    double distanceToCenterOffset = (index - (total - 1) / 2.0).abs() / ((total - 1) / 2.0);
    
    // Smooth the curve towards the edges
    double gradientProgress = math.pow(distanceToCenterOffset, 1.2).toDouble().clamp(0.0, 1.0);
    
    final centerColor = const Color(0xFFFF6FE8); // Vibrant Pink
    final edgeColor = const Color(0xFFC0D5FF); // Soft Cool Lavender/Blue

    return Color.lerp(centerColor, edgeColor, gradientProgress) ?? centerColor;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(widget.barCount, (index) {
            
            // Base structural wave that undulates slowly
            double structuralWave = math.sin((index / widget.barCount) * math.pi * 3 - (_controller.value * math.pi * 2));
            
            // Fast, organic phase-jitter unique to each bar
            double organicJitter = math.sin(_controller.value * math.pi * 2 * _speeds[index] + _phases[index]);
            
            // Merge them: majority structural, minority organic jitter
            double combinedOscillation = (structuralWave * 0.7) + (organicJitter * 0.3);
            
            // Normalize scale [-1.0, 1.0] -> [0.0, 1.0]
            double mappedScale = (combinedOscillation + 1) / 2; 

            double rawHeight = widget.minHeight + (widget.maxHeight - widget.minHeight) * mappedScale;

            // Apply a severe envelope clamp (Hann window-esque) to taper the edges hard
            double distCenter = 1.0 - (index - (widget.barCount - 1) / 2.0).abs() / ((widget.barCount - 1) / 2.0);
            double envelope = math.pow(distCenter, 0.4).toDouble(); // Creates a rounded dome shape maximum constraint
            
            double finalHeight = rawHeight * (0.3 + 0.7 * envelope);
            if (finalHeight < widget.minHeight) finalHeight = widget.minHeight;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5), // gap
              width: 4.5,
              height: finalHeight,
              decoration: BoxDecoration(
                color: _getColorForIndex(index, widget.barCount),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        );
      },
    );
  }
}
