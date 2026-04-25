// lib/services/matching_engine.dart
//
// THREE-LAYER MATCHING ENGINE
//   Layer 1: Cosine Similarity on embedding vectors (content-based)
//   Layer 2: Jaccard Similarity on liked songs (collaborative filtering)
//   Layer 3: Gale-Shapley inspired stable matching (mutual ranking)
//
// Modeled after Hinge/Bumble's two-tower architecture.

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class MatchingEngine {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Configuration ────────────────────────────────────────────────
  static const double kMatchThreshold     = 55.0;  // minimum hybrid score %
  static const int    kCandidateLimit      = 50;    // max candidates per run
  static const int    kMaxDailyProposals   = 3;     // Gale-Shapley cap
  static const int    kMaxPendingPerUser   = 5;     // prevent overwhelming
  static const int    kRecentLikeCap       = 50;    // Jaccard: max likes compared
  static const int    kMinSongPoolForJaccard = 20;  // disable Jaccard below this
  static const double kExplorationRatio    = 0.1;   // 10% random candidates

  // ═══════════════════════════════════════════════════════════════
  //  LAYER 1: COSINE SIMILARITY
  // ═══════════════════════════════════════════════════════════════

  /// Compute cosine similarity between two L2-normalized embeddings.
  /// Both vectors MUST be L2-normalized (unit vectors).
  /// Returns a score in [0, 100] where 100 = identical.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

    double dot = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    // Raw cosine: -1 to 1. Map to 0-100.
    return ((dot + 1.0) / 2.0 * 100.0).clamp(0.0, 100.0);
  }

  // ═══════════════════════════════════════════════════════════════
  //  LAYER 2: JACCARD COLLABORATIVE FILTERING
  // ═══════════════════════════════════════════════════════════════

  /// Jaccard similarity on liked song IDs.
  /// Returns value in [0, 1] where 1 = identical taste.
  static double jaccardSimilarity(Set<String> myLikes, Set<String> theirLikes) {
    if (myLikes.isEmpty && theirLikes.isEmpty) return 0.0;

    final intersection = myLikes.intersection(theirLikes);
    final union = myLikes.union(theirLikes);

    if (union.isEmpty) return 0.0;
    return intersection.length / union.length;
  }

  /// Compute the hybrid score blending cosine + Jaccard.
  /// Jaccard weight increases as the user accumulates more likes.
  static double hybridScore({
    required double cosineScore,
    required double jaccardScore,
    required int userLikeCount,
    required int songPoolSize,
  }) {
    // Disable Jaccard for small song pools (everyone shares everything)
    if (songPoolSize < kMinSongPoolForJaccard) {
      return cosineScore;
    }

    // Progressive weighting: 0 likes → 100% cosine, 10+ likes → 60/40
    final jaccardWeight = (userLikeCount / 10.0).clamp(0.0, 0.4);
    final cosineWeight = 1.0 - jaccardWeight;

    return (cosineWeight * cosineScore) + (jaccardWeight * jaccardScore * 100.0);
  }

  // ═══════════════════════════════════════════════════════════════
  //  MAIN MATCHING PIPELINE
  // ═══════════════════════════════════════════════════════════════

  /// Find and create matches for the current user.
  /// Called after each like/swipe.
  Future<void> findMatches() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;

    try {
      // ── Load my data ──────────────────────────────────────────
      final myDoc = await _db.collection('users').doc(me).get();
      final myData = myDoc.data() ?? {};
      final myProfile = (myData['tasteProfile'] as Map<String, dynamic>?) ?? {};
      final myEmbedding = _extractEmbedding(myProfile);

      if (myEmbedding == null) {
        debugPrint('⚠️ MatchingEngine: No embedding for current user');
        return;
      }

      // ── Load my liked songs ─────────────────────────────────
      final myLikesSnap = await _db
          .collection('users').doc(me)
          .collection('likes')
          .orderBy('swipedAt', descending: true)
          .limit(kRecentLikeCap)
          .get();

      final myLikes = myLikesSnap.docs.map((d) => d.id).toSet();

      // ── Get song pool size ─────────────────────────────────
      // Use aggregation for efficiency (count without reading docs)
      int songPoolSize = 0;
      try {
        final songCountSnap = await _db.collection('songs').count().get();
        songPoolSize = songCountSnap.count ?? 0;
      } catch (_) {
        songPoolSize = 5; // fallback to sample count
      }

      // ── Load my existing matches (to skip) ─────────────────
      final myMatchesSnap = await _db
          .collection('users').doc(me)
          .collection('matches')
          .get();

      final existingMatchIds = myMatchesSnap.docs.map((d) => d.id).toSet();

      // ── Check today's proposal count (Gale-Shapley cap) ────
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final proposalCount = myMatchesSnap.docs.where((d) {
        final data = d.data();
        final ts = data['timestamp'] as Timestamp?;
        if (ts == null) return false;
        return data['assignedRole'] == 'initiator' &&
            ts.toDate().isAfter(todayStart);
      }).length;

      if (proposalCount >= kMaxDailyProposals) {
        debugPrint('🛑 MatchingEngine: Daily proposal cap reached ($proposalCount/$kMaxDailyProposals)');
        return;
      }
      final proposalsRemaining = kMaxDailyProposals - proposalCount;

      // ── Fetch candidates ────────────────────────────────────
      final candidates = await _fetchCandidatePool(me, myProfile, existingMatchIds);

      if (candidates.isEmpty) {
        debugPrint('⚠️ MatchingEngine: No candidates found');
        return;
      }

      // ── Score all candidates ────────────────────────────────
      final scored = <_ScoredCandidate>[];

      for (final candidate in candidates) {
        final otherId = candidate.id;
        final otherData = candidate.data() as Map<String, dynamic>? ?? {};
        final otherProfile = (otherData['tasteProfile'] as Map<String, dynamic>?) ?? {};
        final otherEmbedding = _extractEmbedding(otherProfile);

        if (otherEmbedding == null) continue;

        // Layer 1: Cosine similarity
        final cosine = cosineSimilarity(myEmbedding, otherEmbedding);

        // Layer 2: Jaccard on liked songs
        double jaccard = 0.0;
        Set<String> sharedSongIds = {};
        if (songPoolSize >= kMinSongPoolForJaccard && myLikes.isNotEmpty) {
          final otherLikesSnap = await _db
              .collection('users').doc(otherId)
              .collection('likes')
              .orderBy('swipedAt', descending: true)
              .limit(kRecentLikeCap)
              .get();

          final otherLikes = otherLikesSnap.docs.map((d) => d.id).toSet();
          jaccard = jaccardSimilarity(myLikes, otherLikes);
          sharedSongIds = myLikes.intersection(otherLikes);
        }

        // Hybrid score
        final score = hybridScore(
          cosineScore: cosine,
          jaccardScore: jaccard,
          userLikeCount: myLikes.length,
          songPoolSize: songPoolSize,
        );

        if (score < kMatchThreshold) continue;

        // Compute shared signals
        final sharedSignals = _computeSharedSignals(
          myData, otherData, sharedSongIds,
        );

        scored.add(_ScoredCandidate(
          userId: otherId,
          score: score,
          cosineScore: cosine,
          jaccardScore: jaccard * 100,
          sharedGenres: sharedSignals['genres'] as List<String>,
          sharedArtists: sharedSignals['artists'] as List<String>,
          sharedSongs: sharedSignals['songs'] as List<String>,
        ));
      }

      // ── Layer 3: Gale-Shapley lite — rank by score, cap proposals ──
      scored.sort((a, b) => b.score.compareTo(a.score));

      int sent = 0;
      for (final candidate in scored) {
        if (sent >= proposalsRemaining) break;

        // Check if candidate has too many pending matches
        final pendingCount = await _countPendingMatches(candidate.userId);
        if (pendingCount >= kMaxPendingPerUser) {
          debugPrint('⏩ Skipping ${candidate.userId} — $pendingCount pending matches');
          continue;
        }

        // Deterministic initiator: lower UID sends
        final shouldInitiate = me.compareTo(candidate.userId) < 0;
        if (!shouldInitiate) {
          // The other user's client will initiate when they swipe
          // But still count as a "seen" match to avoid re-processing
          continue;
        }

        await _createMatchDocuments(
          me: me,
          other: candidate.userId,
          score: candidate.score,
          sharedGenres: candidate.sharedGenres,
          sharedArtists: candidate.sharedArtists,
          sharedSongs: candidate.sharedSongs,
        );

        sent++;
        debugPrint('✅ Match sent to ${candidate.userId} — '
            'score: ${candidate.score.toStringAsFixed(1)}% '
            '(cosine: ${candidate.cosineScore.toStringAsFixed(1)}, '
            'jaccard: ${candidate.jaccardScore.toStringAsFixed(1)})');
      }

      debugPrint('🏁 MatchingEngine: sent $sent matches, '
          '${scored.length} candidates above threshold');
    } catch (e, st) {
      debugPrint('❌ MatchingEngine error: $e\n$st');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  CANDIDATE POOL (pre-filtering)
  // ═══════════════════════════════════════════════════════════════

  Future<List<DocumentSnapshot>> _fetchCandidatePool(
    String myUid,
    Map<String, dynamic> myProfile,
    Set<String> existingMatchIds,
  ) async {
    final candidates = <DocumentSnapshot>[];

    // ── Genre-filtered candidates (90%) ─────────────────────────
    final topGenre = (myProfile['topGenre'] ?? '').toString();

    // Also try genre histogram for broader matching
    final genreHist = (myProfile['genreHistogram'] as Map<String, dynamic>?) ?? {};
    final topGenres = <String>[];
    if (topGenre.isNotEmpty) topGenres.add(topGenre);
    // Add top-3 genres from histogram
    if (genreHist.isNotEmpty) {
      final sorted = genreHist.entries.toList()
        ..sort((a, b) => (b.value as num).compareTo(a.value as num));
      for (final entry in sorted.take(3)) {
        if (!topGenres.contains(entry.key)) topGenres.add(entry.key);
      }
    }

    if (topGenres.isNotEmpty) {
      // Firestore whereIn supports up to 30 values
      final genreQuery = topGenres.take(10).toList();
      try {
        final snap = await _db.collection('users')
            .where('tasteProfile.topGenre', whereIn: genreQuery)
            .limit(kCandidateLimit)
            .get();

        for (final doc in snap.docs) {
          if (doc.id != myUid && !existingMatchIds.contains(doc.id)) {
            candidates.add(doc);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Genre filter query failed: $e');
      }
    }

    // ── Random exploration candidates (10%) ─────────────────────
    // Fetch a few random users to escape the genre bubble
    final explorationCount = (kCandidateLimit * kExplorationRatio).ceil();
    final existingIds = {myUid, ...existingMatchIds, ...candidates.map((d) => d.id)};

    try {
      // Use a random document ID as a cursor for pseudo-random sampling
      final randomKey = _db.collection('users').doc().id;
      final randomSnap = await _db.collection('users')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: randomKey)
          .limit(explorationCount * 2) // fetch extra in case of overlap
          .get();

      for (final doc in randomSnap.docs) {
        if (!existingIds.contains(doc.id) && candidates.length < kCandidateLimit) {
          candidates.add(doc);
          existingIds.add(doc.id);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Exploration query failed: $e');
    }

    // ── Fallback for very small user pools ──────────────────────
    if (candidates.length < 10) {
      try {
        final allSnap = await _db.collection('users')
            .limit(kCandidateLimit)
            .get();

        for (final doc in allSnap.docs) {
          if (!existingIds.contains(doc.id)) {
            candidates.add(doc);
            existingIds.add(doc.id);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Fallback query failed: $e');
      }
    }

    return candidates;
  }

  // ═══════════════════════════════════════════════════════════════
  //  SHARED SIGNALS
  // ═══════════════════════════════════════════════════════════════

  Map<String, List<String>> _computeSharedSignals(
    Map<String, dynamic> myData,
    Map<String, dynamic> otherData,
    Set<String> sharedSongIds,
  ) {
    // Shared genres
    final myGenres = List<String>.from(myData['genres'] ?? []);
    final otherGenres = List<String>.from(otherData['genres'] ?? []);
    final sharedGenres = myGenres
        .where((g) => otherGenres.contains(g))
        .take(3)
        .toList();

    // Shared artists
    final myArtists = List<String>.from(myData['topArtists'] ?? []);
    final otherArtists = List<String>.from(otherData['topArtists'] ?? []);
    final sharedArtists = myArtists
        .where((a) => otherArtists.contains(a))
        .take(3)
        .toList();

    // Shared songs (convert IDs back to readable titles)
    final sharedSongs = sharedSongIds
        .map((id) => id.replaceAll('_', ' '))
        .take(3)
        .toList();

    return {
      'genres': sharedGenres,
      'artists': sharedArtists,
      'songs': sharedSongs,
    };
  }

  // ═══════════════════════════════════════════════════════════════
  //  MATCH DOCUMENT CREATION
  // ═══════════════════════════════════════════════════════════════

  Future<void> _createMatchDocuments({
    required String me,
    required String other,
    required double score,
    required List<String> sharedGenres,
    required List<String> sharedArtists,
    required List<String> sharedSongs,
  }) async {
    final myRef = _db.collection('users').doc(me)
        .collection('matches').doc(other);
    final otherRef = _db.collection('users').doc(other)
        .collection('matches').doc(me);

    final batch = _db.batch();

    // My outgoing request
    batch.set(myRef, {
      'userId': other,
      'status': 'pending',
      'decision': 'connect',
      'assignedRole': 'initiator',
      'reason': '',
      'similarityScore': score,
      'sharedGenres': sharedGenres,
      'sharedArtists': sharedArtists,
      'sharedSongs': sharedSongs,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Their incoming request
    batch.set(otherRef, {
      'userId': me,
      'status': 'incoming',
      'decision': 'none',
      'assignedRole': 'receiver',
      'reason': '',
      'similarityScore': score,
      'sharedGenres': sharedGenres,
      'sharedArtists': sharedArtists,
      'sharedSongs': sharedSongs,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Accept an incoming match request (receiver side).
  Future<void> acceptMatch(String otherUserId) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;

    final myRef = _db.collection('users').doc(me)
        .collection('matches').doc(otherUserId);
    final otherRef = _db.collection('users').doc(otherUserId)
        .collection('matches').doc(me);

    final batch = _db.batch();

    batch.update(myRef, {
      'status': 'connected',
      'decision': 'connect',
      'timestamp': FieldValue.serverTimestamp(),
    });

    batch.update(otherRef, {
      'status': 'connected',
      'decision': 'connect',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    debugPrint('✅ Match accepted: $otherUserId');
  }

  /// Decline/abandon an incoming match request.
  Future<void> declineMatch(String otherUserId, String? reason) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;

    final myRef = _db.collection('users').doc(me)
        .collection('matches').doc(otherUserId);
    final otherRef = _db.collection('users').doc(otherUserId)
        .collection('matches').doc(me);

    final batch = _db.batch();

    batch.update(myRef, {
      'status': 'abandoned',
      'decision': 'abandon',
      'reason': reason ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });

    batch.update(otherRef, {
      'status': 'abandoned',
      'decision': 'abandon_by_other',
      'reason': reason ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    debugPrint('✅ Match declined: $otherUserId');
  }

  // ═══════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════

  List<double>? _extractEmbedding(Map<String, dynamic> profile) {
    final raw = profile['embedding'];
    if (raw == null) return null;
    if (raw is List) {
      return raw.map((e) => (e as num).toDouble()).toList();
    }
    return null;
  }

  Future<int> _countPendingMatches(String userId) async {
    try {
      final snap = await _db
          .collection('users').doc(userId)
          .collection('matches')
          .where('status', isEqualTo: 'incoming')
          .get();
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }
}

/// Internal scored candidate for ranking.
class _ScoredCandidate {
  final String userId;
  final double score;
  final double cosineScore;
  final double jaccardScore;
  final List<String> sharedGenres;
  final List<String> sharedArtists;
  final List<String> sharedSongs;

  const _ScoredCandidate({
    required this.userId,
    required this.score,
    required this.cosineScore,
    required this.jaccardScore,
    required this.sharedGenres,
    required this.sharedArtists,
    required this.sharedSongs,
  });
}
