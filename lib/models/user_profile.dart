// lib/models/user_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String username;
  final String photoUrl;
  final String email;
  final Map<String, dynamic> tasteProfile;
  final List<String> genres;          // from onboarding step 2
  final List<String> topArtists;      // from onboarding step 3
  final bool onboardingComplete;

  // ── NEW: Embedding data ───────────────────────────────────────
  final List<double> embedding;                // 38-dim taste vector
  final Map<String, double> genreHistogram;    // frequency distribution
  final Map<String, double> moodHistogram;     // frequency distribution
  final Map<String, double> artistHistogram;   // frequency distribution

  const UserProfile({
    required this.uid,
    required this.username,
    required this.photoUrl,
    required this.email,
    required this.tasteProfile,
    this.genres = const [],
    this.topArtists = const [],
    this.onboardingComplete = false,
    this.embedding = const [],
    this.genreHistogram = const {},
    this.moodHistogram = const {},
    this.artistHistogram = const {},
  });

  factory UserProfile.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>?;
    if (d == null) {
      return UserProfile(
          uid: doc.id,
          username: '',
          photoUrl: '',
          email: '',
          tasteProfile: {},
      );
    }

    final tp = (d['tasteProfile'] as Map<String, dynamic>?) ?? {};

    return UserProfile(
      uid: doc.id,
      username: d['username'] ?? '',
      photoUrl: d['photoUrl'] ?? '',
      email: d['email'] ?? '',
      tasteProfile: tp,
      genres: List<String>.from(d['genres'] ?? []),
      topArtists: List<String>.from(d['topArtists'] ?? []),
      onboardingComplete: d['onboardingComplete'] as bool? ?? false,
      embedding: (tp['embedding'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList() ?? [],
      genreHistogram: (tp['genreHistogram'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
      moodHistogram: (tp['moodHistogram'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
      artistHistogram: (tp['artistHistogram'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
    );
  }
}
