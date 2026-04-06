// lib/onboarding/steps/genre_step.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../onboarding_controller.dart';
import '../data/genre_list.dart';
import '../widgets/genre_chip.dart';

class GenreStep extends StatelessWidget {
  final VoidCallback onNext;
  const GenreStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<OnboardingController>();
    final selected = ctrl.genres;
    final done = ctrl.genresDone;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('your music taste',
              style: TextStyle(fontFamily: 'Circular', fontSize: 26,
                  fontWeight: FontWeight.w800, color: Color(0xFF1A0D26),
                  letterSpacing: -.4)),
          const SizedBox(height: 4),
          const Text('pick exactly 5 genres to continue',
              style: TextStyle(fontFamily: 'Circular', fontSize: 14,
                  color: Color(0xFF8A7EA5))),
          const SizedBox(height: 16),
          // Selection counter
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: done
                  ? const Color(0xFFE1F5EE)
                  : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: done
                    ? const Color(0xFF5DCAA5)
                    : Colors.white.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              '${selected.length} / 5 selected',
              style: TextStyle(
                fontFamily: 'Circular', fontSize: 12, fontWeight: FontWeight.w700,
                color: done ? const Color(0xFF085041) : const Color(0xFF8A7EA5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Chip grid
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: List.generate(kGenres.length, (i) {
                  final g = kGenres[i];
                  final isSelected = selected.contains(g);
                  final selIdx = isSelected ? selected.indexOf(g) : 0;
                  return GenreChip(
                    label: g,
                    selected: isSelected,
                    selectionIndex: selIdx,
                    onTap: () => context.read<OnboardingController>().toggleGenre(g),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 52,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: done ? 1.0 : 0.4,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB3D9),
                  foregroundColor: const Color(0xFF4B1528),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                  elevation: 0,
                ),
                onPressed: done ? onNext : null,
                child: Text(
                  done ? 'next →' : 'pick ${5 - selected.length} more',
                  style: const TextStyle(fontFamily: 'Circular',
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
