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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.selected
                ? Colors.white.withOpacity(0.85)
                : Colors.white.withOpacity(0.45),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.selected 
                  ? const Color(0xFFFF99CC).withOpacity(0.2)
                  : const Color(0xFF8A7EA5).withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 6),
              )
            ],
            border: Border.all(
              color: widget.selected
                  ? const Color(0xFFFF99CC)
                  : Colors.white.withOpacity(0.6),
              width: widget.selected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [c1, c2],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                         BoxShadow(
                           color: c2.withOpacity(0.3),
                           blurRadius: 8,
                           offset: const Offset(0, 4),
                         )
                      ],
                    ),
                  ),
                  if (widget.selected)
                    Positioned(
                      top: -4, right: -4,
                      child: Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF99CC),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.check,
                            size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                a.name,
                style: const TextStyle(
                  fontFamily: 'Circular',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F0B1A),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                a.genre,
                style: const TextStyle(
                  fontFamily: 'Circular',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
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
