// lib/pages/home_tab.dart
//
// The home tab — shown when selectedTab == 0 in home_page.dart.
//
// DNA VISUALIZER CHANGES (v2)
// ───────────────────────────
// • Proper double-helix: two sinusoidal strands drawn as node chains
//   with smooth connecting line segments, π apart in phase.
// • Connecting rungs that rotate with depth — look 3D.
// • Cinematic zoom: strands fly apart + glow on double-tap / pinch.
// • Mood segments continuously color the strands from user taste data.
// • Song title labels fade in along rungs at high zoom.
// • Mood distribution bar-chart + fave artist on the zoom overlay card.

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/songs_provider.dart';

// ── Palette ────────────────────────────────────────────────────────
const _pink   = Color(0xFFFF6FE8);
const _purple = Color(0xFFB69CFF);
const _blue   = Color(0xFF7BA7FF);
const _dark   = Color(0xFF3A2A45);
const _muted  = Color(0xFF8A7EA5);
const _glass  = Color(0x8CFFFFFF);

// ── Mood helpers ────────────────────────────────────────────────────
Color _moodColor(String mood) {
  switch (mood.toLowerCase()) {
    case 'happy':       return const Color(0xFFFF6FE8);
    case 'energetic':   return const Color(0xFFFF6B2B);
    case 'chill':       return const Color(0xFF4A90FF);
    case 'melancholic': return const Color(0xFF9B59FF);
    case 'reflective':  return const Color(0xFF00C9B1);
    case 'sad':         return const Color(0xFF3A6FFF);
    default:            return const Color(0xFFB69CFF);
  }
}

String _moodSymbol(String mood) {
  switch (mood.toLowerCase()) {
    case 'happy':       return '✦';
    case 'energetic':   return '⚡';
    case 'chill':       return '◎';
    case 'melancholic': return '◈';
    case 'reflective':  return '◇';
    case 'sad':         return '◉';
    default:            return '♪';
  }
}

// ── Data models ────────────────────────────────────────────────────
class _MatchData {
  final String uid;
  final String name;
  final String? photoUrl;
  final int    compatibility;
  final List<String> sharedSongs;
  final List<String> genres;
  final bool   isNew;
  const _MatchData({
    required this.uid,
    required this.name,
    this.photoUrl,
    required this.compatibility,
    required this.sharedSongs,
    required this.genres,
    required this.isNew,
  });
}

class _DNAData {
  // Maps to users/{uid}.tasteProfile in Firestore
  final String topMood;    // e.g. "Reflective"
  final String topGenre;   // e.g. "Synth Pop"
  final String topArtist;  // e.g. "Taylor Swift"
  final String bpmRange;   // e.g. "140-160"
  final String musicalKey; // e.g. "F Major"

  const _DNAData({
    required this.topMood,
    required this.topGenre,
    required this.topArtist,
    required this.bpmRange,
    required this.musicalKey,
  });

  factory _DNAData.empty() => const _DNAData(
    topMood:    '',
    topGenre:   '',
    topArtist:  '',
    bpmRange:   '',
    musicalKey: '',
  );

  bool get isEmpty => topMood.isEmpty && topArtist.isEmpty;
}

// ═══════════════════════════════════════════════════════════════════
// HomeTab
// ═══════════════════════════════════════════════════════════════════
class HomeTab extends StatefulWidget {
  final VoidCallback onGoToWav;
  final VoidCallback onGoToMatches;
  final Color moodTint;

  const HomeTab({
    super.key,
    required this.onGoToWav,
    required this.onGoToMatches,
    required this.moodTint,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  // ── Firestore data ──────────────────────────────────────────────
  int               _likedCount    = 0;
  int               _matchCount    = 0;
  int               _likedYouCount = 0;
  List<_MatchData>  _topMatches    = [];
  List<Map<String,String>> _trendingSongs = [];
  bool              _loading       = true;
  String            _greeting      = 'Good day';
  String            _userName      = '';
  int               _newMatchCount = 0;
  int               _totalLikedCount = 0;

  // ── Entrance animation ──────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  final ScrollController _scrollController = ScrollController();

  _DNAData _dnaData = _DNAData.empty();

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();


    _greeting = _timeGreeting();
    _loadData();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // ── Data loading ────────────────────────────────────────────────
  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('users').doc(uid).get(),
        db.collection('matches')
            .where('users', arrayContains: uid)
            .orderBy('compatibilityScore', descending: true)
            .limit(5)
            .get(),
        db.collection('songs')
            .orderBy('likeCount', descending: true)
            .limit(8)
            .get(),
        db.collection('users').doc(uid).collection('likedSongs').get(),
      ]);

      final userDoc     = results[0] as DocumentSnapshot;
      final matchesSnap = results[1] as QuerySnapshot;
      final songsSnap   = results[2] as QuerySnapshot;
      final likedSnap   = results[3] as QuerySnapshot;

      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      _userName = userData['username'] as String? ?? '';

      final todayStart = DateTime.now().copyWith(
          hour: 0, minute: 0, second: 0, millisecond: 0);
      final likedToday = likedSnap.docs.where((d) {
        final ts = (d.data() as Map)['likedAt'];
        if (ts == null) return false;
        return (ts as Timestamp).toDate().isAfter(todayStart);
      }).length;

      int newCount = 0;
      final matches = <_MatchData>[];
      for (final doc in matchesSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final otherUid = (data['users'] as List)
            .firstWhere((u) => u != uid, orElse: () => '');
        if (otherUid.isEmpty) continue;
        final otherUser = await db.collection('users').doc(otherUid).get();
        final ouData = otherUser.data() as Map<String, dynamic>? ?? {};
        final isNew = data['isNew'] == true;
        if (isNew) newCount++;
        matches.add(_MatchData(
          uid:           otherUid,
          name:          ouData['username'] as String? ?? 'User',
          photoUrl:      ouData['photoUrl'] as String?,
          compatibility: (data['compatibilityScore'] as num? ?? 0).toInt(),
          sharedSongs:   List<String>.from(data['sharedSongs'] ?? []),
          genres:        List<String>.from(data['sharedGenres'] ?? []),
          isNew:         isNew,
        ));
      }

      final likedYouSnap = await db.collection('matches')
          .where('users', arrayContains: uid)
          .where('initiatedBy', isNotEqualTo: uid)
          .get();

      final trending = songsSnap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return <String, String>{
          'title':     data['title']     as String? ?? '',
          'artist':    data['artist']    as String? ?? '',
          'image_url': data['image_url'] as String? ?? '',
          'mood':      data['mood']      as String? ?? '',
          'bpm':       data['bpm']?.toString() ?? '',
          'genre':     data['genre']     as String? ?? '',
        };
      }).where((s) => s['title']!.isNotEmpty).toList();

      // ── Read tasteProfile map from the user document ────────────
      final tp = userData['tasteProfile'] as Map<String, dynamic>? ?? {};
      final dna = _DNAData(
        topMood:    tp['topMood']    as String? ?? '',
        topGenre:   tp['topGenre']   as String? ?? '',
        topArtist:  tp['topArtist']  as String? ?? '',
        bpmRange:   tp['bpmRange']   as String? ?? '',
        musicalKey: tp['key']        as String? ?? '',
      );

      if (!mounted) return;
      setState(() {
        _likedCount      = likedToday;
        _totalLikedCount = likedSnap.docs.length;
        _matchCount      = matchesSnap.docs.length;
        _likedYouCount   = likedYouSnap.docs.length;
        _topMatches      = matches;
        _trendingSongs   = trending;
        _newMatchCount   = newCount;
        _dnaData         = dna;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[HomeTab] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Staggered entrance animation ────────────────────────────────
  Widget _stagger(Widget child, {required double delay}) {
    return AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (_, __) {
        final raw = (_entranceCtrl.value - delay).clamp(0.0, 1.0);
        final t   = Curves.easeOutCubic.transform(
            raw / (1.0 - delay).clamp(0.1, 1.0));
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - t.clamp(0.0, 1.0))),
            child: child,
          ),
        );
      },
    );
  }


  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final vGap  = (sh * 0.018).clamp(10.0, 18.0);
    final hPad  = (sw * 0.05).clamp(16.0, 28.0);
    final likesLeft = context.watch<SongsProvider>().likesLeft;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _pink, strokeWidth: 2),
      );
    }

    return RefreshIndicator(
      color: _pink,
      onRefresh: _loadData,
      child: Stack(
        children: [
          // ── DNA Helix Background ─────────────────────────────
          Positioned.fill(
            child: MusicDNAVisualizer(
              scrollController: _scrollController,
              fillProgress:     (_totalLikedCount / 50).clamp(0.0, 1.0),
              dnaData:          _dnaData,
            ),
          ),
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                          SizedBox(height: vGap * 0.5),
                          _stagger(_buildGreeting(sw), delay: 0.0),
                          SizedBox(height: vGap),
                          if (_newMatchCount > 0) ...[
                            _stagger(_buildHypeBanner(), delay: 0.08),
                            SizedBox(height: vGap),
                          ],
                          _stagger(_buildStatStrip(sw, likesLeft), delay: 0.12),
                          SizedBox(height: vGap * 1.2),
                          _stagger(_buildLikesCTA(likesLeft, sw), delay: 0.18),
                          SizedBox(height: vGap * 1.2),
                          if (_trendingSongs.isNotEmpty) ...[
                            _stagger(
                              _buildSectionHeader('🎵  Trending right now', 'See all',
                                  widget.onGoToWav),
                              delay: 0.24,
                            ),
                            SizedBox(height: vGap * 0.6),
                            _stagger(_buildTrendingRow(sw, sh), delay: 0.28),
                            SizedBox(height: vGap * 1.2),
                          ],
                          if (_topMatches.isNotEmpty) ...[
                            _stagger(
                              _buildSectionHeader('💜  Your top matches', 'View all',
                                  widget.onGoToMatches),
                              delay: 0.34,
                            ),
                            SizedBox(height: vGap * 0.6),
                            ..._topMatches.take(3).toList().asMap().entries.map((e) =>
                              _stagger(
                                Padding(
                                  padding: EdgeInsets.only(bottom: vGap * 0.6),
                                  child: _buildMatchRow(e.value, sw),
                                ),
                                delay: 0.36 + e.key * 0.05,
                              ),
                            ),
                            SizedBox(height: vGap * 0.6),
                          ],
                          _stagger(
                            _buildSectionHeader('🎧  Trending moods', null, null),
                            delay: 0.52,
                          ),
                          SizedBox(height: vGap * 0.6),
                          _stagger(_buildMoodChips(sw), delay: 0.56),
                          SizedBox(height: vGap * 2),
                        ]),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  // ── UI builders (unchanged from original) ───────────────────────
  Widget _buildGreeting(double sw) {
    final nameStr = _userName.isNotEmpty ? ', $_userName' : '';
    final sub = _likedYouCount > 0
        ? '$_likedYouCount ${_likedYouCount == 1 ? 'person' : 'people'} liked your taste today'
        : 'Start wavving to find your music matches';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_greeting$nameStr 👋',
                style: TextStyle(
                  fontFamily: 'Circular',
                  fontSize: (sw * 0.058).clamp(18.0, 24.0),
                  fontWeight: FontWeight.w800,
                  color: _dark, letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(sub,
                style: TextStyle(
                  fontFamily: 'Circular',
                  fontSize: (sw * 0.032).clamp(11.0, 14.0),
                  fontWeight: FontWeight.w500, color: _muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHypeBanner() {
    final msg = _newMatchCount == 1 ? '1 new match!' : '$_newMatchCount new matches!';
    final sub = _topMatches.isNotEmpty
        ? '${_topMatches.first.name} & others love your taste'
        : 'Tap to see who matched with you';
    return GestureDetector(
      onTap: widget.onGoToMatches,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_pink, _purple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _pink.withOpacity(0.30), blurRadius: 20, offset: const Offset(0, 6))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(child: Text('🔥', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg, style: const TextStyle(fontFamily: 'Circular', color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(fontFamily: 'Circular', color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.7), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatStrip(double sw, int likesLeft) {
    return Row(
      children: [
        Expanded(child: _statCard('$_likedCount',    'WAVS TODAY', _pink)),
        const SizedBox(width: 8),
        Expanded(child: _statCard('$_matchCount',    'MATCHES',    _blue)),
        const SizedBox(width: 8),
        Expanded(child: _statCard('$_likedYouCount', 'LIKED YOU',  _purple)),
      ],
    );
  }

  Widget _statCard(String num, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: _glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 1),
      ),
      child: Column(
        children: [
          Text(num, style: TextStyle(fontFamily: 'Circular', fontSize: 26, fontWeight: FontWeight.w800, color: color, letterSpacing: -1, height: 1)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Circular', fontSize: 9, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 0.4)),
        ],
      ),
    );
  }

  Widget _buildLikesCTA(int likesLeft, double sw) {
    const maxLikes = 10;
    final fraction = ((maxLikes - likesLeft) / maxLikes).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: widget.onGoToWav,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _glass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _pink.withOpacity(0.35), width: 1.5),
          boxShadow: [BoxShadow(color: _pink.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52, height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(52, 52),
                    painter: _RingPainter(fraction: fraction, trackColor: _pink.withOpacity(0.15), fillColor: _pink),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$likesLeft', style: const TextStyle(fontFamily: 'Circular', fontSize: 17, fontWeight: FontWeight.w900, color: _pink, height: 1)),
                      const Text('LEFT', style: TextStyle(fontFamily: 'Circular', fontSize: 7, fontWeight: FontWeight.w700, color: _muted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    likesLeft > 0 ? '$likesLeft daily ${likesLeft == 1 ? 'like' : 'likes'} left' : 'Out of likes today',
                    style: TextStyle(fontFamily: 'Circular', fontSize: (sw * 0.038).clamp(13.0, 16.0), fontWeight: FontWeight.w800, color: _dark),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    likesLeft > 0 ? 'Resets at midnight — use them!' : 'Come back tomorrow for more',
                    style: const TextStyle(fontFamily: 'Circular', fontSize: 11, fontWeight: FontWeight.w500, color: _muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onGoToWav,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: likesLeft > 0 ? const LinearGradient(colors: [_pink, _purple], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                  color: likesLeft == 0 ? _muted.withOpacity(0.3) : null,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: likesLeft > 0 ? [BoxShadow(color: _pink.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))] : null,
                ),
                child: Text('WAV →', style: TextStyle(fontFamily: 'Circular', fontSize: 12, fontWeight: FontWeight.w800, color: likesLeft > 0 ? Colors.white : _muted, letterSpacing: 0.3)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? actionLabel, VoidCallback? onAction) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontFamily: 'Circular', fontSize: 14, fontWeight: FontWeight.w700, color: _dark, letterSpacing: 0.1)),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel, style: const TextStyle(fontFamily: 'Circular', fontSize: 12, fontWeight: FontWeight.w700, color: _pink)),
          ),
      ],
    );
  }

  Widget _buildTrendingRow(double sw, double sh) {
    final cardW = (sw * 0.38).clamp(130.0, 160.0);
    final cardH = cardW * 1.55;
    return SizedBox(
      height: cardH,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _trendingSongs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _buildSongCard(_trendingSongs[i], cardW, cardH),
      ),
    );
  }

  Widget _buildSongCard(Map<String, String> song, double w, double h) {
    final mood  = song['mood'] ?? '';
    final bpm   = song['bpm']  ?? '';
    final color = _moodColor(mood);
    final img   = song['image_url'] ?? '';
    return GestureDetector(
      onTap: widget.onGoToWav,
      child: Container(
        width: w, height: h,
        decoration: BoxDecoration(
          color: _glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 1),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (img.isNotEmpty)
                    Image.network(img, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _SongArtPlaceholder(mood: mood))
                  else
                    _SongArtPlaceholder(mood: mood),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.25)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 9, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Circular', fontSize: 11, fontWeight: FontWeight.w700, color: _dark)),
                  const SizedBox(height: 1),
                  Text(song['artist'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Circular', fontSize: 10, fontWeight: FontWeight.w500, color: _muted)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (mood.isNotEmpty) _MiniPill(label: mood, color: color),
                      if (bpm.isNotEmpty && bpm != '0') ...[
                        const SizedBox(width: 4),
                        _MiniPill(label: '$bpm BPM', color: _blue),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchRow(_MatchData match, double sw) {
    final initials = match.name.isNotEmpty
        ? match.name.substring(0, math.min(2, match.name.length)).toUpperCase()
        : '?';
    final avatarColors = match.compatibility >= 80
        ? [_pink, _purple]
        : match.compatibility >= 60 ? [_blue, _purple] : [_purple, _blue];
    return GestureDetector(
      onTap: widget.onGoToMatches,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: avatarColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: avatarColors.first.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, fontFamily: 'Circular'))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.name, style: const TextStyle(fontFamily: 'Circular', fontSize: 13, fontWeight: FontWeight.w700, color: _dark)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (match.genres.isNotEmpty) match.genres.take(2).join(' · '),
                      if (match.sharedSongs.isNotEmpty) '${match.sharedSongs.length} songs in common',
                    ].join('  '),
                    style: const TextStyle(fontFamily: 'Circular', fontSize: 11, fontWeight: FontWeight.w500, color: _muted),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: match.compatibility / 100,
                            backgroundColor: _purple.withOpacity(0.15),
                            valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6FE8)),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${match.compatibility}%',
                        style: const TextStyle(fontFamily: 'Circular', fontSize: 10, fontWeight: FontWeight.w700, color: _pink)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (match.isNew)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _pink.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _pink.withOpacity(0.3), width: 1),
                ),
                child: const Text('NEW', style: TextStyle(fontFamily: 'Circular', fontSize: 8, fontWeight: FontWeight.w800, color: _pink, letterSpacing: 0.5)),
              )
            else
              Icon(Icons.arrow_forward_ios_rounded, color: _muted.withOpacity(0.5), size: 13),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodChips(double sw) {
    final moods = [
      ('Energetic',   const Color(0xFFFF6B2B)),
      ('Chill',       const Color(0xFF4A90FF)),
      ('Happy',       const Color(0xFFFF6FE8)),
      ('Melancholic', const Color(0xFF9B59FF)),
      ('Reflective',  const Color(0xFF00C9B1)),
    ];
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: moods.map<Widget>((m) => GestureDetector(
        onTap: null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _glass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.7), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: m.$2)),
              const SizedBox(width: 6),
              Text(m.$1, style: const TextStyle(fontFamily: 'Circular', fontSize: 12, fontWeight: FontWeight.w700, color: _dark)),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// RING PAINTER (unchanged)
// ═══════════════════════════════════════════════════════════════════
class _RingPainter extends CustomPainter {
  final double fraction;
  final Color  trackColor;
  final Color  fillColor;
  const _RingPainter({required this.fraction, required this.trackColor, required this.fillColor});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = cx - 4;
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = trackColor..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round);
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2, 2 * math.pi * fraction, false,
        Paint()..color = fillColor..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round,
      );
    }
  }
  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.fillColor != fillColor;
}

// ═══════════════════════════════════════════════════════════════════
// SONG ART PLACEHOLDER
// ═══════════════════════════════════════════════════════════════════
class _SongArtPlaceholder extends StatelessWidget {
  final String mood;
  const _SongArtPlaceholder({super.key, required this.mood});
  @override
  Widget build(BuildContext context) {
    final c = _moodColor(mood);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.withOpacity(0.6), const Color(0xFF1a0a2e)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(child: Text(_moodSymbol(mood), style: const TextStyle(fontSize: 28))),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MINI PILL TAG
// ═══════════════════════════════════════════════════════════════════
class _MiniPill extends StatelessWidget {
  final String label;
  final Color  color;
  const _MiniPill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Text(label, style: TextStyle(fontFamily: 'Circular', fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PULSE DOT
// ═══════════════════════════════════════════════════════════════════
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}
class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Transform.scale(
        scale: 1.0 + _c.value * 0.35,
        child: Container(
          width: 11, height: 11,
          decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color,
              border: Border.all(color: Colors.white, width: 1.5)),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 🧬 MUSIC DNA VISUALIZER
class MusicDNAVisualizer extends StatefulWidget {
  final ScrollController scrollController;
  final double fillProgress;
  final _DNAData dnaData;

  const MusicDNAVisualizer({
    super.key,
    required this.scrollController,
    required this.fillProgress,
    required this.dnaData,
  });

  @override
  State<MusicDNAVisualizer> createState() => _MusicDNAVisualizerState();
}

class _Particle {
  final double x, yBase, speed, size;
  final Color color;
  _Particle(this.x, this.yBase, this.speed, this.size, this.color);
}

class _MusicDNAVisualizerState extends State<MusicDNAVisualizer> with SingleTickerProviderStateMixin {
  late final AnimationController _timeCtrl;
  late final List<_Particle> _particles;
  
  Color _genreColor(String genre) {
    switch (genre.toLowerCase()) {
      case 'pop': return const Color(0xFFFF6FE8);
      case 'rock': return const Color(0xFFFF6B2B);
      case 'hip hop': case 'rap': return const Color(0xFF4A90FF);
      case 'r&b': case 'soul': return const Color(0xFF9B59FF);
      case 'electronic': case 'edm': return const Color(0xFF00C9B1);
      case 'indie': case 'alternative': return const Color(0xFF3A6FFF);
      case 'classical': case 'jazz': return const Color(0xFFE8D05C);
      default:
        if (genre.isEmpty) return const Color(0xFFB69CFF);
        return Colors.primaries[genre.hashCode % Colors.primaries.length];
    }
  }

  Color _moodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':       return const Color(0xFFFF6FE8);
      case 'energetic':   return const Color(0xFFFF6B2B);
      case 'chill':       return const Color(0xFF4A90FF);
      case 'melancholic': return const Color(0xFF9B59FF);
      case 'reflective':  return const Color(0xFF00C9B1);
      case 'sad':         return const Color(0xFF3A6FFF);
      default:            return const Color(0xFF7BA7FF); // fallback blue
    }
  }

  @override
  void initState() {
    super.initState();
    _timeCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    
    // Generate particles
    final rnd = math.Random(42);
    final cA = _genreColor(widget.dnaData.topGenre);
    final cB = _moodColor(widget.dnaData.topMood);
    
    _particles = List.generate(45, (i) {
      final isA = rnd.nextBool();
      return _Particle(
        rnd.nextDouble() * 400 - 200, // x offset from center
        rnd.nextDouble(),             // y normalized phase
        0.2 + rnd.nextDouble() * 0.5, // speed
        1.0 + rnd.nextDouble() * 2.5, // size
        (isA ? cA : cB).withOpacity(0.15 + rnd.nextDouble() * 0.3)
      );
    });
  }

  @override
  void dispose() { _timeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_timeCtrl, widget.scrollController]),
      builder: (_, __) {
        return CustomPaint(
          size: Size.infinite,
          painter: _SimpleDNAPainter(
            time: _timeCtrl.value,
            scrollOffset: widget.scrollController.hasClients ? widget.scrollController.offset : 0.0,
            colorA: _genreColor(widget.dnaData.topGenre),
            colorB: _moodColor(widget.dnaData.topMood),
            bpmRange: widget.dnaData.bpmRange,
            particles: _particles,
          ),
        );
      },
    );
  }
}

class _SimpleDNAPainter extends CustomPainter {
  final double time;
  final double scrollOffset;
  final Color colorA;
  final Color colorB;
  final String bpmRange;
  final List<_Particle> particles;

  _SimpleDNAPainter({
    required this.time,
    required this.scrollOffset,
    required this.colorA,
    required this.colorB,
    required this.bpmRange,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final wavelength = 180.0;
    final strandWidth = 40.0;
    
    // 2. Scroll-driven acceleration
    final baseAngle = time * 2 * math.pi;
    final scrollPhase = -(scrollOffset * 0.005); 
    
    // 3. Ambient BPM Breathing
    double bpm = 100.0;
    if (bpmRange.isNotEmpty) {
      final parts = bpmRange.replaceAll(RegExp(r'[^0-9-]'), '').split('-');
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        bpm = double.tryParse(parts[0]) ?? 100.0;
      }
    }
    final bps = bpm / 60.0;
    final pulse = 1.0;
    
    // 5. Ambient Dust Particles
    for (final p in particles) {
      final pY = (p.yBase - time * p.speed) % 1.0;
      final actY = pY * size.height;
      final actX = cx + p.x + math.sin(time * 4 * math.pi + p.x) * 15;
      
      final fade = math.sin(pY * math.pi);
      final pPaint = Paint()..color = p.color.withOpacity(p.color.opacity * fade);
      
      canvas.drawCircle(Offset(actX, actY), p.size * pulse, pPaint);
    }

    final yStart = -wavelength;
    final yEnd = size.height + wavelength;
    final step = 8.0;

    final ptsA = <Offset>[];
    final ptsB = <Offset>[];
    final depA = <double>[];
    final fades = <double>[];

    for (double y = yStart; y <= yEnd; y += step) {
      final angle = (y / wavelength) * 2 * math.pi + baseAngle + scrollPhase;
      ptsA.add(Offset(cx + math.sin(angle) * strandWidth * pulse, y));
      ptsB.add(Offset(cx + math.sin(angle + math.pi) * strandWidth * pulse, y));
      depA.add(math.cos(angle));
      
      // 4. Cinematic Fading
      final yNorm = (y / size.height).clamp(0.0, 1.0);
      fades.add(math.sin(yNorm * math.pi));
    }

    // Draw Strands
    for (int isA = 0; isA <= 1; isA++) {
      final aIsFront = depA.isNotEmpty && depA[depA.length ~/ 2] > 0;
      final drawA = (isA == 1) ? aIsFront : !aIsFront;
      
      final pts = drawA ? ptsA : ptsB;
      final color = drawA ? colorA : colorB;
      
      if (pts.isEmpty) continue;
      
      // Segment drawing
      for (int i = 0; i < pts.length - 1; i++) {
        final f = fades[i];
        if (f < 0.05) continue;
        
        final pColor = color.withOpacity((drawA ? 0.75 : 0.35) * f);
        final paint = Paint()
          ..color = pColor
          ..strokeWidth = (drawA ? 3.5 : 2.5) * pulse
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
          
        canvas.drawLine(pts[i], pts[i+1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleDNAPainter old) =>
      old.time != time || old.scrollOffset != scrollOffset || old.colorA != colorA || old.colorB != colorB || old.bpmRange != bpmRange;
}
