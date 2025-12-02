// lib/pages/wav_page.dart
import 'dart:async';
import 'package:flutter/material.dart';

// Firebase
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Local widgets / services
import 'card_stack.dart';
import 'taste_service.dart';
import 'match_service.dart';

class WavPage extends StatefulWidget {
  const WavPage({super.key});

  @override
  State<WavPage> createState() => _WavPageState();
}

class _WavPageState extends State<WavPage> {
  // CardStack key (untyped to avoid private-state type errors)
  final GlobalKey _stackKey = GlobalKey();

  // Firestore / user
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  User? _user;

  // Songs
  List<Map<String, String>> songs = [];
  bool _loadingSongs = true;
  bool _songLoadFailed = false;

  // Daily likes
  static const int _defaultDailyLimit = 12;
  int _likesLeft = _defaultDailyLimit;
  Timestamp? _likesLastReset;

  // UI state for AnimatedSwitcher
  int _likesShown = _defaultDailyLimit;

  // Button hover/press states
  bool _dislikeHovered = false;
  bool _dislikePressed = false;
  bool _likeHovered = false;
  bool _likePressed = false;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _loadSongsFromFirestore();
    _initLikesFromFirestore();
  }

  // --------------------- SONG LOADER ---------------------
  Future<void> _loadSongsFromFirestore() async {
    try {
      final snap = await _db.collection('songs').get();
      final docs = snap.docs;
      if (docs.isEmpty) throw Exception('no songs in firestore');

      songs = docs.map((d) {
        final data = d.data();
        return {
          'title': (data['title'] ?? '')?.toString() ?? '',
          'artist': (data['artist'] ?? '')?.toString() ?? '',
          'genre': (data['genre'] ?? '')?.toString() ?? '',
          'mood': (data['mood'] ?? '')?.toString() ?? '',
          'bpm': (data['bpm'] != null) ? data['bpm'].toString() : '0',
          'key': (data['key'] ?? '')?.toString() ?? '',
          'image': (data['cover'] ?? '')?.toString() ?? '',
        };
      }).toList();

      if (songs.isEmpty) throw Exception('no songs after mapping');

      setState(() {
        _loadingSongs = false;
        _songLoadFailed = false;
      });
    } catch (e, st) {
      debugPrint('Error loading songs: $e\n$st');
      _loadSampleSongs();
      setState(() {
        _loadingSongs = false;
        _songLoadFailed = true;
      });
    }
  }

  void _loadSampleSongs() {
    songs = [
      {'title': 'Blinding Lights', 'artist': 'The Weeknd', 'genre': 'Synthwave', 'mood': 'Energetic', 'bpm': '118', 'key': 'C Major', 'image': 'https://picsum.photos/400/400?random=1'},
      {'title': 'Levitating', 'artist': 'Dua Lipa', 'genre': 'Disco Pop', 'mood': 'Happy', 'bpm': '103', 'key': 'G Minor', 'image': 'https://picsum.photos/400/400?random=2'},
      {'title': 'As It Was', 'artist': 'Harry Styles', 'genre': 'Pop Rock', 'mood': 'Melancholic', 'bpm': '174', 'key': 'F# Minor', 'image': 'https://picsum.photos/400/400?random=3'},
      {'title': 'Anti-Hero', 'artist': 'Taylor Swift', 'genre': 'Synth Pop', 'mood': 'Reflective', 'bpm': '85', 'key': 'A Major', 'image': 'https://picsum.photos/400/400?random=4'},
      {'title': 'Calm Down', 'artist': 'Rema', 'genre': 'Afrobeats', 'mood': 'Chill', 'bpm': '104', 'key': 'D Major', 'image': 'https://picsum.photos/400/400?random=5'},
    ];
  }

  // --------------------- DAILY LIKES (persisted) ---------------------
  Future<void> _initLikesFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      _user = user;

      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

      int savedLeft = (data['dailyLikesLeft'] is int) ? data['dailyLikesLeft'] as int : _defaultDailyLimit;
      Timestamp? savedTs = data['likesLastReset'] as Timestamp?;

      if (savedTs == null) {
        await _writeLikesToFirestore(_defaultDailyLimit, Timestamp.now());
        setState(() {
          _likesLeft = _defaultDailyLimit;
          _likesShown = _likesLeft;
          _likesLastReset = Timestamp.now();
        });
        return;
      }

      final now = DateTime.now();
      final resetAt = savedTs.toDate();
      final diff = now.difference(resetAt);
      if (diff.inHours >= 24) {
        await _writeLikesToFirestore(_defaultDailyLimit, Timestamp.fromDate(now));
        setState(() {
          _likesLeft = _defaultDailyLimit;
          _likesShown = _likesLeft;
          _likesLastReset = Timestamp.fromDate(now);
        });
      } else {
        setState(() {
          _likesLeft = savedLeft;
          _likesShown = _likesLeft;
          _likesLastReset = savedTs;
        });
      }
    } catch (e, st) {
      debugPrint('Error initializing likes: $e\n$st');
      setState(() {
        _likesLeft = _defaultDailyLimit;
        _likesShown = _likesLeft;
      });
    }
  }

  Future<void> _writeLikesToFirestore(int left, Timestamp ts) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _db.collection('users').doc(user.uid).set({
        'dailyLikesLeft': left,
        'likesLastReset': ts,
      }, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('Error writing likes: $e\n$st');
    }
  }

  Future<bool> _consumeLikeAndPersist() async {
    if (_likesLeft <= 0) return false;
    setState(() {
      _likesLeft = _likesLeft - 1;
      _likesShown = _likesLeft;
    });
    final ts = _likesLastReset ?? Timestamp.now();
    await _writeLikesToFirestore(_likesLeft, ts);
    return true;
  }

  Future<void> _restoreLikesForTest() async {
    setState(() {
      _likesLeft = _defaultDailyLimit;
      _likesShown = _likesLeft;
      _likesLastReset = Timestamp.now();
    });
    await _writeLikesToFirestore(_likesLeft, _likesLastReset!);
  }

  // --------------------- RECORD SWIPE ---------------------
  Future<void> _recordSwipe({required bool liked, required Map<String, String> song}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No logged-in user; not recording swipe');
        return;
      }

      final collectionName = liked ? 'likes' : 'dislikes';

      await _db
          .collection('users')
          .doc(user.uid)
          .collection(collectionName)
          .doc(_normalizeSongDocId(song))
          .set({
        'title': song['title'] ?? '',
        'artist': song['artist'] ?? '',
        'genre': song['genre'] ?? '',
        'mood': song['mood'] ?? '',
        'bpm': int.tryParse(song['bpm']?.toString() ?? '0') ?? 0,
        'key': song['key']?.toString() ?? '',
        'image': song['image'] ?? '',
        'swipeType': liked ? 'like' : 'dislike',
        'swipedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('Error recording swipe: $e\n$st');
    }
  }

  String _normalizeSongDocId(Map<String, String> song) {
    final t = (song['title'] ?? '').trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final a = (song['artist'] ?? '').trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return '${t}_$a';
  }

  // --------------------- POST-LIKE: Taste + Match ---------------------
  Future<void> _processAfterLike(Map<String, String> song) async {
    try {
      await TasteService().updateTasteProfileFromSong({
        "artist": song['artist'] ?? '',
        "genre": song['genre'] ?? '',
        "mood": song['mood'] ?? '',
        "bpm": int.tryParse(song['bpm']?.toString() ?? '0') ?? 0,
        "key": song['key'] ?? '',
      });
    } catch (e) {
      debugPrint('TasteService failed: $e');
    }

    try {
      await MatchService().processMatchesForUser();
    } catch (e) {
      debugPrint('MatchService.processMatchesForUser failed: $e');
    }
  }

  // --------------------- ODOMETER COUNTER ---------------------
  Widget _buildOdometerCounter(int value) {
    final String valueStr = value.toString();
    final List<String> digits = valueStr.split('');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: digits.asMap().entries.map((entry) {
        return _OdometerDigit(
          digit: entry.value,
          key: ValueKey('digit_pos_${entry.key}'),
        );
      }).toList(),
    );
  }

  // --------------------- UI BUILD ---------------------
  @override
  Widget build(BuildContext context) {
    if (_loadingSongs) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
        height: constraints.maxHeight,
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 36),

              // ---------- DAILY LIKES DISPLAY ----------
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Your daily likes: ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Premium odometer widget
                    _buildOdometerCounter(_likesShown),
                  ],
                ),
              ),

              // Restore button (testing only)
              TextButton.icon(
                onPressed: _restoreLikesForTest,
                icon: const Icon(Icons.restore, color: Colors.white70, size: 16),
                label: const Text('Restore (test)', style: TextStyle(color: Colors.white70)),
              ),

              const SizedBox(height: 12),

              // ---------- Card stack ----------
              Expanded(
                child: Center(
                  child: CardStack(
                    key: _stackKey,
                    songs: songs,
                    canLike: _likesLeft > 0,
                    onSwipeThreshold: (isLiking, isDisliking) {
                      // Trigger button hover states based on swipe threshold
                      setState(() {
                        _likeHovered = isLiking;
                        _dislikeHovered = isDisliking;
                      });
                    },
                    onLike: (song) async {
                      if (_likesLeft <= 0) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('No likes left — try again tomorrow'),
                              backgroundColor: Colors.red.shade700,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        return;
                      }

                      final consumed = await _consumeLikeAndPersist();
                      if (!consumed) return;

                      await _recordSwipe(liked: true, song: song);
                      await _processAfterLike(song);
                    },
                    onDislike: (song) async {
                      await _recordSwipe(liked: false, song: song);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ---------- Action buttons row ----------
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Dislike (always enabled)
                    MouseRegion(
                      onEnter: (_) => setState(() => _dislikeHovered = true),
                      onExit: (_) => setState(() => _dislikeHovered = false),
                      child: GestureDetector(
                        onTapDown: (_) => setState(() => _dislikePressed = true),
                        onTapUp: (_) => setState(() => _dislikePressed = false),
                        onTapCancel: () => setState(() => _dislikePressed = false),
                        onTap: () {
                          final s = _stackKey.currentState;
                          try {
                            (s as dynamic).triggerDislike();
                          } catch (e) {
                            debugPrint('triggerDislike failed: $e');
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          transform: Matrix4.identity()
                            ..translate(
                              0.0,
                              _dislikePressed ? 4.0 : (_dislikeHovered ? -6.0 : 0.0),
                              0.0,
                            )
                            ..scale(_dislikePressed ? 0.95 : (_dislikeHovered ? 1.08 : 1.0)),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _dislikePressed ? 0.7 : 1.0,
                            child: Image.asset(
                              'assets/images/dislike.png',
                              width: 70,
                              height: 70,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 64),

                    // Like (disabled when no likes left)
                    Opacity(
                      opacity: _likesLeft > 0 ? 1.0 : 0.3,
                      child: MouseRegion(
                        onEnter: (_) {
                          if (_likesLeft > 0) setState(() => _likeHovered = true);
                        },
                        onExit: (_) => setState(() => _likeHovered = false),
                        child: GestureDetector(
                          onTapDown: (_) {
                            if (_likesLeft > 0) setState(() => _likePressed = true);
                          },
                          onTapUp: (_) => setState(() => _likePressed = false),
                          onTapCancel: () => setState(() => _likePressed = false),
                          onTap: () async {
                            if (_likesLeft <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('No likes left — try again tomorrow'),
                                  backgroundColor: Colors.red.shade700,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            // Decrement counter BEFORE animation starts
                            setState(() {
                              _likesShown = _likesLeft - 1;
                            });
                            final s = _stackKey.currentState;
                            try {
                              (s as dynamic).triggerLike();
                            } catch (e) {
                              debugPrint('triggerLike failed: $e');
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOut,
                            transform: Matrix4.identity()
                              ..translate(
                                0.0,
                                _likePressed ? 4.0 : (_likeHovered ? -6.0 : 0.0),
                                0.0,
                              )
                              ..scale(_likePressed ? 0.95 : (_likeHovered ? 1.08 : 1.0)),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 150),
                              opacity: _likePressed ? 0.7 : 1.0,
                              child: Image.asset(
                                'assets/images/like.png',
                                width: 70,
                                height: 70,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// Separate StatefulWidget for individual digit animation
class _OdometerDigit extends StatefulWidget {
  final String digit;

  const _OdometerDigit({required this.digit, required Key key}) : super(key: key);

  @override
  State<_OdometerDigit> createState() => _OdometerDigitState();
}

class _OdometerDigitState extends State<_OdometerDigit> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeOutAnimation;
  late Animation<double> _fadeInAnimation;
  
  String? _oldDigit;
  String _currentDigit = '';

  @override
  void initState() {
    super.initState();
    _currentDigit = widget.digit;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );

    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(_OdometerDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.digit != widget.digit) {
      _oldDigit = _currentDigit;
      _currentDigit = widget.digit;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAnimating = _controller.status == AnimationStatus.forward || 
                             _controller.status == AnimationStatus.reverse;
    
    return SizedBox(
      width: 14,
      height: 28,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ClipRect(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Old digit sliding up and fading out
                if (_oldDigit != null && isAnimating)
                  Transform.translate(
                    offset: Offset(0, -42 * _slideAnimation.value),
                    child: Opacity(
                      opacity: _fadeOutAnimation.value,
                      child: Text(
                        _oldDigit!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                // New digit sliding up from below and fading in
                Transform.translate(
                  offset: Offset(0, isAnimating ? 42 * (1 - _slideAnimation.value) : 0),
                  child: Opacity(
                    opacity: isAnimating ? _fadeInAnimation.value : 1.0,
                    child: Text(
                      _currentDigit,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
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
          );
        },
      ),
    );
  }
}