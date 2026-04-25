// lib/onboarding/onboarding_controller.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../services/embedding_service.dart';

class OnboardingController extends ChangeNotifier {
  int _step = 0;
  String? _photoUrl;
  final List<String> _genres  = [];
  final List<String> _artists = [];
  bool _saving = false;

  int    get step      => _step;
  String? get photoUrl => _photoUrl;
  List<String> get genres  => List.unmodifiable(_genres);
  List<String> get artists => List.unmodifiable(_artists);
  bool   get saving    => _saving;
  bool   get genresDone  => _genres.length == 5;
  bool   get artistsDone => _artists.length == 5;

  // ── Navigation ──────────────────────────────────────────────────
  void nextStep() {
    _step++;
    notifyListeners();
  }

  void prevStep() {
    if (_step > 0) { _step--; notifyListeners(); }
  }

  // ── Photo ────────────────────────────────────────────────────────
  void setPhotoUrl(String url) {
    _photoUrl = url;
    notifyListeners();
  }

  Future<String?> uploadPhoto(dynamic imageFile) async {
    // imageFile: File on mobile, Uint8List on web
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final ref = FirebaseStorage.instance.ref().child('user_photos/$uid.jpg');
      if (kIsWeb) {
        await ref.putData(
          imageFile as Uint8List,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        await ref.putFile(imageFile as File);
      }
      final url = await ref.getDownloadURL();
      setPhotoUrl(url);
      return url;
    } catch (e) {
      if (kDebugMode) debugPrint('OnboardingController: photo upload error: $e');
      return null;
    }
  }

  // ── Genres ───────────────────────────────────────────────────────
  void toggleGenre(String genre) {
    if (_genres.contains(genre)) {
      _genres.remove(genre);
    } else if (_genres.length < 5) {
      _genres.add(genre);
    }
    notifyListeners();
  }

  // ── Artists ──────────────────────────────────────────────────────
  void toggleArtist(String artist) {
    if (_artists.contains(artist)) {
      _artists.remove(artist);
    } else if (_artists.length < 5) {
      _artists.add(artist);
    }
    notifyListeners();
  }

  // ── Complete — single atomic Firestore write ─────────────────────
  Future<void> complete() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _saving = true;
    notifyListeners();

    try {
      // Compute initial embedding from onboarding selections
      final embedding = EmbeddingService.computeFromOnboarding(
        genres: _genres,
        artists: _artists,
      );

      // Build initial histograms
      final genreHist = <String, double>{};
      if (_genres.isNotEmpty) {
        final w = 1.0 / _genres.length;
        for (final g in _genres) {
          genreHist[g.toLowerCase()] = w;
        }
      }
      final artistHist = <String, double>{};
      if (_artists.isNotEmpty) {
        final w = 1.0 / _artists.length;
        for (final a in _artists) {
          artistHist[a.toLowerCase()] = w;
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'photoUrl':           _photoUrl ?? '',
        'genres':             _genres,
        'topArtists':         _artists,
        'onboardingComplete': true,
        'tasteProfile': {
          'topGenre':        _genres.isNotEmpty  ? _genres.first  : '',
          'topArtist':       _artists.isNotEmpty ? _artists.first : '',
          'genreHistogram':  genreHist,
          'artistHistogram': artistHist,
          'moodHistogram':   <String, double>{},
          'keyHistogram':    <String, double>{},
          'avgBpm':          0.0,
          'bpmSpread':       0.0,
          'embedding':       embedding,
          'updatedAt':       FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('OnboardingController: complete() error: $e');
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
