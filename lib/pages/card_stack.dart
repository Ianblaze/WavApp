// lib/pages/card_stack.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/card_stack_controller.dart';

const _pink   = Color(0xFFFF6FE8);
const _purple = Color(0xFFB69CFF);
const _blue   = Color(0xFF7BA7FF);

const double _cardW = 220.0;
const double _cardH = 300.0;

// ─────────────────────────────────────────────────────────────
class CardStack extends StatefulWidget {
  final List<Map<String, String>> songs;
  final Future<void> Function(Map<String, String>)? onLike;
  final Future<void> Function(Map<String, String>)? onDislike;
  final bool canLike;
  final Function(bool isLiking, bool isDisliking)? onSwipeThreshold;
  final Function(double likeProgress, double passProgress)? onDragUpdate;
  final CardStackController? controller;
  final ValueChanged<bool>? onPauseStateChanged;
  // Fires with the new top song whenever the card advances
  final ValueChanged<Map<String, String>>? onCardChanged;
  final bool isIdle;

  const CardStack({
    super.key,
    required this.songs,
    this.onLike,
    this.onDislike,
    this.canLike = true,
    this.onSwipeThreshold,
    this.onDragUpdate,
    this.controller,
    this.onPauseStateChanged,
    this.onCardChanged,
    this.isIdle = false,
  });

  @override
  State<CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<CardStack> with TickerProviderStateMixin {
  int    displayIndex    = 0;
  bool   isAnimating     = false;
  bool   isExiting       = false;
  bool   _isPaused       = false;
  bool   _wasIdleOnPointerDown = false;
  bool   _isExpanding    = false;
  int    _buttonSwipeDir  = 0; // 1=like, -1=dislike, 0=none
  // Track previous threshold state — only fire callback on transitions
  bool   _wasLiking      = false;
  bool   _wasDisliking   = false;

  // ValueNotifier so pan updates never call setState — only the card rebuilds
  final ValueNotifier<Offset> _cardOffsetNotifier = ValueNotifier(Offset.zero);
  Offset get cardOffset => _cardOffsetNotifier.value;
  set cardOffset(Offset v) => _cardOffsetNotifier.value = v;

  // ── local song list — shuffleable copy of widget.songs ─────
  late List<Map<String, String>> _localSongs;

  // ── shuffle animation controller ──────────────────────────
  late final AnimationController _shuffleController;

  // ── 3D flip state ─────────────────────────────────────────
  // Stores song titles of cards currently showing their back face.
  // Cleared on swipe; individual card removed on double-tap expand
  // so the Hero always flies from the front face.
  final Set<String> _flippedCards = {};

  // ── exit rotation ─────────────────────────────────────────
  late final AnimationController _rotationController;
  late final Animation<double>   _rotationAnimation;

  // ── card exit animation ──────────────────────────────────────
  late AnimationController _exitController;
  late Animation<double>   _exitValue; // 0.0 = rest, 1.0 = fully exited

  // ── snap-back spring ──────────────────────────────────────────
  // Drives elastic return when drag released below threshold.
  // We run a manual spring simulation via addListener for full control.
  late AnimationController _snapController;

  // ── subtle expand squish ───────────────────────────────────
  // Drives a gentle bob on the card simultaneously with the Hero.
  // Subtlety is key — small values, slow settle.
  late final AnimationController _expandController;
  late final Animation<double>   _squishX; // narrow → slightly wide → 1.0
  late final Animation<double>   _squishY; // tall   → slightly short → 1.0
  late final Animation<double>   _tiltX;   // subtle perspective lean
  late final Animation<double>   _bobY;    // tiny vertical float

  // ── hint bob ──────────────────────────────────────────────
  late final AnimationController _bobController;
  late final Animation<double>   _bobValue;
  late final Animation<double>   _likeHintOpacity;
  late final Animation<double>   _passHintOpacity;

  // ── hint fade ─────────────────────────────────────────────
  late final AnimationController _hintFadeController;
  late final Animation<double>   _hintFade;

  // ── idle scale ──────────────────────────────────────────
  late final AnimationController _idleScaleController;
  late final Animation<double>   _idleScale;

  // ── idle gimbal ───────────────────────────────────────────
  late final AnimationController _gimbalController;

  bool _hintActive    = true;
  bool _hintDismissed = false;

  static const double _bobAmplitude = 48.0;

  @override
  void initState() {
    super.initState();

    // ── exit rotation ────────────────────────────────────────
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    // Raw linear 0→1 — each card applies its own curve + stagger offset
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      _rotationController,  // linear, no curve here
    );

    // Exit: 600ms — deliberate, matches physical card throw
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Snap-back: runs spring simulation frame-by-frame
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // max duration, usually stops early
    );
    _exitValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );

    _localSongs = List<Map<String, String>>.from(widget.songs);

    _cardOffsetNotifier.addListener(() {
      if (widget.onDragUpdate != null) {
        final dy = _cardOffsetNotifier.value.dy;
        final double likeProg = (dy > 0) ? (dy / _commitThreshold).clamp(0.0, 1.0) : 0.0;
        final double passProg = (dy < 0) ? (-dy / _commitThreshold).clamp(0.0, 1.0) : 0.0;
        widget.onDragUpdate!(likeProg, passProg);
      }
    });

    _shuffleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    widget.controller?.attach(
      triggerLike:    triggerLike,
      triggerDislike: triggerDislike,
      triggerShuffle: _triggerShuffle,
    );

    // ── expand squish ─────────────────────────────────────────
    // 700ms total. Phases:
    //   0–20%   soft press-in  (compress gently)
    //   20–55%  snap-open      (spring wide, runs WITH Hero growth)
    //   55–100% elastic settle (gentle oscillation, elasticOut)
    //
    // Values are intentionally small — this is a bob, not a stretch.
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // scaleX: 1.0 → 0.95 (press) → 1.04 (snap) → 1.0 (settle)
    _squishX = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.95)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.95, end: 1.04)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.04, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 45,
      ),
    ]).animate(_expandController);

    // scaleY: inverse — 1.0 → 1.04 (press tall) → 0.97 (snap) → 1.0
    _squishY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.04)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.04, end: 0.97)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.97, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 45,
      ),
    ]).animate(_expandController);

    // Subtle perspective tilt — just 0.03 rad max
    _tiltX = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.03)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.03, end: -0.01)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.01, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45,
      ),
    ]).animate(_expandController);

    // Tiny vertical bob — just 3px up at peak
    _bobY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 2.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 2.0, end: -3.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -3.0, end: 0.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 45,
      ),
    ]).animate(_expandController);

    // ── hint bob ─────────────────────────────────────────────
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // 2s per cycle, smooth
    );

    _bobValue = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_bobController);

    _likeHintOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 6,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 38),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 6,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 50),
    ]).animate(_bobController);

    _passHintOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 50),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 6,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 38),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 6,
      ),
    ]).animate(_bobController);

    // ── hint fade ─────────────────────────────────────────────
    _hintFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _hintFade = CurvedAnimation(
      parent: _hintFadeController,
      curve: Curves.easeInOut,
    );

    // ── idle scale ────────────────────────────────────────────
    _idleScaleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
      reverseDuration: const Duration(milliseconds: 400),
    );
    _idleScale = CurvedAnimation(parent: _idleScaleController, curve: Curves.easeOutQuad);

    // ── idle gimbal ───────────────────────────────────────────
    _gimbalController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Drive card position from bobController so ValueListenableBuilder
    // sees the movement — without this the card stays still during hint.
    _bobController.addListener(() {
      if (_hintActive && !_hintDismissed) {
        _cardOffsetNotifier.value =
            Offset(0, _bobValue.value * _bobAmplitude);
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _hintFadeController.forward().then((_) {
        if (!mounted) return;
        // Two cycles: forward() twice in sequence
        _bobController.forward(from: 0.0).then((_) {
          if (!mounted || _hintDismissed) return;
          _bobController.forward(from: 0.0).then((_) {
            if (!mounted || _hintDismissed) return;
            _finishHint();
          });
        });
      });
    });
  }

  void _finishHint() {
    if (_hintDismissed) return;
    _hintDismissed = true;
    _bobController.stop();
    _cardOffsetNotifier.value = Offset.zero;
    _hintFadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _hintActive = false;
      });
    });
  }

  @override
  void didUpdateWidget(CardStack old) {
    super.didUpdateWidget(old);
    // Re-attach if controller instance changed (parent rebuild)
    if (old.controller != widget.controller) {
      old.controller?.detach();
      widget.controller?.attach(
        triggerLike:    triggerLike,
        triggerDislike: triggerDislike,
        triggerShuffle: _triggerShuffle,
      );
    }
    if (old.isIdle != widget.isIdle) {
      if (widget.isIdle) {
        // Lock out all taps from the moment we enter idle
        _wasIdleOnPointerDown = true;
        // Reset local interaction states before scaling natively starts
        setState(() {
          _flippedCards.clear();
        });
        
        // Let the current build frame finish before firing parent callbacks
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isPaused && mounted) _setPausedState(false);
        });
        
        // Start the controller immediately — the internal UI fade (0.0 to 1.5s)
        // runs first, while the card scaling (1.5s to 30s) is strictly gated
        // by the 0.05 threshold. This replaces the old Future.delayed(750ms).
        if (mounted && widget.isIdle) {
          _idleScaleController.forward();
        }
      } else {
        _idleScaleController.reverse();
        // Keep taps locked for 600ms after waking (well past the 400ms snapback)
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _wasIdleOnPointerDown = false;
        });
      }
    }

    // Sync _localSongs if provider delivers songs after initState
    if (old.songs != widget.songs &&
        _localSongs.isEmpty &&
        widget.songs.isNotEmpty) {
      setState(() {
        _localSongs = List<Map<String, String>>.from(widget.songs);
      });
      widget.onCardChanged?.call(_getLoopedSong(0));
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _rotationController.dispose();
    _exitController.dispose();
    _snapController.dispose();
    _shuffleController.dispose();
    _expandController.dispose();
    _bobController.dispose();
    _hintFadeController.dispose();
    _idleScaleController.dispose();
    _gimbalController.dispose();
    _cardOffsetNotifier.dispose();
    super.dispose();
  }

  // ── PUBLIC TRIGGERS ───────────────────────────────────────
  void triggerLike() {
    if (!isAnimating && widget.canLike) _handleLikeAnimation(false);
  }

  void triggerDislike() {
    if (!isAnimating) _handleDislikeAnimation(false);
  }

  Map<String, String> _getLoopedSong(int index) {
    if (_localSongs.isEmpty) {
      return {'title': '', 'artist': '', 'genre': '',
              'mood': '', 'bpm': '0', 'key': '', 'image': ''};
    }
    int looped = index % _localSongs.length;
    if (looped < 0) looped += _localSongs.length;
    return _localSongs[looped];
  }

  // Helper — syncs pause state and notifies parent
  void _setPausedState(bool paused) {
    if (_isPaused == paused) return;
    setState(() => _isPaused = paused);
    widget.onPauseStateChanged?.call(paused);
  }

  // ── EXIT ANIMATIONS ───────────────────────────────────────
  Future<void> _handleLikeAnimation(bool fromSwipe) async {
    if (isAnimating || !widget.canLike) return;

    HapticFeedback.mediumImpact();

    final currentSong = _getLoopedSong(displayIndex);
    if (widget.onLike != null) {
      widget.onLike!(currentSong);
    }

    setState(() { isAnimating = true; isExiting = true; _flippedCards.clear(); _buttonSwipeDir = 1; });
    _setPausedState(false);
    if (!fromSwipe) widget.onSwipeThreshold?.call(true, false);
    final startY = cardOffset.dy;
    const endY   = 700.0;
    _exitController.reset();
    // Drive exit with AnimationController — buttery 60fps, no manual loop
    _exitController.addListener(() {
      if (!mounted) return;
      _cardOffsetNotifier.value =
          Offset(0, startY + (endY - startY) * _exitValue.value);
    });
    await _exitController.forward();
    _exitController.clearListeners();
    if (!mounted) return;
    // Set isExiting=false directly (no setState) so _rotationAnimation
    // is used in back card transforms without triggering a rebuild.
    isExiting = false;
    await _rotationController.forward();
    if (!mounted) return;
    setState(() {
      displayIndex    = (displayIndex + 1) % _localSongs.length;
      cardOffset      = Offset.zero;
      isAnimating     = false;
      _hintActive     = false;
      _buttonSwipeDir = 0;
    });
    _cardOffsetNotifier.value = Offset.zero;
    if (!fromSwipe) widget.onSwipeThreshold?.call(false, false);
    _rotationController.reset();
    widget.onCardChanged?.call(_getLoopedSong(displayIndex));
  }

  Future<void> _handleDislikeAnimation(bool fromSwipe) async {
    if (isAnimating) return;

    HapticFeedback.mediumImpact();

    final currentSong = _getLoopedSong(displayIndex);
    if (widget.onDislike != null) {
      widget.onDislike!(currentSong);
    }

    setState(() { isAnimating = true; isExiting = true; _flippedCards.clear(); _buttonSwipeDir = -1; });
    _setPausedState(false);
    if (!fromSwipe) widget.onSwipeThreshold?.call(false, true);
    final startY = cardOffset.dy;
    const endY   = -700.0;
    _exitController.reset();
    _exitController.addListener(() {
      if (!mounted) return;
      _cardOffsetNotifier.value =
          Offset(0, startY + (endY - startY) * _exitValue.value);
    });
    await _exitController.forward();
    _exitController.clearListeners();
    if (!mounted) return;
    isExiting = false;
    await _rotationController.forward();
    if (!mounted) return;
    
    setState(() {
      displayIndex    = (displayIndex + 1) % _localSongs.length;
      cardOffset      = Offset.zero;
      isAnimating     = false;
      _hintActive     = false;
      _buttonSwipeDir = 0;
    });
    _cardOffsetNotifier.value = Offset.zero;
    if (!fromSwipe) widget.onSwipeThreshold?.call(false, false);
    _rotationController.reset();
    widget.onCardChanged?.call(_getLoopedSong(displayIndex));
  }

  // ── SHUFFLE ───────────────────────────────────────────────
  void _triggerShuffle() {
    if (isAnimating) return;
    _shuffleController.forward(from: 0.0);
    setState(() {
      // Pull current card, shuffle everything else, put current back at front.
      // Reset displayIndex to 0 so the full shuffled queue is always available.
      final current = _getLoopedSong(displayIndex);
      final others  = List<Map<String, String>>.from(_localSongs)
        ..removeWhere((s) => s['title'] == current['title'])
        ..shuffle();
      _localSongs  = [current, ...others];
      displayIndex = 0;
      _flippedCards.removeWhere((id) => id != (current['title'] ?? ''));
    });
    widget.onCardChanged?.call(_getLoopedSong(displayIndex));
  }

  // ── SINGLE TAP: toggle pause overlay ─────────────────────
  void _handleTap() {
    // `_wasIdleOnPointerDown` stays true for 600ms after the screen wakes.
    // This is the only fully race-condition-proof way to block the wake-tap.
    if (_hintActive || _wasIdleOnPointerDown) return;
    _setPausedState(!_isPaused);
  }

  // ── DOUBLE TAP: simultaneous squish + Hero expand ─────────
  Future<void> _handleDoubleTap(Map<String, String> song) async {
    if (_hintActive || _isExpanding || _wasIdleOnPointerDown) return;
    if (_isPaused) _setPausedState(false);

    // Force front face before Hero flies — back face Hero looks broken
    final songId = song['title'] ?? '';
    if (_flippedCards.contains(songId)) {
      setState(() => _flippedCards.remove(songId));
      // Small delay to let the flip settle before Hero starts
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
    }

    setState(() => _isExpanding = true);

    // Both start on the same frame — squish and Hero grow together
    _expandController.forward(from: 0.0);

    // Use root navigator so expanded view covers navbar completely
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,  // opaque so nothing below bleeds through
        transitionDuration: const Duration(milliseconds: 680),
        reverseTransitionDuration: const Duration(milliseconds: 560),
        pageBuilder: (ctx, anim, _) => _ExpandedSongView(song: song),
        transitionsBuilder: (ctx, anim, _, child) {
          final bgFade = CurvedAnimation(
            parent: anim,
            curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
            reverseCurve: const Interval(0.3, 1.0, curve: Curves.easeIn),
          );
          return FadeTransition(opacity: bgFade, child: child);
        },
      ),
    ).then((_) {
      if (!mounted) return;
      // Reverse squish as card closes
      _expandController.reverse().then((_) {
        if (!mounted) return;
        setState(() => _isExpanding = false);
        _expandController.reset();
      });
    });
  }

  // ── CARD CONTENT ─────────────────────────────────────────

  // ── Bottom info: title + artist (shared by both faces) ────
  Widget _buildCardBottomInfo(Map<String, String> song) {
    final opacityProg = 1.0 - (_idleScaleController.value / 0.05).clamp(0.0, 1.0);
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Opacity(
        opacity: opacityProg,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                song['title'] ?? '',
                style: const TextStyle(
                  fontFamily: 'Circular',
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                song['artist'] ?? '',
                style: TextStyle(
                  fontFamily: 'Circular',
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Flip toggle button ─────────────────────────────────────
  Widget _buildFlipButton({required bool isFlipped, required VoidCallback onTap}) {
    final opacityProg = 1.0 - (_idleScaleController.value / 0.05).clamp(0.0, 1.0);
    return Opacity(
      opacity: opacityProg,
      child: GestureDetector(
        onTap: onTap,
        // Absorb so the tap doesn't bubble to the card's GestureDetector
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _pink.withOpacity(0.18),
            border: Border.all(color: _pink.withOpacity(0.4), width: 1),
          ),
          child: Icon(
            isFlipped ? Icons.image_rounded : Icons.music_video_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }

  // ── FRONT FACE ─────────────────────────────────────────────
  Widget _buildFrontFace(Map<String, String> song, bool isDraggable, bool isFlipped, double centerAdjustment) {
    final genre  = song['genre'] ?? '';
    final songId = song['title'] ?? '';

    return AnimatedBuilder(
      animation: _idleScaleController,
      builder: (context, child) {
        final rawVal = _idleScaleController.value;
        final isReversing = _idleScaleController.status == AnimationStatus.reverse;
        
        // Forward: Fade out fast in 1.5s (0.05). Reverse: Fade in smoothly over 400ms (1.0).
        final fadeThreshold = isReversing ? 1.0 : 0.05;
        final opacityProg = 1.0 - (rawVal / fadeThreshold).clamp(0.0, 1.0);
        
        // Scaling starts AFTER the 1.5s fade completes (at 0.05)
        final scaleVal  = isDraggable ? rawVal : 0.0;
        final baseProg  = ((scaleVal - 0.05) / 0.95).clamp(0.0, 1.0);
        // Apply the easeOutQuad curve to the scaling progress only
        final scaleProg = Curves.easeOutQuad.transform(baseProg);

        final screenW = MediaQuery.sizeOf(context).width;
        final screenH = MediaQuery.sizeOf(context).height;
        
        // Target significantly larger than screen bounds (15%) to perfectly bleed
        // over screen edges and cover any unexpected navigational paddings/insets.
        final targetW = screenW * 1.15;
        final targetH = screenH * 1.15;

        final currentW = _dynCardW + scaleProg * (targetW - _dynCardW);
        final currentH = _dynCardH + scaleProg * (targetH - _dynCardH);

        return Transform.translate(
          offset: Offset(0, centerAdjustment * scaleProg),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: currentW, height: currentH,
              child: Stack(
              children: [
                // Cover art
                Positioned.fill(
                  child: Image.network(
                    song['image'] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1a0a2e), Color(0xFF2d1b4e), Color(0xFF0d1b2e)],
                        ),
                      ),
                    ),
                  ),
                ),

                // Gradient overlay
                Positioned.fill(
                  child: Opacity(
                    opacity: opacityProg,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.4),
                            Colors.black.withOpacity(0.92),
                          ],
                          stops: const [0.35, 0.65, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

              // Genre chip — top right
              if (genre.isNotEmpty)
                Positioned(
                  top: 14, right: 14,
                  child: Opacity(
                    opacity: opacityProg,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      child: Text(
                        genre.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Circular',
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Swipe direction feedback overlay ──────────────────
              if (isDraggable)
                Positioned.fill(
                  child: ValueListenableBuilder<Offset>(
                    valueListenable: _cardOffsetNotifier,
                    builder: (_, dragOffset, __) {
                      return _SwipeOverlay(
                        offset: dragOffset,
                        canLike: widget.canLike,
                        commitThreshold: _commitThreshold,
                      );
                    },
                  ),
                ),

              // Flip button — top left (music_video_rounded on front)
              Positioned(
                top: 14, left: 14,
                child: _buildFlipButton(
                  isFlipped: false,
                  onTap: () => setState(() => _flippedCards.add(songId)),
                ),
              ),

              // Pause overlay (only on draggable top card)
              if (isDraggable)
                Positioned.fill(
                  child: _AnimatedPauseOverlay(isPaused: _isPaused),
                ),

              // Bottom info
              _buildCardBottomInfo(song),
            ],
          ),
        ),
      ),
        );
      },
    );
  }

  // ── BACK FACE ──────────────────────────────────────────────
  Widget _buildBackFace(Map<String, String> song, bool isDraggable, double centerAdjustment) {
    final songId = song['title'] ?? '';

    // Everything inside the back face must be counter-rotated by π
    // on the Y axis so text and icons render correctly (not mirrored).
    // We counter-rotate the ENTIRE content stack as one unit — individual
    // element counter-rotation causes layout issues with Positioned widgets.
    return AnimatedBuilder(
      animation: _idleScaleController,
      builder: (context, child) {
        final rawVal = _idleScaleController.value;
        final isReversing = _idleScaleController.status == AnimationStatus.reverse;
        
        // Forward: Fade out fast in 1.5s (0.05). Reverse: Fade in smoothly over 400ms (1.0).
        final fadeThreshold = isReversing ? 1.0 : 0.05;
        final opacityProg = 1.0 - (rawVal / fadeThreshold).clamp(0.0, 1.0);
        
        final scaleVal  = isDraggable ? rawVal : 0.0;
        final baseProg  = ((scaleVal - 0.05) / 0.95).clamp(0.0, 1.0);
        final scaleProg = Curves.easeOutQuad.transform(baseProg);

        final screenW = MediaQuery.sizeOf(context).width;
        final screenH = MediaQuery.sizeOf(context).height;
        
        // Target significantly larger than screen bounds (15%) to perfectly bleed
        // over screen edges and cover any unexpected navigational paddings/insets.
        final targetW = screenW * 1.15;
        final targetH = screenH * 1.15;

        final currentW = _dynCardW + scaleProg * (targetW - _dynCardW);
        final currentH = _dynCardH + scaleProg * (targetH - _dynCardH);

        return Transform.translate(
          offset: Offset(0, centerAdjustment * scaleProg),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: currentW, height: currentH,
              child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: Stack(
                children: [
                  // Dark visualizer background
                  Positioned.fill(
                    child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0A0214), Color(0xFF180A38), Color(0xFF2A114A)],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),

                // Subtle grid lines
                Positioned.fill(
                  child: CustomPaint(painter: _GridPainter()),
                ),

                // Centre visualizer content
                Positioned.fill(
                  child: Center(
                    child: Opacity(
                      opacity: opacityProg,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _pink.withOpacity(0.12),
                              border: Border.all(color: _pink.withOpacity(0.35), width: 1),
                            ),
                            child: const Icon(
                              Icons.graphic_eq_rounded,
                              color: _pink,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'LIVE VISUALIZER',
                            style: TextStyle(
                              fontFamily: 'Circular',
                              color: _pink.withOpacity(0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'coming soon',
                            style: TextStyle(
                              fontFamily: 'Circular',
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Flip button — top left (same position as front face)
                Positioned(
                  top: 14, left: 14,
                  child: _buildFlipButton(
                    isFlipped: true,
                    onTap: () => setState(() => _flippedCards.remove(songId)),
                  ),
                ),

                // Pause overlay
                if (isDraggable)
                  Positioned.fill(
                    child: _AnimatedPauseOverlay(isPaused: _isPaused),
                  ),

                // Bottom info — same position as front face
                _buildCardBottomInfo(song),
              ],
            ),
          ),
        ),
      ),
        );
      },
    );
  }

  // ── BUILD CARD ─────────────────────────────────────────────
  Widget _buildCard(
    Map<String, String> song,
    double horizontalOffset,
    double scale,
    double rotation, {
    required bool isDraggable,
    required bool isBlurred,
    double commitThreshold = 180,
    double centerAdjustment = 0.0,
  }) {
    final songId    = song['title'] ?? '';
    final isFlipped = _flippedCards.contains(songId);

    // target: 0 = front, π = back.
    final targetAngle = isFlipped ? math.pi : 0.0;

    // Faces are separate widgets passed into the flip wrapper.
    final frontFace = _buildFrontFace(song, isDraggable, isFlipped, centerAdjustment);
    final backFace  = _buildBackFace(song, isDraggable, centerAdjustment);

    // Hero wraps the front face so double-tap expand always flies
    // from the art side. Shadow lives outside via PhysicalModel.
    final heroFront = Hero(
      tag: 'song_card_${song['title']}_${song['artist']}',
      createRectTween: (Rect? begin, Rect? end) =>
          MaterialRectCenterArcTween(begin: begin, end: end),
      flightShuttleBuilder: (_, heroAnim, direction, fromCtx, toCtx) {
        return AnimatedBuilder(
          animation: Listenable.merge([heroAnim, _expandController]),
          builder: (_, __) {
            final radiusCurve = CurvedAnimation(
                parent: heroAnim, curve: Curves.easeInOutCubic);
            final r = direction == HeroFlightDirection.push
                ? Tween(begin: 24.0, end: 0.0).evaluate(radiusCurve)
                : Tween(begin: 0.0, end: 24.0).evaluate(radiusCurve);
            return Transform.translate(
              offset: Offset(0, _bobY.value),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(_tiltX.value)
                  ..scale(_squishX.value, _squishY.value),
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(r.clamp(0.0, 24.0)),
                    child: direction == HeroFlightDirection.push
                        ? toCtx.widget
                        : fromCtx.widget,
                  ),
                ),
              ),
            );
          },
        );
      },
      child: frontFace,
    );

    // The full card content — flip wrapper with front + back.
    // Key on songId so a fresh TweenAnimationBuilder is created for each
    // card, preventing stale tween state from the previous card carrying over.
    // begin: null means "animate from wherever the current value is" — this
    // is what drives the flip animation when targetAngle changes.
    // TweenAnimationBuilder for flip — ClipRRect must be INSIDE the Transform
    // so clipping happens in the rotated coordinate space, not before.
    // This prevents the card being cut off during the 3D rotation.
    Widget cardContent = TweenAnimationBuilder<double>(
      key: ValueKey('flip_$songId'),
      tween: Tween<double>(begin: null, end: targetAngle),
      duration: const Duration(milliseconds: 700),
      curve: const Cubic(0.4, 0.0, 0.2, 1.4),
      builder: (_, angle, __) {
        final showFront = angle < math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: showFront ? heroFront : backFace,
        );
      },
    );

    // Static BoxDecoration shadow — computed once, never per-frame
    // Removed RepaintBoundary because animating physical bounds forces continuous
    // reallocation of the offscreen native texture bitmap at 60fps, causing catastrophic
    // freezing and flickering on mobile hardware. Flutter core renders layers natively much faster.
    // removed the internal AnimatedOpacity for background cards because it was being
    // destroyed by the RepaintBoundary key change in _buildAnimatedBackCard.
    // Fade for background cards is now handled at the stack assembly level.
    Widget cardBody = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.38),
            blurRadius: 28,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: cardContent,
    );

    if (isBlurred) {
      // Blur removed for massive 90fps performance gain on Drag
      cardBody = Opacity(opacity: 0.45, child: cardBody);
    }

    if (!isDraggable) {
      // Return just cardBody — _buildStack wraps in a lightweight Transform
      // so the card content is never rebuilt during rotation animation.
      return cardBody;
    }

    return GestureDetector(
      onTap: _handleTap,
      onDoubleTap: () { _handleDoubleTap(song); },
      onPanStart: (_hintActive || _isExpanding)
          ? null
          : (_) {
              // Cancel any in-progress snap-back so it doesn't fight the drag
              if (_snapController.isAnimating) {
                _snapController.stop();
                _snapController.clearListeners();
              }
            },
      onPanUpdate: (_hintActive || _isExpanding)
          ? null
          : (details) {
              // Direct ValueNotifier write — no setState, no full rebuild
              _cardOffsetNotifier.value =
                  _cardOffsetNotifier.value + details.delta;
              final dy = _cardOffsetNotifier.value.dy;
              final isLiking    = dy > commitThreshold * 0.6 && widget.canLike;
              final isDisliking = dy < -(commitThreshold * 0.6);
              // Only fire when state changes — prevents setState on every pixel
              if (isLiking != _wasLiking || isDisliking != _wasDisliking) {
                _wasLiking    = isLiking;
                _wasDisliking = isDisliking;
                widget.onSwipeThreshold?.call(isLiking, isDisliking);
              }
            },
      onPanEnd: (_hintActive || _isExpanding)
          ? null
          : (_) {
              final dy = _cardOffsetNotifier.value.dy;
              _wasLiking = false; _wasDisliking = false;
              widget.onSwipeThreshold?.call(false, false);
              // Commit if card crossed overlay threshold (60%) on release —
              // user saw the feedback and let go, so they intend to swipe.
              if (dy > commitThreshold * 0.6 && widget.canLike) {
                triggerLike();
              } else if (dy < -(commitThreshold * 0.6)) {
                triggerDislike();
              } else {
                _snapController.stop();
                _snapController.reset();
                _snapController.clearListeners();
                Offset pos  = _cardOffsetNotifier.value;
                Offset vel  = Offset.zero;
                // Minimal spring: snaps back cleanly with just a whisper of overshoot
                const double k    = 0.20;
                const double damp = 0.68;
                _snapController.addListener(() {
                  vel = vel + Offset(-k * pos.dx, -k * pos.dy);
                  vel = vel * damp;
                  pos = pos + vel;
                  _cardOffsetNotifier.value = pos;
                  if (pos.distance < 0.5 && vel.distance < 0.5) {
                    _cardOffsetNotifier.value = Offset.zero;
                    _snapController.stop();
                    _snapController.clearListeners();
                  }
                });
                _snapController.repeat();
              }
            },
      child: ValueListenableBuilder<Offset>(
        valueListenable: _cardOffsetNotifier,
        builder: (_, dragOffset, child) {
          final dx = dragOffset.dx;
          final rotZ = (dx / 200.0).clamp(-1.0, 1.0) * 0.38;
          final rotY = (dx / 300.0).clamp(-1.0, 1.0) * 0.10;
          return AnimatedBuilder(
            animation: Listenable.merge([_expandController, _idleScaleController, _gimbalController]),
            child: child,
            builder: (_, inner) {
              // Single Matrix4 combines drag tilt + expand squish + gimbal
              
              double gimbalRotX = 0.0;
              double gimbalRotY = 0.0;
              double dyScaleOffset = 0.0;
              if (widget.isIdle && isDraggable) {
                // Kick in the 3D tilt instantly at 100% capacity right when scaling
                // begins, then fade it out so it lands completely flat physically edge-to-edge.
                final rawVal = _idleScaleController.value;
                final scaleProg = ((rawVal - 0.05) / 0.95).clamp(0.0, 1.0);
                
                double gimbalRamp = 0.0;
                if (scaleProg > 0.0) {
                  gimbalRamp = 1.0 - scaleProg; // Immediate sharp onset
                }
                
                final t = _gimbalController.value * 2 * math.pi;
                gimbalRotX = math.sin(t * 2) * 0.22 * gimbalRamp; 
                gimbalRotY = math.cos(t) * 0.35 * gimbalRamp; 
                
                // Extremely gentle -1% push up to exactly reconcile physical bezels
                dyScaleOffset = -scaleProg * MediaQuery.sizeOf(context).height * 0.01;
              }

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateZ(rotZ)
                  ..rotateY(rotY + gimbalRotY)
                  ..rotateX(_tiltX.value + gimbalRotX)
                  ..scale(_squishX.value, _squishY.value),
                child: Transform.translate(
                  offset: dragOffset + Offset(0, _bobY.value + dyScaleOffset),
                  child: inner,
                ),
              );
            },
          );
        },
        child: cardBody,
      ),
    );
  }

  // ── HINT ARROWS ───────────────────────────────────────────
  Widget _buildLikeArrow(double cardDy) {
    return FadeTransition(
      opacity: _likeHintOpacity,
      child: Transform.translate(
        offset: Offset(0, cardDy + (_dynCardH / 2) + 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DashedLine(color: _pink.withOpacity(0.5), height: 18),
            const SizedBox(height: 4),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pink.withOpacity(0.12),
                border: Border.all(
                    color: _pink.withOpacity(0.65), width: 1.5),
              ),
              child: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: _pink, size: 20),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('LIKE',
                style: TextStyle(
                  fontFamily: 'Circular',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _pink,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassArrow(double cardDy) {
    return FadeTransition(
      opacity: _passHintOpacity,
      child: Transform.translate(
        offset: Offset(0, cardDy - (_dynCardH / 2) - 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('PASS',
                style: TextStyle(
                  fontFamily: 'Circular',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _purple,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _purple.withOpacity(0.12),
                border: Border.all(
                    color: _purple.withOpacity(0.65), width: 1.5),
              ),
              child: const Icon(Icons.keyboard_arrow_up_rounded,
                  color: _purple, size: 20),
            ),
            const SizedBox(height: 4),
            _DashedLine(color: _purple.withOpacity(0.5), height: 18),
          ],
        ),
      ),
    );
  }

  // ── Spring curve — overshoots ~8% then settles ───────────────
  // Cubic(0.34, 1.26, 0.64, 1.0) gives a natural spring feel without
  // the excessive bounce of ElasticOut.
  static const _springCurve = Cubic(0.34, 1.26, 0.64, 1.0);

  // ── Stagger delays per card slot ────────────────────────────
  // i=1 (next card) moves immediately, further cards follow with delay.
  // Delay is a fraction of the total animation [0.0–0.25].
  static double _staggerDelay(int i) {
    switch (i) {
      case  1: return 0.0;   // next card: leads the movement
      case -1: return 0.08;  // previous card: slight lag
      case  2: return 0.14;  // two ahead: follows next
      case -2: return 0.20;  // two behind: last to move
      default: return 0.0;
    }
  }

  // ── BUILD STACK ───────────────────────────────────────────
  // Each card has its own AnimatedBuilder → only transforms rebuild.
  // Spring curve + stagger = B+C combined from the mockups.
  Widget _buildAnimatedBackCard(int i, double centerAdjustment) {
    final song = _getLoopedSong(displayIndex + i);
    // Build the heavy card content once to be passed as 'child' to the builder.
    // This child is never re-inflated during the animation frames.
    final cardContent = _buildCard(song, 0, 1.0, 0,
        isDraggable: false, isBlurred: true,
        centerAdjustment: centerAdjustment);

    return AnimatedBuilder(
      animation: Listenable.merge([_rotationAnimation, _idleScaleController]),
      child: cardContent,
      builder: (context, child) {
        // Calculate dynamic opacity on EVERY frame as idleScaleController moves
        final idleProg = _idleScaleController.value;
        final opacity = (1.0 - (idleProg / 0.05)).clamp(0.0, 1.0);

        // RepaintBoundary sits inside the builder so we can refresh the cache key
        // whenever widget.isIdle changes (to fix sharp corners).
        final wrappedChild = RepaintBoundary(
          key: ValueKey('back_${displayIndex + i}_${widget.isIdle}'),
          child: child,
        );

        // Apply background card fade-out/fade-in
        final fadedChild = Opacity(opacity: opacity, child: wrappedChild);

        final double raw = isExiting ? 0.0 : _rotationAnimation.value;
        // Remap raw progress through stagger delay, then apply spring curve
        final double delay = _staggerDelay(i);
        final double shifted = ((raw - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        final double progress = _springCurve.transform(shifted);

        final double effective = i.toDouble() - progress;
        if (effective.abs() > 2.6) return const SizedBox.shrink();
        final s = (1.0 - (effective.abs() * 0.11)).clamp(0.0, 1.0);
        final h = effective * 80.0;
        final r = effective * 0.07;

        return Transform.translate(
          offset: Offset(h, 0),
          child: Transform.rotate(
            angle: r,
            child: Transform.scale(scale: s, child: fadedChild),
          ),
        );
      },
    );
  }

  List<Widget> _buildStack(double centerAdjustment) {
    Widget wrapOverflow(Widget child) => OverflowBox(
      minWidth: 0, minHeight: 0,
      maxWidth: double.infinity, maxHeight: double.infinity,
      child: child,
    );

    return [
      wrapOverflow(_buildAnimatedBackCard(-2, centerAdjustment)),
      wrapOverflow(_buildAnimatedBackCard(-1, centerAdjustment)),
      wrapOverflow(_buildAnimatedBackCard(2, centerAdjustment)),
      wrapOverflow(_buildAnimatedBackCard(1, centerAdjustment)),
      // Top card — only show when not mid-transition
      if (!(isAnimating && !isExiting))
        wrapOverflow(_buildCard(_getLoopedSong(displayIndex), 0, 1.0, 0,
            isDraggable: true, isBlurred: false,
            commitThreshold: _commitThreshold,
            centerAdjustment: centerAdjustment)),
    ];
  }

  // Screen-based dimensions — updated each build from MediaQuery
  double _commitThreshold = 200;
  double _dynCardW = 220;
  double _dynCardH = 300;

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final double stackH = _dynCardH + 120;
    // Commit when card has travelled ~38% of half screen height
    // This places the threshold near the screen edge
    _commitThreshold = MediaQuery.of(context).size.height * 0.38;
    // Card: 58% of screen width, aspect ratio 0.72 (portrait playing card feel)
    // Calculate centering offset once per build from a STABLE coordinate reference
    double centerAdjustment = 0.0;
    try {
      final rb = context.findRenderObject() as RenderBox?;
      if (rb != null && rb.attached) {
        final globalY = rb.localToGlobal(Offset.zero).dy;
        // Bias the center slightly downwards (+20) to ensure the bottom edge
        // definitively clears any system navigational artifacts.
        centerAdjustment = (MediaQuery.sizeOf(context).height / 2) - (globalY + stackH / 2) + 20.0;
      }
    } catch (_) {}

    // _buildStack() is passed as child — stable across bob frames.
    // Only hint arrows need to rebuild with cardDy.
    final stackWidget = SizedBox(
      height: stackH,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: _buildStack(centerAdjustment),
      ),
    );

    return AnimatedBuilder(
      animation: _bobController,
      child: stackWidget,
      builder: (_, child) {
        final cardDy = _bobController.isAnimating
            ? _bobValue.value * _bobAmplitude
            : 0.0;

        return SizedBox(
          height: stackH,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: stackH,
                width: double.infinity,
                child: child!,
              ),
              if (!_hintDismissed) ...[
                FadeTransition(
                  opacity: _hintFade,
                  child: _buildLikeArrow(cardDy),
                ),
                FadeTransition(
                  opacity: _hintFade,
                  child: _buildPassArrow(cardDy),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Fullscreen expanded song view
// ─────────────────────────────────────────────────────────────
class _ExpandedSongView extends StatefulWidget {
  final Map<String, String> song;
  const _ExpandedSongView({required this.song});

  @override
  State<_ExpandedSongView> createState() => _ExpandedSongViewState();
}

class _ExpandedSongViewState extends State<_ExpandedSongView>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final song   = widget.song;
    final title  = song['title']  ?? '';
    final artist = song['artist'] ?? '';
    final genre  = song['genre']  ?? '';
    final mood   = song['mood']   ?? '';
    final bpm    = song['bpm']    ?? '';
    final key    = song['key']    ?? '';
    final image  = song['image']  ?? '';

    final sh = MediaQuery.of(context).size.height;
    final sw = MediaQuery.of(context).size.width;

    return GestureDetector(
      onDoubleTap: _close,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Dark background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.3),
                    radius: 1.2,
                    colors: [Color(0xFF2d1b4e), Color(0xFF0d0d1a)],
                  ),
                ),
              ),
            ),

            // Blurred cover art — RepaintBoundary caches raster, never recomputed
            if (image.isNotEmpty)
              Positioned.fill(
                child: RepaintBoundary(
                  child: Opacity(
                    opacity: 0.18,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                      child: Image.network(image, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),

            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: (sw * 0.07).clamp(20.0, 36.0),
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'NOW PLAYING',
                          style: TextStyle(
                            fontFamily: 'Circular',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                        GestureDetector(
                          onTap: _close,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'CLOSE',
                              style: TextStyle(
                                fontFamily: 'Circular',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Cover art — PhysicalModel shadow outside Hero
                    Center(
                      child: PhysicalModel(
                        color: Colors.transparent,
                        elevation: 24,
                        shadowColor: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                        child: SizedBox(
                          width: sw * 0.86,
                          height: sw * 0.86, // square, fills width
                          child: Hero(
                            tag: 'song_card_${title}_${artist}',
                            createRectTween: (Rect? begin, Rect? end) =>
                                MaterialRectCenterArcTween(
                                    begin: begin, end: end),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: image.isNotEmpty
                                  ? Image.network(image, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _CoverPlaceholder())
                                  : _CoverPlaceholder(),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Title + artist + waveform
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontFamily: 'Circular',
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                  height: 1.1,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                artist,
                                style: TextStyle(
                                  fontFamily: 'Circular',
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: AnimatedBuilder(
                            animation: _waveController,
                            builder: (_, __) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: List.generate(5, (i) {
                                  final phase =
                                      (i * 0.22 + _waveController.value) % 1.0;
                                  final h = 5.0 +
                                      16.0 *
                                          math.sin(phase * math.pi).abs();
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 1.5),
                                    child: Container(
                                      width: 4,
                                      height: h,
                                      decoration: BoxDecoration(
                                        color: _pink,
                                        borderRadius:
                                            BorderRadius.circular(2),
                                      ),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Metadata pills
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        if (mood.isNotEmpty)
                          _ExpandedPill(label: mood, color: _pink),
                        if (bpm.isNotEmpty && bpm != '0')
                          _ExpandedPill(label: '$bpm BPM', color: _blue),
                        if (key.isNotEmpty)
                          _ExpandedPill(label: key, color: _purple),
                        if (genre.isNotEmpty)
                          _ExpandedPill(
                              label: genre,
                              color: Colors.white.withOpacity(0.6)),
                      ],
                    ),

                    const Expanded(child: SizedBox()),

                    // Progress bar
                    Stack(
                      children: [
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: 0.0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [_pink, _purple]),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('—:——',
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.3),
                            )),
                        Text('—:——',
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.3),
                            )),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Playback controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Opacity(
                          opacity: 0.35,
                          child: Icon(Icons.skip_previous_rounded,
                              color: Colors.white, size: 32),
                        ),
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: _pink.withOpacity(0.4),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.pause_rounded,
                              color: Color(0xFF1a0a2e), size: 30),
                        ),
                        Opacity(
                          opacity: 0.35,
                          child: Icon(Icons.skip_next_rounded,
                              color: Colors.white, size: 32),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Center(
                      child: Text(
                        'PLAYBACK COMING SOON',
                        style: TextStyle(
                          fontFamily: 'Circular',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
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

// ─────────────────────────────────────────────────────────────
class _CoverPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1a0a2e), Color(0xFF2d1b4e), Color(0xFF0d1b2e)],
        ),
      ),
      child: Center(
        child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.06),
            border: Border.all(
                color: Colors.white.withOpacity(0.12), width: 1),
          ),
          child: Center(
            child: Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pink.withOpacity(0.2),
                border: Border.all(color: _pink.withOpacity(0.4), width: 1),
              ),
              child: const Icon(Icons.music_note_rounded,
                  color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _ExpandedPill extends StatelessWidget {
  final String label;
  final Color  color;
  const _ExpandedPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Circular',
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _MetaPill extends StatelessWidget {
  final String label;
  final Color  color;
  const _MetaPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Circular',
          color: color.withOpacity(0.95),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _DashedLine extends StatelessWidget {
  final Color  color;
  final double height;
  const _DashedLine({required this.color, required this.height});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(2, height), painter: _DashedPainter(color: color));
}

class _DashedPainter extends CustomPainter {
  final Color color;
  const _DashedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color       = color
      ..strokeWidth = 2
      ..strokeCap   = StrokeCap.round;
    const dash = 4.0;
    const gap  = 4.0;
    double y   = 0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, (y + dash).clamp(0, size.height)),
        p,
      );
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────
// Swipe direction feedback overlay
// Shown while dragging — green/heart for like, red/X for pass.
// Opacity scales with drag distance so it feels proportional.
// ─────────────────────────────────────────────────────────────
class _SwipeOverlay extends StatelessWidget {
  final Offset offset;
  final bool   canLike;
  final double commitThreshold;

  const _SwipeOverlay({
    required this.offset,
    required this.canLike,
    this.commitThreshold = 200,
  });

  @override
  Widget build(BuildContext context) {
    final dy = offset.dy;
    // Overlay starts showing at 60% of commit threshold (near screen edge)
    // and reaches full opacity at 100% (commit point)
    final startThreshold = commitThreshold * 0.6;
    final raw = (dy.abs() - startThreshold) / (commitThreshold * 0.4);
    final progress = raw.clamp(0.0, 1.0);
    if (progress < 0.01) return const SizedBox.shrink();

    final isLike = dy > 0;
    // Like = green, Pass = red. Dim like if no likes left.
    final color = isLike
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
    final icon  = isLike
        ? Icons.favorite_rounded
        : Icons.close_rounded;
    final label = isLike ? 'LIKE' : 'PASS';
    final alpha = (progress * (isLike && !canLike ? 0.4 : 0.72)).clamp(0.0, 0.72);

    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: color.withOpacity(alpha * 0.45),
        ),
        child: Center(
          child: Opacity(
            opacity: progress,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.2),
                    border: Border.all(
                      color: color.withOpacity(0.8),
                      width: 2.5,
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: color.withOpacity(0.6), width: 1),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Circular',
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Subtle grid lines for the back face visualizer background
// ─────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = const Color(0xFFFF6FE8).withOpacity(0.045)
      ..strokeWidth = 0.5;

    const step = 28.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

// ─────────────────────────────────────────────────────────────
// Premium animated pause overlay — breathes while paused
// ─────────────────────────────────────────────────────────────
class _AnimatedPauseOverlay extends StatefulWidget {
  final bool isPaused;
  const _AnimatedPauseOverlay({required this.isPaused});

  @override
  State<_AnimatedPauseOverlay> createState() => _AnimatedPauseOverlayState();
}

class _AnimatedPauseOverlayState extends State<_AnimatedPauseOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _breatheController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isPaused) _breatheController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _AnimatedPauseOverlay old) {
    super.didUpdateWidget(old);
    if (widget.isPaused && !old.isPaused) {
      _breatheController.repeat(reverse: true);
    } else if (!widget.isPaused && old.isPaused) {
      _breatheController.animateTo(0,
          duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: widget.isPaused ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          if (value == 0.0) return const SizedBox.shrink();
          return Stack(
            fit: StackFit.expand,
            children: [
              // Blurred violet tint (blur removed for performance)
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF2d1b4e).withOpacity(0.65 * value),
                      Colors.black.withOpacity(0.85 * value),
                    ],
                    radius: 1.2,
                  ),
                ),
              ),
              // Breathing play button
              Center(
                child: Transform.scale(
                  scale: widget.isPaused
                      ? Curves.elasticOut.transform(value)
                      : Curves.easeOut.transform(value),
                  child: AnimatedBuilder(
                    animation: _breatheController,
                    builder: (context, child) {
                      final b = _breatheController.value;
                      return Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white
                              .withOpacity(0.15 + 0.05 * b),
                          border: Border.all(
                            color: Colors.white
                                .withOpacity(0.4 + 0.3 * b),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6FE8)
                                  .withOpacity(0.3 * b * value),
                              blurRadius: 15 + 20 * b,
                              spreadRadius: 2 * b,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white.withOpacity(value),
                          size: 28,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}