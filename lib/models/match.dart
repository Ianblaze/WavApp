// lib/models/match.dart
//
// Enriched match model with compatibility data from the matching engine.

import 'package:cloud_firestore/cloud_firestore.dart';

class Match {
  final String userId;
  final String username;
  final String photoUrl;
  final String status;
  final String decision;
  final String reason;
  final String assignedRole;
  final String? chatId;
  final String? docId;

  // ── NEW: Matching engine data ─────────────────────────────────
  final double similarityScore;       // hybrid cosine+jaccard score (0-100)
  final List<String> sharedGenres;    // genres both users share
  final List<String> sharedArtists;   // artists both users share
  final List<String> sharedSongs;     // songs both users liked
  final DateTime? matchedAt;          // when the match was created

  const Match({
    required this.userId,
    required this.username,
    required this.photoUrl,
    required this.status,
    required this.decision,
    required this.reason,
    required this.assignedRole,
    this.chatId,
    this.docId,
    this.similarityScore = 0.0,
    this.sharedGenres = const [],
    this.sharedArtists = const [],
    this.sharedSongs = const [],
    this.matchedAt,
  });

  /// The match quality tier based on hybrid score.
  /// Used for UI differentiation (glow color, badge text).
  String get qualityTier {
    if (similarityScore >= 85) return 'perfect';    // 🔥
    if (similarityScore >= 65) return 'strong';     // ⚡
    return 'potential';                              // 💫
  }

  String get qualityEmoji {
    if (similarityScore >= 85) return '🔥';
    if (similarityScore >= 65) return '⚡';
    return '💫';
  }

  String get qualityLabel {
    if (similarityScore >= 85) return 'Perfect Match';
    if (similarityScore >= 65) return 'Strong Match';
    return 'Potential Match';
  }

  /// Build a human-readable shared taste summary.
  /// e.g. "Pop, R&B · The Weeknd · 3 songs in common"
  String get sharedTasteSummary {
    final parts = <String>[];
    if (sharedGenres.isNotEmpty) {
      parts.add(sharedGenres.take(2).join(', '));
    }
    if (sharedArtists.isNotEmpty) {
      parts.add(sharedArtists.first);
    }
    if (sharedSongs.isNotEmpty) {
      parts.add('${sharedSongs.length} song${sharedSongs.length == 1 ? '' : 's'} in common');
    }
    if (parts.isEmpty) return 'Music taste match';
    return parts.join(' · ');
  }

  /// Factory from Firestore match doc + resolved user data.
  factory Match.fromFirestore({
    required String odocId,
    required Map<String, dynamic> matchData,
    required Map<String, dynamic> otherUserData,
  }) {
    final ts = matchData['timestamp'] as Timestamp?;

    return Match(
      userId: odocId,
      username: (otherUserData['username'] ?? 'Unknown').toString(),
      photoUrl: (otherUserData['photoUrl'] ?? '').toString(),
      status: (matchData['status'] ?? '').toString(),
      decision: (matchData['decision'] ?? '').toString(),
      reason: (matchData['reason'] ?? '').toString(),
      assignedRole: (matchData['assignedRole'] ?? '').toString(),
      chatId: matchData['chatId']?.toString(),
      docId: odocId,
      similarityScore: (matchData['similarityScore'] as num?)?.toDouble() ?? 0.0,
      sharedGenres: List<String>.from(matchData['sharedGenres'] ?? []),
      sharedArtists: List<String>.from(matchData['sharedArtists'] ?? []),
      sharedSongs: List<String>.from(matchData['sharedSongs'] ?? []),
      matchedAt: ts?.toDate(),
    );
  }
}
