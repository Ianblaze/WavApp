// taste_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TasteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

      // 2. Recalculate profile (null-safe)
      await _recalculateProfile(uid);

    } catch (e) {
      print("TasteService error: $e");
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
  /// STEP 2 — Build tasteProfile from tasteHistory
  /// -----------------------------------------------------------
  Future<void> _recalculateProfile(String uid) async {
    final ref = _db.collection("users").doc(uid).collection("tasteHistory");
    final snap = await ref.get();

    if (snap.docs.isEmpty) return;

    List<String> artists = [];
    List<String> genres = [];
    List<String> moods = [];
    List<String> keys = [];
    List<int> bpms = [];

    for (var doc in snap.docs) {
      final d = doc.data();

      // Null-safe extraction
      final artist = (d["artist"] ?? "").toString().trim();
      final genre = (d["genre"] ?? "").toString().trim();
      final mood = (d["mood"] ?? "").toString().trim();
      final key = (d["key"] ?? "").toString().trim();
      final bpm = d["bpm"] is int ? d["bpm"] : int.tryParse("${d['bpm']}") ?? 0;

      if (artist.isNotEmpty) artists.add(artist);
      if (genre.isNotEmpty) genres.add(genre);
      if (mood.isNotEmpty) moods.add(mood);
      if (key.isNotEmpty) keys.add(key);
      if (bpm > 0) bpms.add(bpm);
    }

    // Safe defaults if user doesn't have enough data
    String topArtist = _mostCommon(artists);
    String topGenre = _mostCommon(genres);
    String topMood = _mostCommon(moods);
    String topKey = _mostCommon(keys);
    String bpmRange = _calculateBpmRange(bpms);

    await _db.collection("users").doc(uid).set({
      "tasteProfile": {
        "topArtist": topArtist,
        "topGenre": topGenre,
        "topMood": topMood,
        "key": topKey,
        "bpmRange": bpmRange,
        "updatedAt": FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  /// -----------------------------------------------------------
  /// HELPERS
  /// -----------------------------------------------------------

  String _mostCommon(List<String> list) {
    if (list.isEmpty) return "";
    final freq = <String, int>{};

    for (final item in list) {
      freq[item] = (freq[item] ?? 0) + 1;
    }

    String best = "";
    int max = 0;

    freq.forEach((k, v) {
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
