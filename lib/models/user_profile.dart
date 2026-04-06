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

  const UserProfile({
    required this.uid,
    required this.username,
    required this.photoUrl,
    required this.email,
    required this.tasteProfile,
    this.genres = const [],
    this.topArtists = const [],
    this.onboardingComplete = false,
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
    return UserProfile(
      uid: doc.id,
      username: d['username'] ?? '',
      photoUrl: d['photoUrl'] ?? '',
      email: d['email'] ?? '',
      tasteProfile: (d['tasteProfile'] as Map<String, dynamic>?) ?? {},
      genres: List<String>.from(d['genres'] ?? []),
      topArtists: List<String>.from(d['topArtists'] ?? []),
      onboardingComplete: d['onboardingComplete'] as bool? ?? false,
    );
  }
}
