// lib/pages/wav_page.dart
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/songs_provider.dart';
import '../models/song.dart';
import '../widgets/card_stack_controller.dart';
import 'card_stack.dart';

const _pink   = Color(0xFFFF6FE8);
const _purple = Color(0xFFB69CFF);
const _blue   = Color(0xFF7BA7FF);
const _dark   = Color(0xFF3A2A45);

// ── Mood → subtle background tint ─────────────────────────────
Color _moodTint(String mood) {
  switch (mood.toLowerCase()) {
    case 'happy':       return const Color(0xFFFF6FE8); // hot pink
    case 'energetic':   return const Color(0xFFFF6B2B); // vivid orange
    case 'chill':       return const Color(0xFF4A90FF); // bright blue
    case 'melancholic': return const Color(0xFF9B59FF); // deep violet
    case 'reflective':  return const Color(0xFF00C9B1); // teal
    case 'sad':         return const Color(0xFF3A6FFF); // electric blue
    default:            return const Color(0xFFB69CFF); // lavender
  }
}

class WavPage extends StatefulWidget {
  final ValueChanged<Color>? onMoodChanged;
  final bool isIdle;
  final bool isActive;

  const WavPage({
    super.key,
    this.isIdle = false,
    this.isActive = false,
    this.onMoodChanged,
  });

  @override
  State<WavPage> createState() => _WavPageState();
}

class _WavPageState extends State<WavPage>
    with TickerProviderStateMixin {
  final CardStackController _cardController = CardStackController();

  bool _dislikeHovered  = false;
  bool _dislikePressed  = false;
  bool _likeHovered     = false;
  bool _likePressed     = false;
  bool _isCardPaused    = false;
  bool _previewsEnabled = true;

  final ValueNotifier<double> _likeDragProgress    = ValueNotifier(0.0);
  final ValueNotifier<double> _dislikeDragProgress = ValueNotifier(0.0);
  bool   _showLimitWarning    = false;

  late final AnimationController _shakeController;
  late final Animation<double>   _shakeAnimation;

  void _triggerLimitWarning() async {
    if (_showLimitWarning) return;
    
    // Double "error" buzz to match the physical shake
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 120), () {
      HapticFeedback.heavyImpact();
    });

    setState(() => _showLimitWarning = true);
    _shakeController.forward(from: 0.0);
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) setState(() => _showLimitWarning = false);
    });
  }

  // ── Current top card (updated via onCardChanged) ──────────────
  Map<String, String> _currentSong = {};
  String _statsKey = '';

  // ── Gesture hints ─────────────────────────────────────────────
  bool _hintsVisible   = false;
  bool _hintsDismissed = true;

  // ── Shuffle button spin ────────────────────────────────────────
  late AnimationController _shuffleSpinController;

  // ── Waveform ──────────────────────────────────────────────────
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _shuffleSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -4.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    // Don't check tutorial here — IndexedStack mounts this before it's visible.
    // Wait for didUpdateWidget to fire when isActive becomes true.
  }

  @override
  void didUpdateWidget(WavPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _checkTutorialStatus();
    }
  }

  @override
  void dispose() {
    _cardController.detach();
    _waveController.dispose();
    _shuffleSpinController.dispose();
    _shakeController.dispose();
    _likeDragProgress.dispose();
    _dislikeDragProgress.dispose();
    super.dispose();
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final key = 'has_seen_wav_hints_$uid';
    final hasSeen = prefs.getBool(key) ?? false;
    
    if (!hasSeen) {
      if (mounted) {
        setState(() {
          _hintsVisible = true;
          _hintsDismissed = false;
        });
      }
      await prefs.setBool(key, true);
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted && !_hintsDismissed) _dismissHints();
      });
    }
  }

  void _dismissHints() {
    setState(() => _hintsVisible = false);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _hintsDismissed = true);
    });
  }

  void _onCardChanged(Map<String, String> song) {
    setState(() {
      _currentSong = song;
      _statsKey    = song['title'] ?? '';
      if (!_hintsDismissed) _dismissHints();
    });
    // Notify home_page so the full-screen tint updates
    widget.onMoodChanged?.call(_moodTint(song['mood'] ?? ''));
  }

  // ── ODOMETER ──────────────────────────────────────────────────
  Widget _buildOdometerCounter(int value) {
    final digits = value.toString().split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: digits.asMap().entries.map((e) {
        return _OdometerDigit(
          digit: e.value,
          key: ValueKey('digit_pos_${e.key}'),
        );
      }).toList(),
    );
  }

  // ── LIKES PILL ────────────────────────────────────────────────
  Widget _buildLikesPill(int likesLeft) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shakeAnimation.value, 0),
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _pink.withOpacity(0.3), width: 1),
        ),
        child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_rounded, color: _pink, size: 13),
          const SizedBox(width: 6),
          Text(
            'Daily likes: ',
            style: TextStyle(
              fontFamily: 'Circular',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _dark.withOpacity(0.85),
            ),
          ),
          _buildOdometerCounter(likesLeft),
        ],
      ), // closes Row
      ), // closes Container
    ); // closes AnimatedBuilder
  }

  // ── WAVEFORM TOGGLE ───────────────────────────────────────────
  Widget _buildWaveform() {
    final globalOn             = _previewsEnabled;
    final isEffectivelyPlaying = _previewsEnabled && !_isCardPaused;

    return GestureDetector(
      onTap: () => setState(() => _previewsEnabled = !_previewsEnabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: globalOn
              ? Colors.white.withOpacity(0.08)
              : _dark.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: globalOn
                ? _pink.withOpacity(0.3)
                : _dark.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                globalOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                key: ValueKey(globalOn),
                color: globalOn ? _pink : _dark.withOpacity(0.5),
                size: 13,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _waveController,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(5, (i) {
                  final phase =
                      (i * 0.22 + _waveController.value) % 1.0;
                  final h = isEffectivelyPlaying
                      ? (4.0 + 11.0 * math.sin(phase * math.pi).abs())
                      : 3.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 3,
                      height: h,
                      decoration: BoxDecoration(
                        color: globalOn ? _pink : _dark.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SHUFFLE BUTTON ────────────────────────────────────────────
  Widget _buildShuffleButton() {
    return GestureDetector(
      onTap: () {
        _cardController.shuffle();
        _shuffleSpinController.forward(from: 0.0);
      },
      child: AnimatedBuilder(
        animation: _shuffleSpinController,
        builder: (_, child) => Transform.rotate(
          angle: Tween(begin: 0.0, end: math.pi * 2).evaluate(
            CurvedAnimation(
              parent: _shuffleSpinController,
              curve: Curves.elasticOut,
            ),
          ),
          child: child,
        ),
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.55),
            border: Border.all(color: _purple.withOpacity(0.35), width: 1),
          ),
          child: Icon(
            Icons.shuffle_rounded,
            color: _purple.withOpacity(0.85),
            size: 14,
          ),
        ),
      ),
    );
  }

  // ── STATS ROW — animated on card change ───────────────────────
  Widget _buildStatsRow() {
    if (_currentSong.isEmpty) return const SizedBox(height: 54);
    final song = _currentSong;
    final bpm  = song['bpm']  ?? '';
    final key  = song['key']  ?? '';
    final mood = song['mood'] ?? '';

    final keyParts = key.split(' ');
    final keyNote  = keyParts.isNotEmpty ? keyParts.first : key;
    final keyQual  = keyParts.length > 1
        ? keyParts.sublist(1).join(' ').toUpperCase()
        : '';


    // Fixed 3-column layout — each stat always occupies exactly 1/3 width
    // so positions never shift between cards with different data lengths.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve:  Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: child,
      ),
      child: SizedBox(
        key: ValueKey(_statsKey),
        height: 58,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TEMPO — always in left third
            Expanded(
              child: bpm.isNotEmpty && bpm != '0'
                  ? AnimatedBpmStat(bpmString: bpm)
                  : const SizedBox.shrink(),
            ),
            // Divider
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(width: 1, height: 28, color: _dark.withOpacity(0.1)),
            ),
            // KEY — always in centre third
            Expanded(
              child: key.isNotEmpty
                  ? AnimatedKeyStat(keyNote: keyNote, keyQual: keyQual)
                  : const SizedBox.shrink(),
            ),
            // Divider
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(width: 1, height: 28, color: _dark.withOpacity(0.1)),
            ),
            // MOOD — always in right third, distinctive coloured pill
            Expanded(
              child: mood.isNotEmpty
                  ? AnimatedMoodStat(
                      mood: mood,
                      symbol: _moodSymbol(mood),
                      tint: _moodTint(mood),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  String _moodSymbol(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':       return '✦';
      case 'energetic':   return '⚡';
      case 'chill':       return '◎';
      case 'melancholic': return '◈';
      case 'reflective':  return '◇';
      case 'sad':         return '◉';
      default:            return '✦';
    }
  }

  // ── GESTURE HINTS ─────────────────────────────────────────────
  Widget _buildGestureHints() {
    // When dismissed, return fully transparent — parent SizedBox(height:32)
    // holds the space so nothing shifts position.
    if (_hintsDismissed) return const SizedBox.expand();

    return AnimatedOpacity(
      opacity: _hintsVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: _dismissHints,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _hintChip(Icons.touch_app_rounded, 'double tap to expand'),
            const SizedBox(width: 8),
            _hintChip(Icons.flip_rounded, 'tap icon to flip'),
          ],
        ),
      ),
    );
  }

  Widget _hintChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _dark.withOpacity(0.1), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _dark.withOpacity(0.55)),
          const SizedBox(width: 5),
          Text(label,
            style: TextStyle(
              fontFamily: 'Circular',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _dark.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }

  // ── MAIN BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<SongsProvider>(
      builder: (context, songsProvider, _) {
        if (songsProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final songs     = songsProvider.songs.map((s) => s.toSwipeMap()).toList();
        final likesLeft = songsProvider.likesLeft;

        // Seed _currentSong synchronously — safe because we're in build,
        // not in a callback, and the map is always non-null.
        if (_currentSong.isEmpty && songs.isNotEmpty) {
          _currentSong = songs.first;
          _statsKey    = songs.first['title'] ?? '';
          // Seed the home_page tint immediately
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onMoodChanged?.call(
                _moodTint(songs.first['mood'] ?? ''));
          });
        }

        final sw = MediaQuery.of(context).size.width;
        final sh = MediaQuery.of(context).size.height;

        final hPad       = (sw * 0.05).clamp(16.0, 32.0);
        final topPad     = (sh * 0.008).clamp(4.0, 12.0);
        final btnSize    = (sw * 0.15).clamp(48.0, 68.0);
        final btnSpacing = (sw * 0.12).clamp(40.0, 80.0);
        final bottomPad  = (sh * 0.015).clamp(8.0, 20.0);

        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            // ── PASS (UP) GLOW ──
            Positioned(
              top: -200,
              left: -100,
              right: -100,
              bottom: 0,
              child: ValueListenableBuilder<double>(
                valueListenable: _dislikeDragProgress,
                builder: (_, progress, child) => AnimatedOpacity(
                  opacity: progress,
                  duration: Duration(milliseconds: progress == 0.0 ? 350 : 0),
                  curve: Curves.easeOut,
                  child: child,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.2,
                      colors: [
                        const Color(0xFFFF2A2A).withOpacity(0.85),
                        Colors.transparent,
                      ],
                      stops: const [0.3, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // ── LIKE (DOWN) GLOW ──
            Positioned(
              top: 0,
              left: -100,
              right: -100,
              bottom: -200,
              child: ValueListenableBuilder<double>(
                valueListenable: _likeDragProgress,
                builder: (_, progress, child) => AnimatedOpacity(
                  opacity: progress,
                  duration: Duration(milliseconds: progress == 0.0 ? 350 : 0),
                  curve: Curves.easeOut,
                  child: child,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.bottomCenter,
                      radius: 1.2,
                      colors: [
                        const Color(0xFF00FF66).withOpacity(0.85),
                        Colors.transparent,
                      ],
                      stops: const [0.3, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: topPad),

                    // ── Top bar ────────────────────────────
                    AnimatedOpacity(
                      opacity: widget.isIdle ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeInOut,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLikesPill(likesLeft),
                          Row(
                            children: [
                              _buildShuffleButton(),
                              const SizedBox(width: 10),
                              _buildWaveform(),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (kDebugMode)
                      TextButton.icon(
                        onPressed: () => songsProvider.restoreLikes(),
                        icon: const Icon(Icons.restore,
                            color: Colors.white70, size: 14),
                        label: const Text('Restore (test)',
                          style: TextStyle(
                            fontFamily: 'Circular',
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    // ── Gesture hints — always 32px tall to prevent layout shift ──
                    // Content fades out but space is always reserved.
                    SizedBox(
                      height: 32,
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: widget.isIdle ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 1500),
                          child: _buildGestureHints()
                        )
                      ),
                    ),

                    // ── Card stack ─────────────────────────
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            // Never shorter than 340px regardless of screen
                            minHeight: (sh * 0.42).clamp(340.0, double.infinity),
                          ),
                          child: SizedBox(
                            width: sw * 0.92,
                            child: CardStack(
                            isIdle: widget.isIdle,
                            controller: _cardController,
                            songs: songs,
                            canLike: likesLeft > 0,
                            onPauseStateChanged: (isPaused) =>
                                setState(() => _isCardPaused = isPaused),
                            onCardChanged: _onCardChanged,
                            onSwipeThreshold: (isLiking, isDisliking) {
                              if (_likeHovered == isLiking &&
                                  _dislikeHovered == isDisliking) return;
                              
                              // Haptic tick when passing the threshold
                              if (isLiking || isDisliking) {
                                HapticFeedback.lightImpact();
                              }

                              setState(() {
                                _likeHovered    = isLiking;
                                _dislikeHovered = isDisliking;
                              });
                            },
                            onDragUpdate: (likeProg, passProg) {
                              _likeDragProgress.value    = likeProg;
                              _dislikeDragProgress.value = passProg;
                            },
                            onLike: (song) async {
                              final s = Song(
                                title:    song['title']  ?? '',
                                artist:   song['artist'] ?? '',
                                genre:    song['genre']  ?? '',
                                mood:     song['mood']   ?? '',
                                bpm:      int.tryParse(song['bpm'] ?? '0') ?? 0,
                                key:      song['key']    ?? '',
                                imageUrl: song['image']  ?? '',
                              );
                              if (likesLeft <= 0) {
                                _triggerLimitWarning();
                                return;
                              }
                              await songsProvider.swipeLike(s);
                            },
                            onDislike: (song) async {
                              final s = Song(
                                title:    song['title']  ?? '',
                                artist:   song['artist'] ?? '',
                                genre:    song['genre']  ?? '',
                                mood:     song['mood']   ?? '',
                                bpm:      int.tryParse(song['bpm'] ?? '0') ?? 0,
                                key:      song['key']    ?? '',
                                imageUrl: song['image']  ?? '',
                              );
                              await songsProvider.swipeDislike(s);
                            },
                          ),
                        ),
                        ),
                      ),
                    ),

                    // ── Stats row ──────────────────────────
                    AnimatedOpacity(
                      opacity: widget.isIdle ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeInOut,
                      child: _buildStatsRow(),
                    ),

                    const SizedBox(height: 4),

                    // ── Action buttons ─────────────────────
                    AnimatedOpacity(
                      opacity: widget.isIdle ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeInOut,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: bottomPad),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          // Dislike
                          _buildActionButton(
                            assetPath:     'assets/images/dislike.png',
                            dragProgress:  _dislikeDragProgress,
                            isHovered:     _dislikeHovered,
                            isPressed:     _dislikePressed,
                            isEnabled:     true,
                            onHoverChange: (v) =>
                                setState(() => _dislikeHovered = v),
                            onPressChange: (v) =>
                                setState(() => _dislikePressed = v),
                            onTap: () {
                              if (!_hintsDismissed) return;
                              _cardController.dislike();
                            },
                            size: btnSize,
                          ),

                          SizedBox(width: btnSpacing),

                          // Like button
                          _buildActionButton(
                                assetPath:     'assets/images/like.png',
                                dragProgress:  _likeDragProgress,
                                isHovered:     _likeHovered,
                                isPressed:     _likePressed,
                                isEnabled:     likesLeft > 0,
                                onHoverChange: (v) {
                                  if (likesLeft > 0)
                                    setState(() => _likeHovered = v);
                                },
                                onPressChange: (v) {
                                  if (likesLeft > 0)
                                    setState(() => _likePressed = v);
                                },
                                onTap: () {
                                  if (!_hintsDismissed) return;
                                  if (likesLeft <= 0) {
                                    _triggerLimitWarning();
                                    return;
                                  }
                                  _cardController.like();
                                },
                                size: btnSize,
                          ),
                        ],
                      ),
                    ),
                  ), // closes AnimatedOpacity
                ],
                ),
              ),
            ),

            // ── CINEMATIC OVERLAY ────────────────────────
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: widget.isIdle ? 1.0 : 0.0),
              // Match the card_stack idle scale timing (30s forward, 400ms reverse)
              duration: Duration(milliseconds: widget.isIdle ? 30000 : 400),
              curve: Curves.easeOutQuad,
              builder: (context, val, child) {
                // Fade in smoothly only after 90% (final 3 seconds) of the cinematic scaling
                final overlayIntro = ((val - 0.90) / 0.10).clamp(0.0, 1.0);
                return Positioned(
                  bottom: -100 + (140 * overlayIntro), // Slides from -100 to 40
                  left: 24,
                  right: 24,
                  child: Opacity(
                    opacity: overlayIntro,
                    child: child,
                  ),
                );
              },
              child: _buildCinematicOverlay(_currentSong),
            ),

            // ── TOP TOAST: Out of Likes ──
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1500),
              curve: _showLimitWarning ? Curves.bounceOut : Curves.easeInCubic,
              top: _showLimitWarning ? 76.0 : -250.0,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeInOut,
                  opacity: _showLimitWarning ? 1.0 : 0.0,
                  child: AnimatedScale(
                    scale: _showLimitWarning ? 1.0 : 0.7,
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.elasticOut,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF2a1245).withOpacity(0.55),
                                const Color(0xFF1a0a2e).withOpacity(0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: const Color(0xFFFF6FE8).withOpacity(0.45),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6FE8).withOpacity(0.18),
                                blurRadius: 24,
                                spreadRadius: 0,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 16,
                                spreadRadius: -2,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFFFF6FE8).withOpacity(0.25),
                                      const Color(0xFFFF6FE8).withOpacity(0.08),
                                    ],
                                  ),
                                ),
                                child: const Icon(Icons.auto_awesome,
                                    color: Color(0xFFFF6FE8), size: 14),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "Out of vibes. Come back tomorrow!",
                                style: TextStyle(
                                  fontFamily: 'Circular',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── CINEMATIC OVERLAY ───────────────────────────────────────────
  Widget _buildCinematicOverlay(Map<String, String> song) {
    if (song.isEmpty) return const SizedBox();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (song['image'] != null && song['image']!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              song['image']!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                song['title'] ?? '',
                style: const TextStyle(
                  fontFamily: 'Circular',
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                song['artist'] ?? '',
                style: const TextStyle(
                  fontFamily: 'Circular',
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── ACTION BUTTON ─────────────────────────────────────────────
  Widget _buildActionButton({
    required String assetPath,
    required bool isHovered,
    required bool isPressed,
    required bool isEnabled,
    ValueNotifier<double>? dragProgress,
    required Function(bool) onHoverChange,
    required Function(bool) onPressChange,
    required VoidCallback onTap,
    required double size,
  }) {
    Widget button = Opacity(
      opacity: isEnabled ? 1.0 : 0.3,
      child: MouseRegion(
        onEnter: (_) => onHoverChange(true),
        onExit:  (_) => onHoverChange(false),
        child: GestureDetector(
          onTapDown:   (_) => onPressChange(true),
          onTapUp:     (_) { onPressChange(false); HapticFeedback.selectionClick(); },
          onTapCancel: ()  => onPressChange(false),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..translate(0.0,
                  isPressed ? 4.0 : (isHovered ? -6.0 : 0.0), 0.0)
              ..scale(isPressed ? 0.95 : (isHovered ? 1.08 : 1.0)),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: isPressed ? 0.7 : 1.0,
              child: Image.asset(assetPath,
                  width: size, height: size, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );

    if (dragProgress == null) return button;

    return ValueListenableBuilder<double>(
      valueListenable: dragProgress,
      builder: (context, progress, child) {
        // Direct scale connection matching vertical drag intensity
        final scale = 1.0 + (progress * 0.25);
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: button,
    );
  }
}

// ── ODOMETER DIGIT ────────────────────────────────────────────
class _OdometerDigit extends StatefulWidget {
  final String digit;
  const _OdometerDigit({required this.digit, required Key key})
      : super(key: key);

  @override
  State<_OdometerDigit> createState() => _OdometerDigitState();
}

class _OdometerDigitState extends State<_OdometerDigit>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double>   _slideAnimation;
  late Animation<double>   _fadeOutAnimation;
  late Animation<double>   _fadeInAnimation;

  String? _oldDigit;
  String  _currentDigit = '';

  @override
  void initState() {
    super.initState();
    _currentDigit     = widget.digit;
    _controller       = AnimationController(
        duration: const Duration(milliseconds: 1800), vsync: this);
    _slideAnimation   = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeInAnimation  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_OdometerDigit old) {
    super.didUpdateWidget(old);
    if (old.digit != widget.digit) {
      _oldDigit     = _currentDigit;
      _currentDigit = widget.digit;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final animating = _controller.status == AnimationStatus.forward ||
        _controller.status == AnimationStatus.reverse;

    return SizedBox(
      width: 14, height: 28,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => ClipRect(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_oldDigit != null && animating)
                Transform.translate(
                  offset: Offset(0, -42 * _slideAnimation.value),
                  child: Opacity(
                    opacity: _fadeOutAnimation.value,
                    child: Text(_oldDigit!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Circular',
                        color: _dark,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(0,
                    animating ? 42 * (1 - _slideAnimation.value) : 0),
                child: Opacity(
                  opacity: animating ? _fadeInAnimation.value : 1.0,
                  child: Text(_currentDigit,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Circular',
                      color: _dark,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── STATIC BPM STAT ───────────────────────────────────────────
class AnimatedBpmStat extends StatelessWidget {
  final String bpmString;
  const AnimatedBpmStat({super.key, required this.bpmString});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'TEMPO',
          style: TextStyle(
            fontFamily: 'Circular',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: _dark.withOpacity(0.38),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          bpmString,
          style: const TextStyle(
            fontFamily: 'Circular',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _dark,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'BPM',
          style: TextStyle(
            fontFamily: 'Circular',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _dark.withOpacity(0.32),
          ),
        ),
      ],
    );
  }
}

// ── ANIMATED KEY STAT ───────────────────────────────────────────
class AnimatedKeyStat extends StatefulWidget {
  final String keyNote;
  final String keyQual;

  const AnimatedKeyStat({
    super.key,
    required this.keyNote,
    required this.keyQual,
  });

  @override
  State<AnimatedKeyStat> createState() => _AnimatedKeyStatState();
}

class _AnimatedKeyStatState extends State<AnimatedKeyStat>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _breatheAnimation = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.keyNote.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'KEY',
          style: TextStyle(
            fontFamily: 'Circular',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: _dark.withOpacity(0.38),
          ),
        ),
        const SizedBox(height: 3),
        AnimatedBuilder(
          animation: _breatheAnimation,
          builder: (context, child) {
            return Text(
              widget.keyNote,
              style: TextStyle(
                fontFamily: 'Circular',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _dark,
                height: 1.0,
                shadows: [
                  Shadow(
                    color: _purple.withOpacity(_breatheAnimation.value),
                    blurRadius: 8.0,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 2),
        Text(
          widget.keyQual,
          style: TextStyle(
            fontFamily: 'Circular',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _dark.withOpacity(0.32),
          ),
        ),
      ],
    );
  }
}

// ── ANIMATED MOOD STAT ──────────────────────────────────────────
class AnimatedMoodStat extends StatefulWidget {
  final String mood;
  final String symbol;
  final Color tint;

  const AnimatedMoodStat({
    super.key,
    required this.mood,
    required this.symbol,
    required this.tint,
  });

  @override
  State<AnimatedMoodStat> createState() => _AnimatedMoodStatState();
}

class _AnimatedMoodStatState extends State<AnimatedMoodStat>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mood.isEmpty) return const SizedBox.shrink();

    final m = widget.mood.toLowerCase();

    // Dynamic Colors
    List<Color> shimmerColors;
    if (m == 'energetic') {
      shimmerColors = [
        Colors.orange.shade400,
        Colors.yellow.shade300,
        Colors.orange.shade400
      ];
    } else if (m == 'chill' || m == 'melancholic') {
      shimmerColors = [
        Colors.cyan.shade400,
        Colors.purple.shade300,
        Colors.cyan.shade400
      ];
    } else if (m == 'happy') {
      shimmerColors = [
        const Color(0xFFFF6FE8),
        Colors.white,
        const Color(0xFFFF6FE8)
      ];
    } else {
      shimmerColors = [widget.tint, Colors.white, widget.tint];
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'MOOD',
          style: TextStyle(
            fontFamily: 'Circular',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: _dark.withOpacity(0.38),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: widget.tint.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: widget.tint.withOpacity(0.45), width: 1),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: shimmerColors,
                    stops: const [0.0, 0.5, 1.0],
                    begin: Alignment(-2.0 + (_controller.value * 4.0), 0.0),
                    end: Alignment(0.0 + (_controller.value * 4.0), 0.0),
                  ).createShader(bounds);
                },
                child: child,
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.symbol,
                  style: const TextStyle(fontSize: 9, color: Colors.white),
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.mood.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Circular',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}