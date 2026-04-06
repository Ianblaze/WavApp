import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../pages/taste_service.dart';
import '../pages/match_service.dart';

class SongsProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int _defaultDailyLimit = 12;
  static const List<Song> _sampleSongs = [
    Song(title: 'Blinding Lights', artist: 'The Weeknd', genre: 'Synthwave',
        mood: 'Energetic', bpm: 118, key: 'C Major',
        imageUrl: 'https://picsum.photos/400/400?random=1'),
    Song(title: 'Levitating', artist: 'Dua Lipa', genre: 'Disco Pop',
        mood: 'Happy', bpm: 103, key: 'G Minor',
        imageUrl: 'https://picsum.photos/400/400?random=2'),
    Song(title: 'As It Was', artist: 'Harry Styles', genre: 'Pop Rock',
        mood: 'Melancholic', bpm: 174, key: 'F# Minor',
        imageUrl: 'https://picsum.photos/400/400?random=3'),
    Song(title: 'Anti-Hero', artist: 'Taylor Swift', genre: 'Synth Pop',
        mood: 'Reflective', bpm: 85, key: 'A Major',
        imageUrl: 'https://picsum.photos/400/400?random=4'),
    Song(title: 'Calm Down', artist: 'Rema', genre: 'Afrobeats',
        mood: 'Chill', bpm: 104, key: 'D Major',
        imageUrl: 'https://picsum.photos/400/400?random=5'),
  ];

  List<Song> _songs = [];
  int _likesLeft = _defaultDailyLimit;
  Timestamp? _likesLastReset;
  bool _isLoading = true;
  bool _songLoadFailed = false;

  List<Song> get songs => _songs;
  int get likesLeft => _likesLeft;
  bool get isLoading => _isLoading;
  bool get songLoadFailed => _songLoadFailed;

  SongsProvider() {
    _init();
  }

  Future<void> _init() async {
    await Future.wait([loadSongs(), _initLikes()]);
  }

  Future<void> loadSongs() async {
    try {
      final snap = await _db.collection('songs').get();
      if (snap.docs.isEmpty) throw Exception('no songs');
      _songs = snap.docs.map((d) => Song.fromMap(d.data())).toList();
      _songLoadFailed = false;
    } catch (e, st) {
      debugPrint('Error loading songs: $e\n$st');
      _songs = _sampleSongs;
      _songLoadFailed = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _initLikes() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      final savedLeft = (data['dailyLikesLeft'] is int)
          ? data['dailyLikesLeft'] as int
          : _defaultDailyLimit;
      final savedTs = data['likesLastReset'] as Timestamp?;
      if (savedTs == null) {
        await _writeLikes(_defaultDailyLimit, Timestamp.now());
        _likesLeft = _defaultDailyLimit;
        _likesLastReset = Timestamp.now();
      } else {
        final diff = DateTime.now().difference(savedTs.toDate());
        if (diff.inHours >= 24) {
          await _writeLikes(_defaultDailyLimit, Timestamp.fromDate(DateTime.now()));
          _likesLeft = _defaultDailyLimit;
          _likesLastReset = Timestamp.fromDate(DateTime.now());
        } else {
          _likesLeft = savedLeft;
          _likesLastReset = savedTs;
        }
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('Error initialising likes: $e\n$st');
      _likesLeft = _defaultDailyLimit;
      notifyListeners();
    }
  }

  Future<void> _writeLikes(int left, Timestamp ts) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set(
      {'dailyLikesLeft': left, 'likesLastReset': ts},
      SetOptions(merge: true),
    );
  }

  Future<bool> swipeLike(Song song) async {
    if (_likesLeft <= 0) return false;
    _likesLeft--;
    notifyListeners();
    await _writeLikes(_likesLeft, _likesLastReset ?? Timestamp.now());
    await _recordSwipe(liked: true, song: song);
    await _processAfterLike(song);
    return true;
  }

  Future<void> swipeDislike(Song song) async {
    await _recordSwipe(liked: false, song: song);
  }

  Future<void> _recordSwipe({required bool liked, required Song song}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final col = liked ? 'likes' : 'dislikes';
    final docId = '${song.title.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}'
        '_${song.artist.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    await _db
        .collection('users').doc(user.uid)
        .collection(col).doc(docId)
        .set({
          'title': song.title, 'artist': song.artist, 'genre': song.genre,
          'mood': song.mood, 'bpm': song.bpm, 'key': song.key,
          'image': song.imageUrl, 'swipeType': liked ? 'like' : 'dislike',
          'swipedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _processAfterLike(Song song) async {
    try {
      await TasteService().updateTasteProfileFromSong({
        'artist': song.artist, 'genre': song.genre, 'mood': song.mood,
        'bpm': song.bpm, 'key': song.key,
      });
    } catch (e) { debugPrint('TasteService failed: $e'); }
    try {
      await MatchService().processMatchesForUser();
    } catch (e) { debugPrint('MatchService failed: $e'); }
  }

  // Debug only
  Future<void> restoreLikes() async {
    assert(() {
      _likesLeft = _defaultDailyLimit;
      _likesLastReset = Timestamp.now();
      notifyListeners();
      _writeLikes(_likesLeft, _likesLastReset!);
      return true;
    }());
  }
}
