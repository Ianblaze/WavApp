import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_wrapper.dart';
import '../auth/widgets/auth_video_background.dart';
import '../onboarding/widgets/split_screen_shell.dart';
import 'intro_illustrations.dart';

class IntroFlow extends StatefulWidget {
  const IntroFlow({super.key});

  @override
  State<IntroFlow> createState() => _IntroFlowState();
}

class _IntroFlowState extends State<IntroFlow> with TickerProviderStateMixin {
  final _ctrl = PageController();
  int _page = 0;
  double _scrollOffset = 0.0;
  bool _isPlaying = true;
  late AnimationController _progressCtrl;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45), // 15 seconds per slide
    )..addListener(() {
      if (mounted && _isPlaying) {
        final targetPage = (_progressCtrl.value * 3).floor();
        if (targetPage != _page && targetPage < 3) {
          final oldPage = _page;
          _page = targetPage; // Update immediately to prevent re-triggering
          _ctrl.animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOutCubic,
          ).then((_) {
            if (mounted) setState(() {});
          });
        }
        setState(() {}); // For progress bar
      }
    });

    _progressCtrl.forward();

    _ctrl.addListener(() {
      if (mounted) {
        setState(() {
          _scrollOffset = _ctrl.hasClients ? _ctrl.page ?? 0.0 : 0.0;
        });
      }
    });
  }

  static const _screens = [
    _IntroData(
      topGradient: [Color(0xFFFFD4FF), Color(0xFFEDD4FF), Color(0xFFD8E8FF)],
      title: 'Match through\nmusic',
      subtitle:
          'Swipe songs, build your taste profile, and find people who hear the world the same way.',
      isLast: false,
    ),
    _IntroData(
      topGradient: [Color(0xFFEDD4FF), Color(0xFFD4E4FF), Color(0xFFFFD8F4)],
      title: 'Your taste,\nyour matches',
      subtitle:
          'Pick the genres and artists you love. wav finds people whose playlists sync with yours.',
      isLast: false,
    ),
    _IntroData(
      topGradient: [Color(0xFFD4E4FF), Color(0xFFEDD4FF), Color(0xFFFFD4FF)],
      title: 'Music starts\nthe conversation',
      subtitle:
          'When you match, share songs. No awkward openers — just let the music talk.',
      isLast: true,
    ),
  ];

  Widget _getIllustration(int index, double scrollOffset) {
    final double localOffset = index - scrollOffset; // -1 to 1 range
    switch (index) {
      case 0:
        return MatchCardsIllustration(
          parallaxOffset: localOffset,
          isPlaying: _isPlaying,
        );
      case 1:
        return SolarSystemIllustration(
          parallaxOffset: localOffset,
          isPlaying: _isPlaying,
        );
      case 2:
        return MusicConversationIllustration(
          parallaxOffset: localOffset,
          isPlaying: _isPlaying,
        );
      default:
        return const SizedBox();
    }
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _progressCtrl.forward();
      } else {
        _progressCtrl.stop();
      }
    });
  }

  void _next() {
    setState(() {
      _isPlaying = true;
      _progressCtrl.forward();
    });
    if (_page < 2) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _previous() {
    setState(() {
      _isPlaying = true;
      _progressCtrl.forward();
    });
    if (_page > 0) {
      _ctrl.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  bool _isFinishing = false;

  Future<void> _finish() async {
    if (_isFinishing) return;
    setState(() {
      _isFinishing = true;
      _isPlaying = true;
    });

    // Fast forward effect: Animate through remaining slides quickly
    await _progressCtrl.animateTo(
      1.0,
      duration: const Duration(milliseconds: 1200),
      curve: Curves.fastOutSlowIn,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_shown', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthWrapper(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthVideoBackground(
      overlayOpacity: 0.3,
      isPlaying: _isPlaying,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  ui.PointerDeviceKind.touch,
                  ui.PointerDeviceKind.mouse,
                },
              ),
              child: PageView.builder(
                controller: _ctrl,
                physics: const BouncingScrollPhysics(),
                itemCount: _screens.length,
                onPageChanged: (i) {
                  setState(() {
                    _page = i;
                    _isPlaying = true;
                    _progressCtrl.forward(from: i / 3.0);
                  });
                },
                itemBuilder: (ctx, i) {
                  final s = _screens[i];
                  return SplitScreenShell(
                    topGradient: s.topGradient,
                    illustration: _getIllustration(i, _scrollOffset),
                    title: s.title,
                    subtitle: s.subtitle,
                    // No DotIndicators here, we use the MusicPlayer bar instead
                    cta: const SizedBox(height: 80), // Reserve space for player
                  );
                },
              ),
            ),

            // ── Minimal Top Skip Icon ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 24,
              child: GestureDetector(
                onTap: _finish,
                child: Icon(
                  Icons.fast_forward_rounded,
                  size: 32,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),

            // ── Music Player Navigation (Bottom) ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _MusicPlayerNavigation(
                page: _page,
                scrollOffset: _scrollOffset,
                progressValue: _progressCtrl.value, // Pass animated progress
                isPlaying: _isPlaying,
                onPlayToggle: _togglePlay,
                onNext: _next,
                onPrevious: _previous,
                isLast: _page == 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicPlayerNavigation extends StatelessWidget {
  final int page;
  final double scrollOffset;
  final double progressValue;
  final bool isPlaying;
  final VoidCallback onPlayToggle;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final bool isLast;

  const _MusicPlayerNavigation({
    required this.page,
    required this.scrollOffset,
    required this.progressValue,
    required this.isPlaying,
    required this.onPlayToggle,
    required this.onNext,
    required this.onPrevious,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = (scrollOffset + 1) / 3.0; // 3 slides total

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.4),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Song Progress Bar (Spotify Style) ──
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: MediaQuery.of(context).size.width * progressValue.clamp(0.0, 1.0),
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF80FFEA).withOpacity(0.85), 
                      const Color(0xFF8E7CFF).withOpacity(0.85), 
                      const Color(0xFFFF80E2).withOpacity(0.85)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8E7CFF).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Controls ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Back Button
              IconButton(
                onPressed: page > 0 ? onPrevious : null,
                icon: Icon(
                  Icons.skip_previous_rounded,
                  size: 36,
                  color: page > 0 ? Colors.white : Colors.white.withOpacity(0.2),
                ),
              ),
              const SizedBox(width: 24), // Closer together

              // Play/Pause Button
              GestureDetector(
                onTap: onPlayToggle,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 48,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 24), // Closer together

              // Next Button
              IconButton(
                onPressed: onNext,
                icon: Icon(
                  isLast ? Icons.check_circle_rounded : Icons.skip_next_rounded,
                  size: 36,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntroData {
  final List<Color> topGradient;
  final String title;
  final String subtitle;
  final bool isLast;

  const _IntroData({
    required this.topGradient,
    required this.title,
    required this.subtitle,
    required this.isLast,
  });
}
