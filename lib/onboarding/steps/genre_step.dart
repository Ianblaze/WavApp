// lib/onboarding/steps/genre_step.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../onboarding_controller.dart';
import '../data/genre_list.dart';
import '../widgets/genre_chip.dart';
import '../widgets/split_screen_shell.dart';

class GenreStep extends StatelessWidget {
  final VoidCallback onNext;
  const GenreStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<OnboardingController>();
    final selected = ctrl.genres;
    final done = ctrl.genresDone;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = MediaQuery.of(context).size.height;
        
        return SplitScreenShell(
          topGradient: const [Color(0xFFEDD4FF), Color(0xFFD4E4FF)],
          illustration: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selection counter
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: done
                      ? const Color(0xFFE1F5EE)
                      : Colors.white.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: done
                        ? const Color(0xFF5DCAA5)
                        : Colors.white.withOpacity(0.4),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '${selected.length} / 5 selected',
                  style: TextStyle(
                    fontFamily: 'Circular', fontSize: 13, fontWeight: FontWeight.w700,
                    color: done ? const Color(0xFF085041) : const Color(0xFF8A7EA5),
                  ),
                ),
              ),
              SizedBox(height: h * 0.02),
              // Chip grid
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10, runSpacing: 10,
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
            ],
          ),
          title: 'Your music taste',
          subtitle: 'Pick exactly 5 genres. This drives who you match with.',
          cta: SizedBox(
            width: double.infinity, height: 56,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: done ? 1.0 : 0.5,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB3D9),
                  foregroundColor: const Color(0xFF4B1528),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                onPressed: done ? onNext : null,
                child: Text(
                  done ? 'next →' : 'pick ${5 - selected.length} more',
                  style: const TextStyle(
                    fontFamily: 'Circular',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
