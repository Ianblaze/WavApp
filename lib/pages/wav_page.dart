// wav_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';

// FIREBASE
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// MATCHING
import '../pages/match_service.dart';
import '../pages/match_dock_popup.dart'; // the slim dock popup you provided earlier

class WavPage extends StatefulWidget {
  const WavPage({super.key});

  @override
  State<WavPage> createState() => _WavPageState();
}

class _WavPageState extends State<WavPage> with TickerProviderStateMixin {
  int currentIndex = 0;
  int displayIndex = 0; // Version 1 index system (keeps stack stable)
  Offset cardOffset = Offset.zero;
  bool isDragging = false;
  bool isAnimating = false;
  bool isExiting = false;
  late final AnimationController _rotationController;
  late final Animation<double> _rotationAnimation;

  // ---------- FIRESTORE HELPERS ----------

  // current center song
  Map<String, String> get _currentSong => _getLoopedSong(displayIndex);

  String _songDocId(Map<String, String> song) {
    final title = (song['title'] ?? 'unknown').replaceAll('/', '_');
    final artist = (song['artist'] ?? 'unknown').replaceAll('/', '_');
    return '${title}_$artist';
  }

  Future<void> _recordSwipe({required bool liked}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('No logged-in user, not recording swipe');
      return;
    }

    final song = _currentSong;
    if ((song['title'] ?? '').isEmpty) {
      debugPrint('Song has no title, not recording swipe');
      return;
    }

    final collectionName = liked ? 'likes' : 'dislikes';

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(collectionName)
          .doc(_songDocId(song))
          .set({
        'title': song['title'],
        'artist': song['artist'],
        'genre': song['genre'],
        'year': song['year'],
        'image': song['image'],
        'swipeType': liked ? 'like' : 'dislike',
        'swipedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('Error recording swipe: $e\n$st');
    }
  }

  // ---------- MATCH POPUP HELPERS ----------

  /// Show the new slide-down Match Dock popup.
  /// Uses the MatchDockPopup widget (slim top-dock style).
  void _showMatchDock({
    required String username,
    required String photoUrl,
    required String matchedUserId,
    required String similarityPlaceholder,
  }) {
    showGeneralDialog(
      context: context,
      barrierLabel: "match",
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (context, anim1, anim2) {
        // We'll return the popup widget directly so MatchDockPopup can control its internal animation.
        return SafeArea(
          child: Material(
            color: Colors.transparent,
            child: MatchDockPopup(
              username: username,
              photoUrl: photoUrl,
              similarity: similarityPlaceholder,
              onConnect: () async {
                try {
                  await MatchService().acceptMatch(matchedUserId);
                } catch (e) {
                  debugPrint('acceptMatch error: $e');
                }
                Navigator.of(context).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Connected!')),
                  );
                }
              },
              onAbandon: () async {
                try {
                  await MatchService().declineMatch(matchedUserId);
                } catch (e) {
                  debugPrint('declineMatch error: $e');
                }
                Navigator.of(context).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Match abandoned')),
                  );
                }
              },
              onDismiss: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
      transitionBuilder: (context, a1, a2, widget) {
        // Fade in behind the dock (the popup itself animates)
        return FadeTransition(
          opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
          child: widget,
        );
      },
    );
  }

  /// Calls match service and shows dock if there's a match.
  Future<void> _checkAndShowMatch(String likedSongDocId) async {
    try {
      final result = await MatchService().checkForMatch(likedSongDocId);
      // result is Map<String, dynamic>? -> { 'uid', 'username', 'photoUrl' }
      if (result == null) return;

      final String otherUid = (result['uid'] ?? '') as String;
      final String username = (result['username'] ?? 'Unknown') as String;
      final String photoUrl = (result['photoUrl'] ?? '') as String;

      if (!mounted) return;

      // placeholder similarity for now as requested
      const String similarityPlaceholder = "78";

      _showMatchDock(
        username: username,
        photoUrl: photoUrl,
        matchedUserId: otherUid,
        similarityPlaceholder: similarityPlaceholder,
      );
    } catch (e, st) {
      debugPrint('Error checking for match: $e\n$st');
    }
  }

  @override
  void initState() {
    super.initState();
    // Slightly slower, buttery rotation
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

  // Sample music data
  final List<Map<String, String>> songs = [
    {
      'title': 'Blinding Lights',
      'artist': 'The Weeknd',
      'genre': 'Synthwave',
      'year': '2019',
      'image': 'https://picsum.photos/400/400?random=1',
    },
    {
      'title': 'Levitating',
      'artist': 'Dua Lipa',
      'genre': 'Disco Pop',
      'year': '2020',
      'image': 'https://picsum.photos/400/400?random=2',
    },
    {
      'title': 'As It Was',
      'artist': 'Harry Styles',
      'genre': 'Pop Rock',
      'year': '2022',
      'image': 'https://picsum.photos/400/400?random=3',
    },
    {
      'title': 'Anti-Hero',
      'artist': 'Taylor Swift',
      'genre': 'Synth Pop',
      'year': '2022',
      'image': 'https://picsum.photos/400/400?random=4',
    },
    {
      'title': 'Calm Down',
      'artist': 'Rema & Selena Gomez',
      'genre': 'Afrobeats',
      'year': '2022',
      'image': 'https://picsum.photos/400/400?random=5',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Fanned card stack
                _buildCardStack(),
                const SizedBox(height: 36),
                // Action buttons
                _buildActionButtons(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardStack() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return SizedBox(
          height: 360 + 20,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: _buildRotatingCards(),
          ),
        );
      },
    );
  }

  /// Build the stack using Version 1 order:
  /// - Add back cards first
  /// - Add center card last so it's always on top and fully draggable
  List<Widget> _buildRotatingCards() {
    List<Widget> cards = [];
    Widget? centerCardWidget;

    // Use rotation progress only when exiting is false so fan animates
    double progress = isExiting ? 0 : (_rotationAnimation.value);

    // Generate positions from back to front (2 down to -2); center (i==0) will be added last
    for (int i = 2; i >= -2; i--) {
      // Hide center card during rotation to avoid snapback
      if (i == 0 && isAnimating && !isExiting) continue;

      double effectivePosition = i - progress;

      // Card transforms based on effectivePosition
      double horizontalOffset = effectivePosition * 100; // reduced spread for smaller stack
      double scale = 0.92 - (effectivePosition.abs() * 0.08); // slightly smaller overall
      double rotation = effectivePosition * 0.07;
      bool isBlurred = effectivePosition.abs() > 0.1;

      // Cull distant cards
      if (effectivePosition < -2.5 || effectivePosition > 2.5) continue;

      // If center card is exiting and far offscreen, skip rendering it here
      if (i == 0 && isExiting && cardOffset.dy.abs() > 600) continue;

      // Opacity falloff
      double opacity = isBlurred ? 0.6 : 1.0;
      if (effectivePosition.abs() > 2) {
        opacity = (2.5 - effectivePosition.abs()) * 2;
      }

      Map<String, String> song = _getLoopedSong(displayIndex + i);

      Widget card;

      // CENTER CARD: when it's the active, show a slightly larger scale that animates with progress
      if (i == 0 && !isAnimating && !isExiting) {
        // centerScale goes from 1.00 to 1.05 as effectivePosition -> 0
        double centerScale = 1.0 + (0.08 * (1.0 - effectivePosition.abs()).clamp(0.0, 1.0));
        Widget center = TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: centerScale),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Transform.scale(
            scale: value,
            child: child,
          ),
          child: _buildCard(
            song,
            0,
            centerScale,
            0,
            isBlurred: false,
            isDraggable: true,
          ),
        );
        centerCardWidget = Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: center,
        );
        continue; // already handled center — add later
      }

      // If center card is exiting, render it using cardOffset
      if (i == 0 && isExiting) {
        double fadeOpacity = (1 - (cardOffset.dy.abs() / 500)).clamp(0.0, 1.0);
        card = Transform.translate(
          offset: cardOffset,
          child: Opacity(
            opacity: fadeOpacity,
            child: _buildCard(song, 0, 1.0, 0, isBlurred: false, isDraggable: false),
          ),
        );
      } else {
        // non-center cards get fan transforms
        card = _buildCard(song, horizontalOffset, scale, rotation, isBlurred: isBlurred, isDraggable: false);
      }

      final wrapped = Opacity(opacity: opacity.clamp(0.0, 1.0), child: card);

      // collect back cards first
      if (i == 0) {
        centerCardWidget = wrapped;
      } else {
        cards.add(wrapped);
      }
    }

    // finally add center (top) if present
    if (centerCardWidget != null) cards.add(centerCardWidget);
    return cards;
  }

  // Get song with looping
  Map<String, String> _getLoopedSong(int index) {
    if (songs.isEmpty) {
      return {
        'title': '',
        'artist': '',
        'genre': '',
        'year': '',
        'image': ''
      };
    }
    int loopedIndex = index % songs.length;
    if (loopedIndex < 0) loopedIndex += songs.length;
    return songs[loopedIndex];
  }

  Widget _buildCard(
    Map<String, String> song,
    double horizontalOffset,
    double scale,
    double rotation, {
    required bool isBlurred,
    required bool isDraggable,
  }) {
    Widget cardContent = Container(
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
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Album art background
            Positioned.fill(
              child: Transform.translate(
                offset: isDraggable ? Offset(cardOffset.dx * -0.05, cardOffset.dy * -0.05) : Offset.zero,
                child: Image.network(
                  song['image'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF282828),
                    );
                  },
                ),
              ),
            ),

            // Gradient overlay
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
                    stops: const [0.4, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // Song info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song['title'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      song['artist'] ?? '',
                      style: const TextStyle(
                        color: Color(0xFFB3B3B3),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${song['genre'] ?? ''} • ${song['year'] ?? ''}',
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Apply blur effect to non-center cards
    if (isBlurred) {
      cardContent = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Opacity(
          opacity: 0.6,
          child: cardContent,
        ),
      );
    }

    // If draggable, wrap with gesture detector (v1: opaque hit-testing)
    if (isDraggable) {
      cardContent = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          setState(() => isDragging = true);
        },
        onPanUpdate: (details) {
          setState(() {
            cardOffset += details.delta;
          });
        },
        onPanEnd: (details) {
          setState(() => isDragging = false);

          // Detect swipe up / down thresholds
          if (cardOffset.dy > 150) {
            _handleLikeWithSwipe();
          } else if (cardOffset.dy < -150) {
            _handleDislikeWithSwipe();
          } else {
            // Reset smoothly
            setState(() {
              cardOffset = Offset.zero;
            });
          }
        },
        child: AnimatedContainer(
          duration: isDragging ? Duration.zero : const Duration(milliseconds: 300),
          curve: Curves.easeOutQuad,
          transform: Matrix4.translationValues(cardOffset.dx, cardOffset.dy, 0),
          child: Opacity(
            opacity: isDragging ? (1 - (cardOffset.dy.abs() / 500)).clamp(0.3, 1.0) : 1.0,
            child: cardContent,
          ),
        ),
      );

      return cardContent;
    }

    // Non-draggable card - apply fan transforms
    return Transform.translate(
      offset: Offset(horizontalOffset, 0),
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale,
          child: cardContent,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: 300,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Dislike
            GestureDetector(
              onTap: _handleDislike,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SvgPicture.asset(
                  'assets/images/dislikee.svg',
                  width: 70,
                  height: 70,
                ),
              ),
            ),

            // Like
            GestureDetector(
              onTap: _handleLike,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SvgPicture.asset(
                  'assets/images/likee.svg',
                  width: 70,
                  height: 70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------- SWIPE HANDLERS (corrected order) -----------------

  Future<void> _handleLikeWithSwipe() async {
    if (isAnimating) return;

    // capture liked song docId BEFORE we change indices
    final likedSong = _currentSong;
    final likedSongDocId = _songDocId(likedSong);

    // record like
    await _recordSwipe(liked: true);

    setState(() {
      isAnimating = true;
      isExiting = true;
    });

    // Continue the current drag off-screen smoothly
    final currentY = cardOffset.dy;
    final int steps = 30;
    final double targetY = 700;
    final double stepSize = (targetY - currentY) / steps;

    for (int i = 0; i < steps; i++) {
      if (!mounted) return;
      setState(() {
        cardOffset = Offset(0, currentY + (stepSize * (i + 1)));
      });
      await Future.delayed(const Duration(milliseconds: 14));
    }

    if (!mounted) return;

    // Enable rotation animation to run using progress
    setState(() {
      isExiting = false;
    });

    // Run rotation animation
    await _rotationController.forward();

    if (!mounted) return;

    // Now advance displayIndex (v1 style) so stack shows the next set and reset flags AFTER rotation
    setState(() {
      displayIndex = (displayIndex + 1) % songs.length;
      currentIndex = displayIndex; // stable index
      cardOffset = Offset.zero; // reset AFTER rotation to avoid snapback
      isExiting = false;
      isAnimating = false;
    });
    _rotationController.reset();

    // Check for mutual match based on liked song
    await _checkAndShowMatch(likedSongDocId);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❤️ Added to your likes!'),
        backgroundColor: Color(0xFF1DB954),
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  Future<void> _handleDislikeWithSwipe() async {
    if (isAnimating) return;

    // capture disliked song id (if needed)
    final dislikedSong = _currentSong;
    final dislikedSongDocId = _songDocId(dislikedSong);

    // record dislike (no match check for dislikes)
    await _recordSwipe(liked: false);

    setState(() {
      isAnimating = true;
      isExiting = true;
    });

    final currentY = cardOffset.dy;
    final int steps = 30;
    final double targetY = -700;
    final double stepSize = (targetY - currentY) / steps;

    for (int i = 0; i < steps; i++) {
      if (!mounted) return;
      setState(() {
        cardOffset = Offset(0, currentY + (stepSize * (i + 1)));
      });
      await Future.delayed(const Duration(milliseconds: 14));
    }

    if (!mounted) return;

    // Enable rotation animation to run using progress
    setState(() {
      isExiting = false;
    });

    await _rotationController.forward();

    if (!mounted) return;

    setState(() {
      displayIndex = (displayIndex + 1) % songs.length;
      currentIndex = displayIndex;
      cardOffset = Offset.zero; // reset AFTER rotation
      isExiting = false;
      isAnimating = false;
    });
    _rotationController.reset();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('👎 Passed'),
        backgroundColor: Color(0xFF535353),
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  // ----------------- BUTTON HANDLERS (like above) -----------------

  Future<void> _handleLike() async {
    if (isAnimating) return;

    // capture liked song docId BEFORE we change indices
    final likedSong = _currentSong;
    final likedSongDocId = _songDocId(likedSong);

    // record like
    await _recordSwipe(liked: true);

    setState(() {
      isAnimating = true;
      isExiting = true;
    });

    final int steps = 30;
    final double targetY = 700;
    final double stepSize = targetY / steps;

    for (int i = 0; i < steps; i++) {
      if (!mounted) return;
      setState(() {
        cardOffset = Offset(0, stepSize * (i + 1));
      });
      await Future.delayed(const Duration(milliseconds: 14));
    }

    if (!mounted) return;

    // Allow rotation to animate
    setState(() {
      isExiting = false;
    });

    await _rotationController.forward();

    if (!mounted) return;

    setState(() {
      displayIndex = (displayIndex + 1) % songs.length;
      currentIndex = displayIndex;
      cardOffset = Offset.zero; // reset AFTER rotation
      isExiting = false;
      isAnimating = false;
    });
    _rotationController.reset();

    // Check for mutual match based on liked song
    await _checkAndShowMatch(likedSongDocId);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❤️ Added to your likes!'),
        backgroundColor: Color(0xFF1DB954),
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  Future<void> _handleDislike() async {
    if (isAnimating) return;

    // record dislike
    await _recordSwipe(liked: false);

    setState(() {
      isAnimating = true;
      isExiting = true;
    });

    final int steps = 30;
    final double targetY = -700;
    final double stepSize = targetY / steps;

    for (int i = 0; i < steps; i++) {
      if (!mounted) return;
      setState(() {
        cardOffset = Offset(0, stepSize * (i + 1));
      });
      await Future.delayed(const Duration(milliseconds: 14));
    }

    if (!mounted) return;

    setState(() {
      isExiting = false;
    });

    await _rotationController.forward();

    if (!mounted) return;

    setState(() {
      displayIndex = (displayIndex + 1) % songs.length;
      currentIndex = displayIndex;
      cardOffset = Offset.zero; // reset AFTER rotation
      isExiting = false;
      isAnimating = false;
    });
    _rotationController.reset();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('👎 Passed'),
        backgroundColor: Color(0xFF535353),
        duration: Duration(milliseconds: 800),
      ),
    );
  }
}
