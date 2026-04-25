// lib/services/embedding_service.dart
//
// THE "TOWER" — converts raw user taste data into a 38-dimensional
// embedding vector. Both towers in the two-tower architecture use
// this same function; cosine similarity between the outputs gives
// the content-based compatibility score.
//
// Vector layout (38 dims):
//   [0..11]  Genre weights      (12 genres from kGenres)
//   [12..21] Artist weights     (10 artists from kArtists)
//   [22..27] Mood weights       (6 moods)
//   [28]     Normalized avg BPM (0-1)
//   [29]     BPM spread         (0-1, how eclectic)
//   [30..36] Key weights        (7 chromatic pitch classes)
//   [37]     Era/reserved       (default 0.5)

import 'dart:math' as math;

class EmbeddingService {
  // ── Canonical feature indices ──────────────────────────────────
  // These MUST match the onboarding/song data exactly (lowercase).

  static const List<String> kGenreIndex = [
    'pop', 'indie', 'r&b', 'hip-hop', 'electronic',
    'jazz', 'k-pop', 'soul', 'metal', 'afrobeats',
    'latin', 'classical',
  ];

  static const List<String> kArtistIndex = [
    'the weeknd', 'billie eilish', 'frank ocean', 'sza', 'doja cat',
    'tyler the creator', 'lorde', 'kendrick lamar', 'mitski', 'charli xcx',
  ];

  static const List<String> kMoodIndex = [
    'happy', 'energetic', 'chill', 'melancholic', 'reflective', 'sad',
  ];

  // Chromatic pitch-class mapping (collapse enharmonics + major/minor)
  static const Map<String, int> kKeyMap = {
    'c': 0, 'c major': 0, 'c minor': 0,
    'c#': 1, 'db': 1, 'c# major': 1, 'c# minor': 1, 'db major': 1, 'db minor': 1,
    'd': 2, 'd major': 2, 'd minor': 2,
    'd#': 3, 'eb': 3, 'd# major': 3, 'd# minor': 3, 'eb major': 3, 'eb minor': 3,
    'e': 4, 'e major': 4, 'e minor': 4,
    'f': 5, 'f major': 5, 'f minor': 5,
    'f#': 6, 'gb': 6, 'f# major': 6, 'f# minor': 6, 'gb major': 6, 'gb minor': 6,
    'g': 0, 'g major': 0, 'g minor': 0,       // Map G → 0 (relative to C)
    'g#': 1, 'ab': 1, 'g# major': 1, 'ab major': 1,
    'a': 2, 'a major': 2, 'a minor': 2,
    'a#': 3, 'bb': 3, 'a# major': 3, 'bb major': 3,
    'b': 4, 'b major': 4, 'b minor': 4,
  };

  static const int kGenreDims  = 12;
  static const int kArtistDims = 10;
  static const int kMoodDims   = 6;
  static const int kBpmDims    = 2;  // avg + spread
  static const int kKeyDims    = 7;  // 7 chromatic pitch classes
  static const int kEraDims    = 1;
  static const int kTotalDims  = 38; // 12+10+6+2+7+1

  // ── Per-block weights ──────────────────────────────────────────
  // Equalize influence so each feature block has ~equal pull on cosine.
  static const double _genreWeight  = 1.0;   // 12 × 1.0 = eff 12
  static const double _artistWeight = 1.2;   // 10 × 1.2 = eff 12
  static const double _moodWeight   = 2.0;   //  6 × 2.0 = eff 12
  static const double _bpmWeight    = 6.0;   //  2 × 6.0 = eff 12
  static const double _keyWeight    = 1.7;   //  7 × 1.7 = eff 12
  static const double _eraWeight    = 12.0;  //  1 × 12  = eff 12

  /// Compute a 38-dimensional taste embedding from user data.
  ///
  /// [genreHistogram]  — e.g. {'pop': 0.4, 'indie': 0.3, …}
  /// [artistHistogram] — e.g. {'the weeknd': 0.35, …}
  /// [moodHistogram]   — e.g. {'chill': 0.5, 'happy': 0.3, …}
  /// [avgBpm]          — average BPM of liked songs (0 if unknown)
  /// [bpmSpread]       — std deviation of BPM (0 if unknown)
  /// [keyHistogram]    — e.g. {'c major': 0.3, 'g minor': 0.25, …}
  ///
  /// Returns an L2-normalized vector of length 38.
  static List<double> computeEmbedding({
    required Map<String, double> genreHistogram,
    required Map<String, double> artistHistogram,
    required Map<String, double> moodHistogram,
    required double avgBpm,
    required double bpmSpread,
    required Map<String, double> keyHistogram,
  }) {
    final vec = List<double>.filled(kTotalDims, 0.0);

    // ── Genre block (dims 0–11) ──────────────────────────────────
    for (int i = 0; i < kGenreIndex.length; i++) {
      vec[i] = (genreHistogram[kGenreIndex[i]] ?? 0.0) * _genreWeight;
    }

    // ── Artist block (dims 12–21) ────────────────────────────────
    for (int i = 0; i < kArtistIndex.length; i++) {
      vec[kGenreDims + i] =
          (artistHistogram[kArtistIndex[i]] ?? 0.0) * _artistWeight;
    }

    // ── Mood block (dims 22–27) ──────────────────────────────────
    for (int i = 0; i < kMoodIndex.length; i++) {
      vec[kGenreDims + kArtistDims + i] =
          (moodHistogram[kMoodIndex[i]] ?? 0.0) * _moodWeight;
    }

    // ── BPM block (dims 28–29) ──────────────────────────────────
    // Normalize BPM to [0, 1] using range [60, 200]
    final bpmNorm = avgBpm > 0
        ? ((avgBpm - 60.0) / 140.0).clamp(0.0, 1.0)
        : 0.0;
    // Normalize spread to [0, 1] using max spread of 60
    final spreadNorm = bpmSpread > 0
        ? (bpmSpread / 60.0).clamp(0.0, 1.0)
        : 0.0;
    vec[kGenreDims + kArtistDims + kMoodDims]     = bpmNorm * _bpmWeight;
    vec[kGenreDims + kArtistDims + kMoodDims + 1] = spreadNorm * _bpmWeight;

    // ── Key block (dims 30–36) ──────────────────────────────────
    // Collapse into 7 pitch classes (C, C#/Db, D, D#/Eb, E, F, F#/Gb)
    final keyVec = List<double>.filled(kKeyDims, 0.0);
    keyHistogram.forEach((key, weight) {
      final idx = kKeyMap[key.toLowerCase()];
      if (idx != null && idx < kKeyDims) {
        keyVec[idx] += weight;
      }
    });
    for (int i = 0; i < kKeyDims; i++) {
      vec[kGenreDims + kArtistDims + kMoodDims + kBpmDims + i] =
          keyVec[i] * _keyWeight;
    }

    // ── Era block (dim 37) ──────────────────────────────────────
    vec[kTotalDims - 1] = 0.5 * _eraWeight; // default neutral

    // ── L2 normalization ─────────────────────────────────────────
    return _l2Normalize(vec);
  }

  /// Build embedding from simple onboarding picks only (no swipe history).
  /// Used in OnboardingController.complete() for initial embedding.
  static List<double> computeFromOnboarding({
    required List<String> genres,
    required List<String> artists,
  }) {
    // Distribute equal weight across selected genres
    final genreHist = <String, double>{};
    if (genres.isNotEmpty) {
      final w = 1.0 / genres.length;
      for (final g in genres) {
        genreHist[g.toLowerCase()] = w;
      }
    }

    // Distribute equal weight across selected artists
    final artistHist = <String, double>{};
    if (artists.isNotEmpty) {
      final w = 1.0 / artists.length;
      for (final a in artists) {
        artistHist[a.toLowerCase()] = w;
      }
    }

    // No mood/bpm/key data from onboarding — will be zero dims
    return computeEmbedding(
      genreHistogram: genreHist,
      artistHistogram: artistHist,
      moodHistogram: {},
      avgBpm: 0,
      bpmSpread: 0,
      keyHistogram: {},
    );
  }

  /// L2 normalize a vector. Prevents division by zero with epsilon.
  static List<double> _l2Normalize(List<double> vec) {
    double sumSq = 0.0;
    for (final v in vec) {
      sumSq += v * v;
    }
    final magnitude = math.sqrt(sumSq);
    if (magnitude < 1e-8) return vec; // near-zero vector — return as-is

    return [for (final v in vec) v / magnitude];
  }
}
