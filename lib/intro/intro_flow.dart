import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_wrapper.dart';
import '../onboarding/widgets/split_screen_shell.dart';
import 'intro_illustrations.dart';

class IntroFlow extends StatefulWidget {
  const IntroFlow({super.key});

  @override
  State<IntroFlow> createState() => _IntroFlowState();
}

class _IntroFlowState extends State<IntroFlow> {
  final _ctrl = PageController();
  int _page = 0;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
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
      bottomGradient: [Colors.white, Colors.white],
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
        return MatchCardsIllustration(parallaxOffset: localOffset);
      case 1:
        return SolarSystemIllustration(parallaxOffset: localOffset);
      case 2:
        return MusicConversationIllustration(parallaxOffset: localOffset);
      default:
        return const SizedBox();
    }
  }

  Future<void> _next() async {
    if (_page < 2) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_shown', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthWrapper(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: _screens.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (ctx, i) {
              final s = _screens[i];
              return SplitScreenShell(
                topGradient: s.topGradient,
                bottomGradient: s.bottomGradient,
                illustration: _getIllustration(i, _scrollOffset), // Dynamic Parallax
                title: s.title,
                subtitle: s.subtitle,
                extras: _DotIndicators(count: 3, active: i),
                cta: _IntroCTA(
                  isLast: s.isLast,
                  onTap: _next,
                ),
              );
            },
          ),
          // Skip button — top right, minimal style
          if (_page < 2)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 24,
              child: GestureDetector(
                onTap: _finish,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    fontFamily: 'Circular',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F0B1A).withOpacity(0.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── CTA button ────────────────────────────────────────────────────────────────
class _IntroCTA extends StatelessWidget {
  final bool isLast;
  final VoidCallback onTap;

  const _IntroCTA({required this.isLast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 58, 
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFFB3D9), Color(0xFFB69CFF)], // Softer gradient from ref
          ),
          borderRadius: BorderRadius.circular(29),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5FA2).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          isLast ? 'Get Started' : 'next →',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Circular',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F0B1A), // Black text as per ref
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

// ── Dot indicators ────────────────────────────────────────────────────────────
class _DotIndicators extends StatelessWidget {
  final int count;
  final int active;

  const _DotIndicators({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) => AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
        width: i == active ? 24 : 6,
        height: 6,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: i == active
              ? const Color(0xFFFF7DB8)
              : const Color(0xFF0F0B1A).withOpacity(0.25),
          borderRadius: BorderRadius.circular(3),
        ),
      )),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────
class _IntroData {
  final List<Color> topGradient;
  final List<Color>? bottomGradient;
  final String title;
  final String subtitle;
  final bool isLast;

  const _IntroData({
    required this.topGradient,
    this.bottomGradient,
    required this.title,
    required this.subtitle,
    required this.isLast,
  });
}
