import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isFinishing = false;
  bool _userDragging = false;
  bool _isNavigating = false; // Prevents auto-advance from fighting manual nav

  // Fast-forward overlay animation
  late AnimationController _ffOverlayCtrl;
  bool _showFastForward = false;

  static const int _totalSlides = 3;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45), // 15 seconds per slide
    )..addListener(_onProgressTick);

    _ffOverlayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _progressCtrl.forward();

    _ctrl.addListener(() {
      if (!mounted) return;
      final page = _ctrl.hasClients ? _ctrl.page ?? 0.0 : 0.0;
      setState(() {
        _scrollOffset = page;
      });
      // While user is dragging (not during skip), sync the progress bar to the scroll position
      if (_userDragging && !_isFinishing) {
        _progressCtrl.value = (page / _totalSlides).clamp(0.0, 1.0);
      }
    });
  }

  void _onProgressTick() {
    if (_isNavigating) return; // Don't auto-advance during programmatic navigation
    if (!mounted || !_isPlaying || _userDragging || _isFinishing) return;

    final targetPage = (_progressCtrl.value * _totalSlides).floor().clamp(0, _totalSlides - 1);

    if (_progressCtrl.value >= 1.0) {
      _finish();
    } else if (targetPage > _page) {
      _goToPage(targetPage);
    }

    if (mounted) setState(() {});
  }

  static const _screens = [
    _IntroData(
      topGradient: [Color(0xFFFFD4FF), Color(0xFFEDD4FF), Color(0xFFD8E8FF)],
      title: 'Match through\nmusic',
      subtitle:
          'Swipe songs, build your taste profile, and find people who hear the world the same way.',
    ),
    _IntroData(
      topGradient: [Color(0xFFEDD4FF), Color(0xFFD4E4FF), Color(0xFFFFD8F4)],
      title: 'Your taste,\nyour matches',
      subtitle:
          'Pick the genres and artists you love. wav finds people whose playlists sync with yours.',
    ),
    _IntroData(
      topGradient: [Color(0xFFD4E4FF), Color(0xFFEDD4FF), Color(0xFFFFD4FF)],
      title: 'Music starts\nthe conversation',
      subtitle:
          'When you match, share songs. No awkward openers — just let the music talk.',
    ),
  ];

  Widget _getIllustration(int index, double scrollOffset) {
    final double localOffset = index - scrollOffset;
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
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
    if (_page < 2) {
      _goToPage(_page + 1);
    } else {
      // On the last slide, Done button navigates to login
      _performNavigation();
    }
  }

  void _previous() {
    HapticFeedback.lightImpact();
    if (_page > 0) {
      _goToPage(_page - 1);
    }
  }

  void _goToPage(int target) {
    if (!mounted) return;
    _isNavigating = true; // Lock auto-advance
    setState(() {
      _page = target;
      _isPlaying = true;
    });

    _ctrl.animateToPage(
      target,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );

    _progressCtrl.animateTo(
      target / _totalSlides.toDouble(),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    ).then((_) {
      _isNavigating = false; // Unlock auto-advance
      if (mounted && _isPlaying && !_isFinishing) {
        _progressCtrl.forward();
      }
    });
  }

  // Skip: fast-forward to the end of slide 3, then stop
  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    if (_isFinishing) return;
    _isFinishing = true;
    _userDragging = false;

    if (!mounted) return;
    setState(() {
      _isPlaying = true;
      _showFastForward = true;
    });

    // Start the fast-forward overlay animation
    _ffOverlayCtrl.repeat();

    // Premium Fast Forward: Sweep both slides and progress bar to the very end
    final remaining = (1.0 - _progressCtrl.value).clamp(0.0, 1.0);
    final ms = (remaining * 2000).clamp(800.0, 1500.0).toInt();
    final animDuration = Duration(milliseconds: ms);

    await Future.wait([
      _ctrl.animateToPage(
        2,
        duration: animDuration,
        curve: Curves.easeInOutCubic,
      ),
      _progressCtrl.animateTo(
        1.0,
        duration: animDuration,
        curve: Curves.easeInOutCubic,
      ),
    ]);

    // Land on slide 3 at the endpoint — user clicks Done to proceed
    if (mounted) {
      setState(() {
        _page = 2;
        _scrollOffset = 2.0;
        _isFinishing = false;
      });
    }

    // Stop the fast-forward overlay, keep playing so illustrations continue
    _ffOverlayCtrl.stop();
    _progressCtrl.stop(); // Bar is full, no need to advance further
    if (mounted) setState(() => _showFastForward = false);
  }

  Future<void> _performNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_shown', true);
    
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthWrapper(),
        transitionsBuilder: (_, anim, __, child) {
          final curvedAnim = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curvedAnim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(curvedAnim),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  @override
  void dispose() {
    _progressCtrl.removeListener(_onProgressTick);
    _ctrl.dispose();
    _progressCtrl.dispose();
    _ffOverlayCtrl.dispose();
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
            // Use NotificationListener to reliably detect drag start/end
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (_isFinishing) return false;
                if (notification is ScrollStartNotification &&
                    notification.dragDetails != null) {
                  _userDragging = true;
                  _progressCtrl.stop();
                } else if (notification is ScrollEndNotification) {
                  _userDragging = false;
                  if (_isPlaying && !_isFinishing && mounted) {
                    _progressCtrl.forward();
                  }
                }
                return false;
              },
              child: ScrollConfiguration(
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
                    if (_isFinishing || !mounted) return;
                    setState(() => _page = i);
                  },
                  itemBuilder: (ctx, i) {
                    final s = _screens[i];
                    return _KeepAlivePage(
                      child: SplitScreenShell(
                        topGradient: s.topGradient,
                        illustration: _getIllustration(i, _scrollOffset),
                        title: s.title,
                        subtitle: s.subtitle,
                        cta: const SizedBox(height: 160),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Cartoon Fast-Forward Overlay ──
            if (_showFastForward)
              AnimatedBuilder(
                animation: _ffOverlayCtrl,
                builder: (context, child) {
                  return CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: _FastForwardPainter(
                      progress: _ffOverlayCtrl.value,
                    ),
                  );
                },
              ),

            // ── Minimal Top Skip Button ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 24,
              child: GestureDetector(
                onTap: _finish,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Icon(
                    Icons.fast_forward_rounded,
                    size: 30,
                    color: Colors.white.withOpacity(0.9),
                  ),
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
                progressValue: _progressCtrl.value,
                isPlaying: _isPlaying,
                onPlayToggle: _togglePlay,
                onNext: _next,
                onPrevious: _previous,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cartoon Fast-Forward Speed Lines Painter ──
class _FastForwardPainter extends CustomPainter {
  final double progress;

  _FastForwardPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42); // Fixed seed for consistent line positions
    final lineCount = 18;

    for (int i = 0; i < lineCount; i++) {
      // Each line has its own phase offset so they stagger
      final phase = (progress + i / lineCount) % 1.0;
      
      // Lines sweep from right to left (like fast-forwarding)
      final y = rng.nextDouble() * size.height;
      final lineLength = 40.0 + rng.nextDouble() * 120.0;
      
      // Animate: start from right, sweep to the left
      final x = size.width * (1.0 - phase * 1.4);
      
      // Fade in then fade out across the sweep
      final opacity = (phase < 0.3)
          ? (phase / 0.3)
          : (phase > 0.7)
              ? ((1.0 - phase) / 0.3)
              : 1.0;
      
      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0) * 0.25)
        ..strokeWidth = 1.5 + rng.nextDouble() * 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, y),
        Offset(x - lineLength, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FastForwardPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MusicPlayerNavigation extends StatelessWidget {
  final int page;
  final double progressValue;
  final bool isPlaying;
  final VoidCallback onPlayToggle;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const _MusicPlayerNavigation({
    required this.page,
    required this.progressValue,
    required this.isPlaying,
    required this.onPlayToggle,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  Widget build(BuildContext context) {
    final double displayProgress = progressValue.clamp(0.0, 1.0);
    final bool isLast = page == 2;

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
          // ── Song Progress Bar (Spotify Style) with Scrub Knob ──
          SizedBox(
            height: 14, // Room for the knob
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // Track background
                Container(
                  width: double.infinity,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Filled portion
                Container(
                  width: (MediaQuery.of(context).size.width - 48) * displayProgress,
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
                // Scrub knob
                Positioned(
                  left: (MediaQuery.of(context).size.width - 48) * displayProgress - 6,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFAFFFE), // nearly white cyan
                          Color(0xFFFBFAFF), // nearly white purple
                          Color(0xFFFFFAFE), // nearly white pink
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8E7CFF).withOpacity(0.5),
                          blurRadius: isPlaying ? 10 : 4,
                          spreadRadius: isPlaying ? 2 : 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
              const SizedBox(width: 24),

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
              const SizedBox(width: 24),

              // Next / Done Button
              IconButton(
                onPressed: onNext,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: Icon(
                    isLast ? Icons.check_circle_rounded : Icons.skip_next_rounded,
                    key: ValueKey(isLast ? 'done' : 'next'),
                    size: 36,
                    color: isLast ? const Color(0xFF1DB954) : Colors.white,
                  ),
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

  const _IntroData({
    required this.topGradient,
    required this.title,
    required this.subtitle,
  });
}

// Keeps PageView children alive so their animation state isn't lost
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

