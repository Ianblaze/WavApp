// lib/onboarding/steps/artist_step.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../onboarding_controller.dart';
import '../data/artist_list.dart';
import '../widgets/artist_card.dart';

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('favourite artists',
              style: TextStyle(fontFamily: 'Circular', fontSize: 26,
                  fontWeight: FontWeight.w800, color: Color(0xFF1A0D26),
                  letterSpacing: -.4)),
          const SizedBox(height: 4),
          const Text('pick 5 — shapes your matches',
              style: TextStyle(fontFamily: 'Circular', fontSize: 14,
                  color: Color(0xFF8A7EA5))),
          const SizedBox(height: 12),
          // Search box
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.white.withOpacity(0.4), width: 0.5),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontFamily: 'Circular', fontSize: 13,
                  color: Color(0xFF1A0D26)),
              decoration: InputDecoration(
                hintText: 'search artists...',
                hintStyle: const TextStyle(
                    fontFamily: 'Circular', fontSize: 13,
                    color: Color(0xFFB0A0C0)),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF8A7EA5), size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Counter
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
          const SizedBox(height: 10),
          // Artist grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.05,
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
          const SizedBox(height: 12),
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
                onPressed: done ? widget.onNext : null,
                child: Text(
                  done ? "let's go →" : 'pick ${5 - selected.length} more',
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
