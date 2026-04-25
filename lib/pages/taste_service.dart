// lib/pages/taste_service.dart
//
// UPGRADED: Full histogram computation + embedding generation.
// Builds frequency distributions from swipe history with recency decay,
// then calls EmbeddingService to produce the 38-dim taste vector.

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/embedding_service.dart';

class TasteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Recency decay constant: half-life ≈ 23 days
  static const double _decayLambda = 0.03;

  /// -----------------------------------------------------------
  /// 🔥 PUBLIC METHOD — called when user likes/dislikes a song
  /// -----------------------------------------------------------
  Future<void> updateTasteProfileFromSong(Map<String, dynamic> songData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;

    try {
      // 1. Save taste history (null-safe)
      await _addHistory(uid, songData);

      // 2. Recalculate profile with histograms + embedding
      await _recalculateProfile(uid);
    } catch (e) {
      debugPrint("TasteService error: $e");
    }
  }

  /// -----------------------------------------------------------
  /// STEP 1 — Add tasteHistory entry
  /// -----------------------------------------------------------
  Future<void> _addHistory(String uid, Map<String, dynamic> song) async {
    await _db
        .collection("users")
        .doc(uid)
        .collection("tasteHistory")
        .add({
      "artist": (song["artist"] ?? "").toString(),
      "genre": (song["genre"] ?? "").toString(),
      "mood": (song["mood"] ?? "").toString(),
      "bpm": int.tryParse(song["bpm"]?.toString() ?? "") ?? 0,
      "key": (song["key"] ?? "").toString(),
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  /// -----------------------------------------------------------
  /// STEP 2 — Build histograms + embedding from tasteHistory
  /// -----------------------------------------------------------
  Future<void> _recalculateProfile(String uid) async {
    final ref = _db.collection("users").doc(uid).collection("tasteHistory");
    final snap = await ref.get();

    // Pull onboarding seeds
    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final onboardingGenres = List<String>.from(userData['genres'] ?? []);
    final onboardingArtists = List<String>.from(userData['topArtists'] ?? []);

    // ── Weighted frequency counters ────────────────────────────
    final genreWeights  = <String, double>{};
    final artistWeights = <String, double>{};
    final moodWeights   = <String, double>{};
    final keyWeights    = <String, double>{};
    final bpms          = <double>[];

    final now = DateTime.now();

    // Treat each onboarding pick as 3 swipe-equivalent votes (NO decay)
    for (final g in onboardingGenres) {
      final key = g.toLowerCase().trim();
      if (key.isNotEmpty) {
        genreWeights[key] = (genreWeights[key] ?? 0) + 3.0;
      }
    }
    for (final a in onboardingArtists) {
      final key = a.toLowerCase().trim();
      if (key.isNotEmpty) {
        artistWeights[key] = (artistWeights[key] ?? 0) + 3.0;
      }
    }

    // Process swipe history with recency decay
    for (final doc in snap.docs) {
      final d = doc.data();
      final ts = d['timestamp'] as Timestamp?;

      // Compute recency weight: e^(-λ × daysSince)
      double weight = 1.0;
      if (ts != null) {
        final daysSince = now.difference(ts.toDate()).inHours / 24.0;
        weight = math.exp(-_decayLambda * daysSince);
      }

      final artist = (d["artist"] ?? "").toString().trim().toLowerCase();
      final genre  = (d["genre"] ?? "").toString().trim().toLowerCase();
      final mood   = (d["mood"] ?? "").toString().trim().toLowerCase();
      final keyStr = (d["key"] ?? "").toString().trim().toLowerCase();
      final bpm    = d["bpm"] is int
          ? (d["bpm"] as int).toDouble()
          : double.tryParse("${d['bpm']}") ?? 0;

      if (artist.isNotEmpty) {
        artistWeights[artist] = (artistWeights[artist] ?? 0) + weight;
      }
      if (genre.isNotEmpty) {
        genreWeights[genre] = (genreWeights[genre] ?? 0) + weight;
      }
      if (mood.isNotEmpty) {
        moodWeights[mood] = (moodWeights[mood] ?? 0) + weight;
      }
      if (keyStr.isNotEmpty) {
        keyWeights[keyStr] = (keyWeights[keyStr] ?? 0) + weight;
      }
      if (bpm > 0) bpms.add(bpm);
    }

    // ── Normalize to probability distributions ─────────────────
    final genreHist  = _normalize(genreWeights);
    final artistHist = _normalize(artistWeights);
    final moodHist   = _normalize(moodWeights);
    final keyHist    = _normalize(keyWeights);

    // ── BPM statistics ─────────────────────────────────────────
    double avgBpm = 0;
    double bpmSpread = 0;
    if (bpms.isNotEmpty) {
      avgBpm = bpms.reduce((a, b) => a + b) / bpms.length;
      if (bpms.length > 1) {
        final variance = bpms
            .map((b) => (b - avgBpm) * (b - avgBpm))
            .reduce((a, b) => a + b) / bpms.length;
        bpmSpread = math.sqrt(variance);
      }
    }

    // ── Extract top-1 values (backward compat) ─────────────────
    final topGenre  = _topKey(genreHist);
    final topArtist = _topKey(artistHist);
    final topMood   = _topKey(moodHist);
    final topKey    = _topKey(keyHist);
    final bpmRange  = _calculateBpmRange(bpms.map((b) => b.toInt()).toList());

    // ── Compute 38-dim embedding ───────────────────────────────
    final embedding = EmbeddingService.computeEmbedding(
      genreHistogram: genreHist,
      artistHistogram: artistHist,
      moodHistogram: moodHist,
      avgBpm: avgBpm,
      bpmSpread: bpmSpread,
      keyHistogram: keyHist,
    );

    // ── Write to Firestore ─────────────────────────────────────
    await _db.collection("users").doc(uid).set({
      "tasteProfile": {
        // Backward-compatible top-1 fields
        "topArtist": topArtist,
        "topGenre": topGenre,
        "topMood": topMood,
        "key": topKey,
        "bpmRange": bpmRange,
        // NEW: Full histograms
        "genreHistogram": genreHist,
        "artistHistogram": artistHist,
        "moodHistogram": moodHist,
        "keyHistogram": keyHist,
        // NEW: BPM stats
        "avgBpm": avgBpm,
        "bpmSpread": bpmSpread,
        // NEW: 38-dim embedding vector
        "embedding": embedding,
        "updatedAt": FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));

    debugPrint('📊 TasteProfile updated: genre=$topGenre, artist=$topArtist, '
        'mood=$topMood, embedding=${embedding.length}d');
  }

  /// -----------------------------------------------------------
  /// HELPERS
  /// -----------------------------------------------------------

  /// Normalize a weight map to sum to 1.0 (probability distribution).
  Map<String, double> _normalize(Map<String, double> weights) {
    if (weights.isEmpty) return {};
    final total = weights.values.reduce((a, b) => a + b);
    if (total <= 0) return {};
    return weights.map((k, v) => MapEntry(k, v / total));
  }

  /// Get the key with the highest value.
  String _topKey(Map<String, double> hist) {
    if (hist.isEmpty) return "";
    String best = "";
    double max = 0;
    hist.forEach((k, v) {
      if (v > max) {
        best = k;
        max = v;
      }
    });
    return best;
  }

  String _calculateBpmRange(List<int> bpms) {
    if (bpms.isEmpty) return "";
    bpms.sort();
    int avg = bpms.reduce((a, b) => a + b) ~/ bpms.length;
    int lower = (avg ~/ 20) * 20;
    int upper = lower + 20;
    return "$lower-$upper";
  }
}
