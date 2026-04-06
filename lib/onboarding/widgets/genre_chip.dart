// lib/onboarding/widgets/genre_chip.dart
import 'package:flutter/material.dart';

// Colour ramp matching Y2K palette — cycles through selections
const _chipColors = [
  Color(0xFFFFB3D9), // hot pink
  Color(0xFFD9B3FF), // lavender
  Color(0xFFB3D9FF), // electric blue
  Color(0xFFFFD4B3), // peach
  Color(0xFFB3FFD9), // mint
];
const _chipTextColors = [
  Color(0xFF4B1528),
  Color(0xFF26215C),
  Color(0xFF042C53),
  Color(0xFF412402),
  Color(0xFF04342C),
];

class GenreChip extends StatefulWidget {
  final String label;
  final bool selected;
  final int selectionIndex; // 0–4 when selected, drives colour
  final VoidCallback onTap;

  const GenreChip({
    super.key,
    required this.label,
    required this.selected,
    required this.selectionIndex,
    required this.onTap,
  });

  @override
  State<GenreChip> createState() => _GenreChipState();
}

class _GenreChipState extends State<GenreChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.86), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.86, end: 1.10), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.10, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _handleTap() {
    _ctrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final idx = widget.selectionIndex.clamp(0, 4);
    final bg   = widget.selected ? _chipColors[idx]     : Colors.white.withOpacity(0.45);
    final text = widget.selected ? _chipTextColors[idx] : const Color(0xFF8A7EA5);
    final border = widget.selected
        ? _chipColors[idx].withOpacity(0)
        : Colors.white.withOpacity(0.3);

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'Circular',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
        ),
      ),
    );
  }
}
