// lib/onboarding/widgets/artist_card.dart
import 'package:flutter/material.dart';
import '../data/artist_list.dart';

class ArtistCard extends StatefulWidget {
  final ArtistOption artist;
  final bool selected;
  final VoidCallback onTap;

  const ArtistCard({
    super.key,
    required this.artist,
    required this.selected,
    required this.onTap,
  });

  @override
  State<ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<ArtistCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.90), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.05), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0),  weight: 20),
    ]).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final a = widget.artist;
    final c1 = Color(a.gradientColors[0]);
    final c2 = Color(a.gradientColors[1]);

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: () { _ctrl.forward(from: 0); widget.onTap(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.selected
                ? Colors.white.withOpacity(0.72)
                : Colors.white.withOpacity(0.38),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.selected
                  ? const Color(0xFFFF99CC)
                  : Colors.white.withOpacity(0.25),
              width: widget.selected ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [c1, c2],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  if (widget.selected)
                    Positioned(
                      top: 2, right: 2,
                      child: Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF99CC),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                a.name,
                style: const TextStyle(
                  fontFamily: 'Circular',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A0D26),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                a.genre,
                style: const TextStyle(
                  fontFamily: 'Circular',
                  fontSize: 9,
                  color: Color(0xFF8A7EA5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
