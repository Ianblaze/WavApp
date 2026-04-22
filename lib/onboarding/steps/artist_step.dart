// lib/onboarding/steps/artist_step.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../onboarding_controller.dart';
import '../data/artist_list.dart';
import '../widgets/artist_card.dart';
import '../widgets/split_screen_shell.dart';

class ArtistStep extends StatefulWidget {
  final VoidCallback onNext;
  const ArtistStep({super.key, required this.onNext});

  @override
  State<ArtistStep> createState() => _ArtistStepState();
}

class _ArtistStepState extends State<ArtistStep> {
  String _query = '';

  List<ArtistOption> get _filtered => _query.isEmpty
      ? kArtists
      : kArtists.where((a) =>
          a.name.toLowerCase().contains(_query.toLowerCase()) ||
          a.genre.toLowerCase().contains(_query.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<OnboardingController>();
    final selected = ctrl.artists;
    final done = ctrl.artistsDone;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = MediaQuery.of(context).size.width;
        final screenH = MediaQuery.of(context).size.height;
        
        // Dynamically adjust grid aspect ratio to prevent vertical overflow 
        // on very tall or very short screens.
        final dynamicAspectRatio = (screenW / (screenH * 0.38)).clamp(0.9, 1.25);

        return SplitScreenShell(
          topFlex: 62,
          bottomFlex: 38,
          topGradient: const [Color(0xFFD4E4FF), Color(0xFFEDD4FF)],
          illustration: Column(
            children: [
              // Search box
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.4), width: 0.5),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontFamily: 'Circular', fontSize: 14,
                      color: Color(0xFF1A0D26)),
                  decoration: InputDecoration(
                    hintText: 'search artists...',
                    hintStyle: const TextStyle(
                        fontFamily: 'Circular', fontSize: 14,
                        color: Color(0xFFB0A0C0)),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF8A7EA5), size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Artist grid
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: dynamicAspectRatio,
                  ),
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) {
                    final a = _filtered[i];
                    return ArtistCard(
                      artist: a,
                      selected: selected.contains(a.name),
                      onTap: () =>
                          context.read<OnboardingController>().toggleArtist(a.name),
                    );
                  },
                ),
              ),
            ],
          ),
          title: 'Favourite artists',
          subtitle: 'Pick 5 artists you love. They shape every match.',
          extras: AnimatedContainer(
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
                onPressed: done ? widget.onNext : null,
                child: Text(
                  done ? "let's go →" : 'pick ${5 - selected.length} more',
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
