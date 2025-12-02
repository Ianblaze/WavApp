import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class CardStack extends StatefulWidget {
  final List<Map<String, String>> songs;
  final Future<void> Function(Map<String, String>)? onLike;
  final Future<void> Function(Map<String, String>)? onDislike;
  final bool canLike;
  final Function(bool isLiking, bool isDisliking)? onSwipeThreshold; // NEW callback

  const CardStack({
    super.key,
    required this.songs,
    this.onLike,
    this.onDislike,
    this.canLike = true,
    this.onSwipeThreshold,
  });

  @override
  State<CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<CardStack> with TickerProviderStateMixin {
  int displayIndex = 0;
  Offset cardOffset = Offset.zero;
  bool isDragging = false;
  bool isAnimating = false;
  bool isExiting = false;

  late final AnimationController _rotationController;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 360),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  // PUBLIC BUTTON TRIGGERS ---------------------------
  void triggerLike() {
    // Only trigger if likes are available
    if (!isAnimating && widget.canLike) {
      _handleLikeAnimation(false);
    }
  }

  void triggerDislike() {
    if (!isAnimating) _handleDislikeAnimation(false);
  }

  // Called by parent BEFORE animation to trigger counter decrement
  void onSwipeStart() {
    // This allows parent to decrement counter immediately
  }

  // SONG LOOPING
  Map<String, String> _getLoopedSong(int index) {
    if (widget.songs.isEmpty) {
      return {'title': '', 'artist': '', 'genre': '', 'mood': '', 'image': ''};
    }
    int looped = index % widget.songs.length;
    if (looped < 0) looped += widget.songs.length;
    return widget.songs[looped];
  }

  // ----------------- LIKE ANIMATION -----------------
  Future<void> _handleLikeAnimation(bool fromSwipe) async {
    if (isAnimating || !widget.canLike) return; // Block if no likes available

    setState(() {
      isAnimating = true;
      isExiting = true;
    });

    final int steps = 30;
    final double startY = cardOffset.dy;
    final double endY = 700;
    final double step = (endY - startY) / steps;

    for (int i = 0; i < steps; i++) {
      await Future.delayed(const Duration(milliseconds: 12));
      if (!mounted) return;
      setState(() {
        cardOffset = Offset(0, startY + step * (i + 1));
      });
    }

    setState(() => isExiting = false);
    await _rotationController.forward();

    if (!mounted) return;
    final prevSong = _getLoopedSong(displayIndex);

    setState(() {
      displayIndex = (displayIndex + 1) % widget.songs.length;
      cardOffset = Offset.zero;
      isAnimating = false;
    });
    _rotationController.reset();

    if (widget.onLike != null) await widget.onLike!(prevSong);
  }

  // ----------------- DISLIKE ANIMATION -----------------
  Future<void> _handleDislikeAnimation(bool fromSwipe) async {
    if (isAnimating) return;

    setState(() {
      isAnimating = true;
      isExiting = true;
    });

    final int steps = 30;
    final double startY = cardOffset.dy;
    final double endY = -700;
    final double step = (endY - startY) / steps;

    for (int i = 0; i < steps; i++) {
      await Future.delayed(const Duration(milliseconds: 12));
      if (!mounted) return;
      setState(() {
        cardOffset = Offset(0, startY + step * (i + 1));
      });
    }

    setState(() => isExiting = false);
    await _rotationController.forward();

    if (!mounted) return;
    final prevSong = _getLoopedSong(displayIndex);

    setState(() {
      displayIndex = (displayIndex + 1) % widget.songs.length;
      cardOffset = Offset.zero;
      isAnimating = false;
    });
    _rotationController.reset();

    if (widget.onDislike != null) await widget.onDislike!(prevSong);
  }

  // ----------------- BUILD CARD -----------------
  Widget _buildCard(
    Map<String, String> song,
    double horizontalOffset,
    double scale,
    double rotation, {
    required bool isDraggable,
    required bool isBlurred,
  }) {
    Widget content = Container(
      width: 260,
      height: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            spreadRadius: 4,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                song['image'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFF282828)),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song['title'] ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(song['artist'] ?? '',
                        style: const TextStyle(
                            color: Color(0xFFB3B3B3), fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('${song['genre']} • ${song['mood']}',
                        style: const TextStyle(
                            color: Color(0xFF888888), fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (isBlurred) {
      content = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Opacity(opacity: 0.6, child: content),
      );
    }

    if (!isDraggable) {
      return Transform.translate(
        offset: Offset(horizontalOffset, 0),
        child: Transform.rotate(
          angle: rotation,
          child: Transform.scale(scale: scale, child: content),
        ),
      );
    }

    return GestureDetector(
      onPanStart: (_) {
        setState(() => isDragging = true);
      },
      onPanUpdate: (details) {
        setState(() => cardOffset += details.delta);
        
        // Notify parent about threshold crossing
        if (widget.onSwipeThreshold != null) {
          final bool crossedLikeThreshold = cardOffset.dy > 100 && widget.canLike;
          final bool crossedDislikeThreshold = cardOffset.dy < -100;
          widget.onSwipeThreshold!(crossedLikeThreshold, crossedDislikeThreshold);
        }
      },
      onPanEnd: (_) {
        setState(() => isDragging = false);
        
        // Reset button states when swipe ends
        if (widget.onSwipeThreshold != null) {
          widget.onSwipeThreshold!(false, false);
        }
        
        // Like = swipe down (positive dy), Dislike = swipe up (negative dy)
        if (cardOffset.dy > 150 && widget.canLike) {
          triggerLike();
        } else if (cardOffset.dy < -150) {
          triggerDislike();
        } else {
          setState(() => cardOffset = Offset.zero);
        }
      },
      child: Transform.translate(
        offset: cardOffset,
        child: content,
      ),
    );
  }

  // ----------------- STACK -----------------
  List<Widget> _buildStack() {
    List<Widget> stack = [];

    double progress = isExiting ? 0 : _rotationAnimation.value;

    // Build background cards first (left side, then right side)
    // Then center card last so it's always on top
    List<int> order = [-2, -1, 2, 1, 0]; // Back to front rendering order

    for (int i in order) {
      if (i == 0 && isAnimating && !isExiting) continue;

      double effective = i - progress;
      if (effective.abs() > 2.5) continue;

      final song = _getLoopedSong(displayIndex + i);

      double horizontal = effective * 100;
      double scale = 0.92 - (effective.abs() * 0.08);
      double rotation = effective * 0.07;
      bool blurred = effective.abs() > 0.1;

      if (i == 0) {
        // Center card (draggable, rendered last = always on top)
        stack.add(_buildCard(
          song,
          0,
          1.0,
          0,
          isDraggable: true,
          isBlurred: false,
        ));
      } else {
        stack.add(_buildCard(
          song,
          horizontal,
          scale,
          rotation,
          isDraggable: false,
          isBlurred: blurred,
        ));
      }
    }

    return stack;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (_, __) => SizedBox(
        height: 380,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: _buildStack(),
        ),
      ),
    );
  }
}