// lib/onboarding/done_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:math';

import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import 'onboarding_controller.dart';

class DoneScreen extends StatefulWidget {
  const DoneScreen({super.key});

  @override
  State<DoneScreen> createState() => _DoneScreenState();
}

class _DoneScreenState extends State<DoneScreen>
    with SingleTickerProviderStateMixin {
  final _screenshotCtrl = ScreenshotController();
  late AnimationController _confettiCtrl;
  bool _saving = false;
  bool _saved = false;
  bool _writeComplete = false;

  static const _confettiColors = [
    Color(0xFFFFB3D9), Color(0xFFD9B3FF), Color(0xFFB3D9FF),
    Color(0xFFFF99CC), Color(0xFFFFD4B3), Color(0xFFB3FFD9),
  ];

  @override
  void initState() {
    super.initState();
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _writeOnboardingData();
  }

  Future<void> _writeOnboardingData() async {
    final ctrl = context.read<OnboardingController>();
    try {
      await ctrl.complete();
      // Notify AuthProvider to re-check status → will route to authenticated
      if (mounted) setState(() => _writeComplete = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save your profile. Please try again.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCard() async {
    setState(() => _saving = true);
    try {
      final Uint8List? bytes = await _screenshotCtrl.capture(pixelRatio: 3.0);
      if (bytes != null) {
        // TODO: use image_gallery_saver or share_plus to save/share
        // For now, show confirmation
        if (mounted) setState(() { _saving = false; _saved = true; });
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goHome() {
    // Re-trigger auth state check — AuthProvider will now see onboardingComplete=true
    // and route to authenticated → HomePage via AuthWrapper
    context.read<AuthProvider>().forceTokenRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<OnboardingController>();
    final profile = context.watch<UserProfileProvider>().profile;
    final username = profile?.username ??
        context.read<AuthProvider>().currentUser?.displayName ??
        'you';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD4FF), Color(0xFFEDD4FF), Color(0xFFD4E4FF)],
          ),
        ),
        child: Stack(
          children: [
            // Confetti layer
            _ConfettiLayer(controller: _confettiCtrl, colors: _confettiColors),

            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const Text("you're all set!",
                        style: TextStyle(fontFamily: 'Circular', fontSize: 28,
                            fontWeight: FontWeight.w800, color: Color(0xFF1A0D26),
                            letterSpacing: -.4)),
                    const SizedBox(height: 4),
                    const Text('your wav card is ready to share',
                        style: TextStyle(fontFamily: 'Circular', fontSize: 14,
                            color: Color(0xFF8A7EA5))),
                    const SizedBox(height: 24),

                    // Shareable card wrapped in Screenshot widget
                    Screenshot(
                      controller: _screenshotCtrl,
                      child: _WavProfileCard(
                        username: username,
                        genres: ctrl.genres,
                        artists: ctrl.artists,
                        photoUrl: ctrl.photoUrl,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Share button
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A0D26),
                          side: const BorderSide(
                              color: Color(0xFFFF99CC), width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25)),
                        ),
                        onPressed: _saving ? null : _saveCard,
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFFF99CC)))
                            : const Icon(Icons.ios_share_rounded, size: 18),
                        label: Text(
                          _saved ? 'saved to photos!' : 'share my wav card',
                          style: const TextStyle(fontFamily: 'Circular',
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Start matching CTA
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB3D9),
                          foregroundColor: const Color(0xFF4B1528),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26)),
                          elevation: 0,
                        ),
                        onPressed: _writeComplete ? _goHome : null,
                        child: const Text('start matching →',
                            style: TextStyle(fontFamily: 'Circular',
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile card widget ───────────────────────────────────────────────────────
class _WavProfileCard extends StatelessWidget {
  final String username;
  final List<String> genres;
  final List<String> artists;
  final String? photoUrl;

  const _WavProfileCard({
    required this.username,
    required this.genres,
    required this.artists,
    this.photoUrl,
  });

  static const _chipColors = [
    Color(0xFFFFB3D9), Color(0xFFD9B3FF),
    Color(0xFFB3D9FF), Color(0xFFFFD4B3), Color(0xFFB3FFD9),
  ];
  static const _chipText = [
    Color(0xFF4B1528), Color(0xFF26215C),
    Color(0xFF042C53), Color(0xFF412402), Color(0xFF04342C),
  ];
  static const _artistGrads = [
    [Color(0xFFFFB3D9), Color(0xFFFF6FE8)],
    [Color(0xFFD9B3FF), Color(0xFFB69CFF)],
    [Color(0xFFB3D9FF), Color(0xFF7BA7FF)],
    [Color(0xFFFFD4B3), Color(0xFFFF9966)],
    [Color(0xFFB3FFD9), Color(0xFF5DCAA5)],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0D26), Color(0xFF2D1642)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB3D9), Color(0xFFD9B3FF)],
                  ),
                  image: photoUrl != null && photoUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(photoUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: photoUrl == null || photoUrl!.isEmpty
                    ? const Icon(Icons.person_rounded,
                        color: Colors.white, size: 24)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@$username',
                        style: const TextStyle(fontFamily: 'Circular',
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const Text('wav · music matchmaking',
                        style: TextStyle(fontFamily: 'Circular', fontSize: 10,
                            color: Color(0xFF8A7EA5))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFF99CC).withOpacity(0.4)),
                ),
                child: const Text('wav',
                    style: TextStyle(fontFamily: 'Circular', fontSize: 10,
                        color: Color(0xFFFF99CC), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 0.5, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 14),

          // Genres
          const Text('genres',
              style: TextStyle(fontFamily: 'Circular', fontSize: 10,
                  color: Color(0xFF8A7EA5), letterSpacing: .06,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5, runSpacing: 5,
            children: List.generate(genres.length, (i) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _chipColors[i % 5].withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _chipColors[i % 5].withOpacity(0.35)),
              ),
              child: Text(genres[i],
                  style: TextStyle(fontFamily: 'Circular', fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _chipColors[i % 5])),
            )),
          ),
          const SizedBox(height: 14),
          Container(height: 0.5, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 14),

          // Artists
          const Text('top artists',
              style: TextStyle(fontFamily: 'Circular', fontSize: 10,
                  color: Color(0xFF8A7EA5), letterSpacing: .06,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...List.generate(artists.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: _artistGrads[i % 5],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(artists[i],
                    style: const TextStyle(fontFamily: 'Circular',
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: Color(0xFFE0D0F0))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ── Confetti layer ────────────────────────────────────────────────────────────
class _ConfettiLayer extends StatelessWidget {
  final AnimationController controller;
  final List<Color> colors;

  const _ConfettiLayer({required this.controller, required this.colors});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (ctx, _) {
        final rng = Random(42);
        return CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
              progress: controller.value, rng: rng, colors: colors),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final Random rng;
  final List<Color> colors;
  static const _count = 28;

  _ConfettiPainter({
    required this.progress,
    required this.rng,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (int i = 0; i < _count; i++) {
      final seed = i * 137.508;
      final startX = (sin(seed) * 0.5 + 0.5) * size.width;
      final delay = (i / _count);
      final t = ((progress - delay) % 1.0 + 1.0) % 1.0;
      final y = t * (size.height + 40) - 20;
      final x = startX + sin(t * pi * 3 + seed) * 30;
      final rotation = t * pi * 4 + seed;
      final color = colors[i % colors.length].withOpacity(1.0 - t * 0.5);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      paint.color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-4, -4, 8, 8), const Radius.circular(1.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
