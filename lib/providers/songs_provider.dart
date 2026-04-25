import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../pages/taste_service.dart';
import '../services/matching_engine.dart';

class SongsProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int _defaultDailyLimit = 25;
  static const List<Song> _sampleSongs = [
    Song(title: 'Blinding Lights', artist: 'The Weeknd', genre: 'Synthwave', mood: 'Energetic', bpm: 118, key: 'C Major', imageUrl: 'https://picsum.photos/400/400?random=1'),
    Song(title: 'Levitating', artist: 'Dua Lipa', genre: 'Disco Pop', mood: 'Happy', bpm: 103, key: 'G Minor', imageUrl: 'https://picsum.photos/400/400?random=2'),
    Song(title: 'As It Was', artist: 'Harry Styles', genre: 'Pop Rock', mood: 'Melancholic', bpm: 174, key: 'F# Minor', imageUrl: 'https://picsum.photos/400/400?random=3'),
    Song(title: 'Anti-Hero', artist: 'Taylor Swift', genre: 'Synth Pop', mood: 'Reflective', bpm: 85, key: 'A Major', imageUrl: 'https://picsum.photos/400/400?random=4'),
    Song(title: 'Calm Down', artist: 'Rema', genre: 'Afrobeats', mood: 'Chill', bpm: 104, key: 'D Major', imageUrl: 'https://picsum.photos/400/400?random=5'),
    Song(title: 'Kill Bill', artist: 'SZA', genre: 'RnB', mood: 'Melancholic', bpm: 89, key: 'A Minor', imageUrl: 'https://picsum.photos/400/400?random=6'),
    Song(title: 'Flowers', artist: 'Miley Cyrus', genre: 'Pop', mood: 'Empowered', bpm: 118, key: 'E Minor', imageUrl: 'https://picsum.photos/400/400?random=7'),
    Song(title: 'Creepin', artist: 'Metro Boomin', genre: 'Hip Hop', mood: 'Dark', bpm: 98, key: 'F Minor', imageUrl: 'https://picsum.photos/400/400?random=8'),
    Song(title: 'Golden Hour', artist: 'JVKE', genre: 'Classical Pop', mood: 'Romantic', bpm: 94, key: 'A Major', imageUrl: 'https://picsum.photos/400/400?random=9'),
    Song(title: 'Starboy', artist: 'The Weeknd', genre: 'RnB', mood: 'Aggressive', bpm: 186, key: 'A Minor', imageUrl: 'https://picsum.photos/400/400?random=10'),
    Song(title: 'Gods Plan', artist: 'Drake', genre: 'Hip Hop', mood: 'Confident', bpm: 77, key: 'A Minor', imageUrl: 'https://picsum.photos/400/400?random=26'),
    Song(title: 'Shape of You', artist: 'Ed Sheeran', genre: 'Pop', mood: 'Groovy', bpm: 96, key: 'C# Minor', imageUrl: 'https://picsum.photos/400/400?random=27'),
    Song(title: 'Humble', artist: 'Kendrick Lamar', genre: 'Hip Hop', mood: 'Aggressive', bpm: 150, key: 'E Minor', imageUrl: 'https://picsum.photos/400/400?random=28'),
    Song(title: 'Bad Romance', artist: 'Lady Gaga', genre: 'Electropop', mood: 'Epic', bpm: 119, key: 'A Minor', imageUrl: 'https://picsum.photos/400/400?random=29'),
    Song(title: 'Stay', artist: 'The Kid LAROI', genre: 'Pop', mood: 'Frantic', bpm: 170, key: 'C# Minor', imageUrl: 'https://picsum.photos/400/400?random=30'),
    Song(title: 'Rolling in the Deep', artist: 'Adele', genre: 'Soul', mood: 'Powerful', bpm: 105, key: 'C Minor', imageUrl: 'https://picsum.photos/400/400?random=31'),
    Song(title: '7 rings', artist: 'Ariana Grande', genre: 'Trap Pop', mood: 'Sassy', bpm: 140, key: 'C# Minor', imageUrl: 'https://picsum.photos/400/400?random=32'),
    Song(title: 'Work', artist: 'Rihanna', genre: 'Dancehall', mood: 'Chill', bpm: 92, key: 'B Minor', imageUrl: 'https://picsum.photos/400/400?random=33'),
    Song(title: 'Single Ladies', artist: 'Beyonce', genre: 'RnB', mood: 'Energetic', bpm: 97, key: 'E Major', imageUrl: 'https://picsum.photos/400/400?random=34'),
    Song(title: 'Sicko Mode', artist: 'Travis Scott', genre: 'Hip Hop', mood: 'Dark', bpm: 155, key: 'G# Minor', imageUrl: 'https://picsum.photos/400/400?random=35'),
    Song(title: 'Old Town Road', artist: 'Lil Nas X', genre: 'Country Rap', mood: 'Happy', bpm: 136, key: 'F# Major', imageUrl: 'https://picsum.photos/400/400?random=36'),
    Song(title: 'Sunflower', artist: 'Post Malone', genre: 'Pop', mood: 'Dreamy', bpm: 90, key: 'D Major', imageUrl: 'https://picsum.photos/400/400?random=37'),
    Song(title: 'Drivers License', artist: 'Olivia Rodrigo', genre: 'Power Pop', mood: 'Sad', bpm: 144, key: 'Bb Major', imageUrl: 'https://picsum.photos/400/400?random=38'),
    Song(title: 'Montero', artist: 'Lil Nas X', genre: 'Pop', mood: 'Confident', bpm: 179, key: 'G Minor', imageUrl: 'https://picsum.photos/400/400?random=39'),
    Song(title: 'Uptown Funk', artist: 'Bruno Mars', genre: 'Funk', mood: 'Happy', bpm: 115, key: 'D Minor', imageUrl: 'https://picsum.photos/400/400?random=40'),
    Song(title: 'Thank U, Next', artist: 'Ariana Grande', genre: 'Pop', mood: 'Reflective', bpm: 107, key: 'Db Major', imageUrl: 'https://picsum.photos/400/400?random=41'),
    Song(title: 'Rockstar', artist: 'Post Malone', genre: 'Trap', mood: 'Dark', bpm: 160, key: 'G Minor', imageUrl: 'https://picsum.photos/400/400?random=42'),
    Song(title: 'Despacito', artist: 'Luis Fonsi', genre: 'Reggaeton', mood: 'Happy', bpm: 89, key: 'D Major', imageUrl: 'https://picsum.photos/400/400?random=43'),
    Song(title: 'Sorry', artist: 'Justin Bieber', genre: 'Dancehall', mood: 'Happy', bpm: 100, key: 'Eb Major', imageUrl: 'https://picsum.photos/400/400?random=44'),
    Song(title: 'Believer', artist: 'Imagine Dragons', genre: 'Pop Rock', mood: 'Powerful', bpm: 125, key: 'Bb Minor', imageUrl: 'https://picsum.photos/400/400?random=45'),
    Song(title: 'Circles', artist: 'Post Malone', genre: 'Soft Rock', mood: 'Chill', bpm: 120, key: 'C Major', imageUrl: 'https://picsum.photos/400/400?random=46'),
    Song(title: 'Someone Like You', artist: 'Adele', genre: 'Soul', mood: 'Sad', bpm: 67, key: 'A Major', imageUrl: 'https://picsum.photos/400/400?random=47'),
    Song(title: 'Happier', artist: 'Marshmello', genre: 'Dance Pop', mood: 'Bittersweet', bpm: 100, key: 'F Major', imageUrl: 'https://picsum.photos/400/400?random=48'),
    Song(title: 'Lucid Dreams', artist: 'Juice WRLD', genre: 'Emo Rap', mood: 'Sad', bpm: 84, key: 'F# Minor', imageUrl: 'https://picsum.photos/400/400?random=49'),
    Song(title: 'Dakiti', artist: 'Bad Bunny', genre: 'Reggaeton', mood: 'Chill', bpm: 110, key: 'E Minor', imageUrl: 'https://picsum.photos/400/400?random=50'),
    Song(title: 'Good 4 U', artist: 'Olivia Rodrigo', genre: 'Pop Punk', mood: 'Angry', bpm: 167, key: 'A Major', imageUrl: 'https://picsum.photos/400/400?random=51'),
    Song(title: 'Stay With Me', artist: 'Sam Smith', genre: 'Gospel Pop', mood: 'Heartbroken', bpm: 84, key: 'C Major', imageUrl: 'https://picsum.photos/400/400?random=52'),
    Song(title: 'Mood', artist: '24kGoldn', genre: 'Pop Rap', mood: 'Happy', bpm: 91, key: 'G Minor', imageUrl: 'https://picsum.photos/400/400?random=53'),
    Song(title: 'WAP', artist: 'Cardi B', genre: 'Hardcore Hip Hop', mood: 'Confident', bpm: 133, key: 'C Minor', imageUrl: 'https://picsum.photos/400/400?random=54'),
    Song(title: 'One Dance', artist: 'Drake', genre: 'Dancehall', mood: 'Chill', bpm: 104, key: 'Bb Minor', imageUrl: 'https://picsum.photos/400/400?random=55'),
    Song(title: 'Royals', artist: 'Lorde', genre: 'Art Pop', mood: 'Reflective', bpm: 85, key: 'D Major', imageUrl: 'https://picsum.photos/400/400?random=56'),
    Song(title: 'Thinking Out Loud', artist: 'Ed Sheeran', genre: 'Soul', mood: 'Romantic', bpm: 79, key: 'D Major', imageUrl: 'https://picsum.photos/400/400?random=57'),
    Song(title: 'Counting Stars', artist: 'OneRepublic', genre: 'Pop Rock', mood: 'Happy', bpm: 122, key: 'C# Minor', imageUrl: 'https://picsum.photos/400/400?random=58'),
    Song(title: 'Cheap Thrills', artist: 'Sia', genre: 'Dancehall', mood: 'Happy', bpm: 90, key: 'F# Minor', imageUrl: 'https://picsum.photos/400/400?random=59'),
    Song(title: 'Dark Horse', artist: 'Katy Perry', genre: 'Trap Pop', mood: 'Dark', bpm: 132, key: 'Bb Minor', imageUrl: 'https://picsum.photos/400/400?random=60'),
    Song(title: 'Timber', artist: 'Pitbull', genre: 'Dance Pop', mood: 'Happy', bpm: 130, key: 'G# Minor', imageUrl: 'https://picsum.photos/400/400?random=61'),
    Song(title: 'Radioactive', artist: 'Imagine Dragons', genre: 'Electrorock', mood: 'Powerful', bpm: 136, key: 'B Minor', imageUrl: 'https://picsum.photos/400/400?random=62'),
    Song(title: 'Wake Me Up', artist: 'Avicii', genre: 'Folktronica', mood: 'Energetic', bpm: 124, key: 'B Minor', imageUrl: 'https://picsum.photos/400/400?random=63'),
    Song(title: 'Stressed Out', artist: 'Twenty One Pilots', genre: 'Alternative Hip Hop', mood: 'Reflective', bpm: 170, key: 'A minor', imageUrl: 'https://picsum.photos/400/400?random=64'),
    Song(title: 'Love Yourself', artist: 'Justin Bieber', genre: 'Pop', mood: 'Calm', bpm: 100, key: 'E Major', imageUrl: 'https://picsum.photos/400/400?random=65'),
    Song(title: 'A Thousand Years', artist: 'Christina Perri', genre: 'Pop', mood: 'Romantic', bpm: 139, key: 'Bb Major', imageUrl: 'https://picsum.photos/400/400?random=66'),
    Song(title: 'All of Me', artist: 'John Legend', genre: 'Soul', mood: 'Romantic', bpm: 63, key: 'Ab Major', imageUrl: 'https://picsum.photos/400/400?random=67'),
    Song(title: 'Hello', artist: 'Adele', genre: 'Soul', mood: 'Sad', bpm: 79, key: 'F Minor', imageUrl: 'https://picsum.photos/400/400?random=68'),
    Song(title: 'Just the Way You Are', artist: 'Bruno Mars', genre: 'Pop', mood: 'Romantic', bpm: 109, key: 'F Major', imageUrl: 'https://picsum.photos/400/400?random=69'),
    Song(title: 'Roar', artist: 'Katy Perry', genre: 'Pop', mood: 'Powerful', bpm: 90, key: 'Bb Major', imageUrl: 'https://picsum.photos/400/400?random=70'),
    Song(title: 'Call Me Maybe', artist: 'Carly Rae Jepsen', genre: 'Pop', mood: 'Happy', bpm: 120, key: 'G Major', imageUrl: 'https://picsum.photos/400/400?random=71'),
    Song(title: 'Can\'t Feel My Face', artist: 'The Weeknd', genre: 'Funk Pop', mood: 'Energetic', bpm: 108, key: 'A Minor', imageUrl: 'https://picsum.photos/400/400?random=72'),
    Song(title: 'Wrecking Ball', artist: 'Miley Cyrus', genre: 'Pop', mood: 'Powerful', bpm: 120, key: 'D Minor', imageUrl: 'https://picsum.photos/400/400?random=73'),
    Song(title: 'Let It Go', artist: 'Idina Menzel', genre: 'Showtune', mood: 'Epic', bpm: 137, key: 'Ab Major', imageUrl: 'https://picsum.photos/400/400?random=74'),
    Song(title: 'Happy', artist: 'Pharrell Williams', genre: 'Soul', mood: 'Happy', bpm: 160, key: 'F Minor', imageUrl: 'https://picsum.photos/400/400?random=75'),
    Song(title: 'Firework', artist: 'Katy Perry', genre: 'Dance Pop', mood: 'Powerful', bpm: 124, key: 'Ab Major', imageUrl: 'https://picsum.photos/400/400?random=76'),
    Song(title: 'Shake It Off', artist: 'Taylor Swift', genre: 'Dance Pop', mood: 'Happy', bpm: 160, key: 'G Major', imageUrl: 'https://picsum.photos/400/400?random=77'),
    Song(title: 'Lose Yourself', artist: 'Eminem', genre: 'Hardcore Hip Hop', mood: 'Aggressive', bpm: 171, key: 'D Minor', imageUrl: 'https://picsum.photos/400/400?random=78'),
    Song(title: 'Rude', artist: 'Magic!', genre: 'Reggae Fusion', mood: 'Happy', bpm: 144, key: 'Db Major', imageUrl: 'https://picsum.photos/400/400?random=79'),
    Song(title: 'Stay', artist: 'Rihanna', genre: 'Pop', mood: 'Sad', bpm: 112, key: 'C Major', imageUrl: 'https://picsum.photos/400/400?random=80'),
    Song(title: 'Chandelier', artist: 'Sia', genre: 'Electropop', mood: 'Powerful', bpm: 117, key: 'Bb Minor', imageUrl: 'https://picsum.photos/400/400?random=81'),
    Song(title: 'See You Again', artist: 'Wiz Khalifa', genre: 'Hip Hop', mood: 'Nostalgic', bpm: 80, key: 'Bb Major', imageUrl: 'https://picsum.photos/400/400?random=82'),
    Song(title: 'Stay High', artist: 'Tove Lo', genre: 'Pop', mood: 'Dreamy', bpm: 120, key: 'C Major', imageUrl: 'https://picsum.photos/400/400?random=83'),
    Song(title: 'Sugar', artist: 'Maroon 5', genre: 'Pop', mood: 'Happy', bpm: 120, key: 'Db Major', imageUrl: 'https://picsum.photos/400/400?random=84'),
    Song(title: 'Titanium', artist: 'David Guetta', genre: 'House', mood: 'Powerful', bpm: 126, key: 'Eb Major', imageUrl: 'https://picsum.photos/400/400?random=85'),
    Song(title: 'Pompeii', artist: 'Bastille', genre: 'Indie Pop', mood: 'Nostalgic', bpm: 127, key: 'A Major', imageUrl: 'https://picsum.photos/400/400?random=86'),
    Song(title: 'Let Her Go', artist: 'Passenger', genre: 'Folk Rock', mood: 'Bittersweet', bpm: 75, key: 'G Major', imageUrl: 'https://picsum.photos/400/400?random=87'),
    Song(title: 'Take Me to Church', artist: 'Hozier', genre: 'Soul', mood: 'Dark', bpm: 129, key: 'E Minor', imageUrl: 'https://picsum.photos/400/400?random=88'),
    Song(title: 'Demons', artist: 'Imagine Dragons', genre: 'Indie Rock', mood: 'Reflective', bpm: 90, key: 'Eb Major', imageUrl: 'https://picsum.photos/400/400?random=89'),
    Song(title: 'Am I Wrong', artist: 'Nico & Vinz', genre: 'Afrobeats', mood: 'Dreamy', bpm: 120, key: 'C Major', imageUrl: 'https://picsum.photos/400/400?random=90'),
    Song(title: 'Fancy', artist: 'Iggy Azalea', genre: 'Hip Hop', mood: 'Sassy', bpm: 95, key: 'C Minor', imageUrl: 'https://picsum.photos/400/400?random=91'),
    Song(title: 'A Sky Full of Stars', artist: 'Coldplay', genre: 'EDM', mood: 'Dreamy', bpm: 125, key: 'Gb Major', imageUrl: 'https://picsum.photos/400/400?random=92'),
    Song(title: 'Summer', artist: 'Calvin Harris', genre: 'EDM', mood: 'Happy', bpm: 128, key: 'E Minor', imageUrl: 'https://picsum.photos/400/400?random=93'),
    Song(title: 'Waves', artist: 'Mr. Probz', genre: 'Deep House', mood: 'Chill', bpm: 120, key: 'G Minor', imageUrl: 'https://picsum.photos/400/400?random=94'),
    Song(title: 'Blame', artist: 'Calvin Harris', genre: 'EDM', mood: 'Energetic', bpm: 128, key: 'C Minor', imageUrl: 'https://picsum.photos/400/400?random=95'),
    Song(title: 'Maps', artist: 'Maroon 5', genre: 'Pop', mood: 'Frantic', bpm: 120, key: 'C# Minor', imageUrl: 'https://picsum.photos/400/400?random=96'),
    Song(title: 'Bang Bang', artist: 'Jessie J', genre: 'Pop', mood: 'Energetic', bpm: 150, key: 'C Minor', imageUrl: 'https://picsum.photos/400/400?random=97'),
    Song(title: 'Problem', artist: 'Ariana Grande', genre: 'Pop', mood: 'Confident', bpm: 103, key: 'C# Minor', imageUrl: 'https://picsum.photos/400/400?random=98'),
    Song(title: 'Black Widow', artist: 'Iggy Azalea', genre: 'Hip Hop', mood: 'Dark', bpm: 130, key: 'D Minor', imageUrl: 'https://picsum.photos/400/400?random=99'),
    Song(title: 'Habits', artist: 'Tove Lo', genre: 'Electropop', mood: 'Melancholic', bpm: 110, key: 'Bb Minor', imageUrl: 'https://picsum.photos/400/400?random=100'),
    Song(title: 'Animals', artist: 'Maroon 5', genre: 'Pop', mood: 'Aggressive', bpm: 190, key: 'E Minor', imageUrl: 'https://picsum.photos/400/400?random=101'),
    Song(title: 'Trumpets', artist: 'Jason Derulo', genre: 'Pop', mood: 'Happy', bpm: 82, key: 'C Minor', imageUrl: 'https://picsum.photos/400/400?random=102'),
    Song(title: 'Don\'t', artist: 'Ed Sheeran', genre: 'RnB', mood: 'Aggressive', bpm: 95, key: 'F Minor', imageUrl: 'https://picsum.photos/400/400?random=103'),
    Song(title: 'Stay With Me', artist: 'Sam Smith', genre: 'Soul', mood: 'Sad', bpm: 84, key: 'C Major', imageUrl: 'https://picsum.photos/400/400?random=104'),
    Song(title: 'Night Changes', artist: 'One Direction', genre: 'Pop', mood: 'Nostalgic', bpm: 120, key: 'Ab Major', imageUrl: 'https://picsum.photos/400/400?random=105'),
    Song(title: 'Thinking Out Loud', artist: 'Ed Sheeran', genre: 'Pop', mood: 'Romantic', bpm: 79, key: 'D Major', imageUrl: 'https://picsum.photos/400/400?random=106'),
    Song(title: 'Blank Space', artist: 'Taylor Swift', genre: 'Electropop', mood: 'Sassy', bpm: 96, key: 'F Major', imageUrl: 'https://picsum.photos/400/400?random=107'),
    Song(title: 'Style', artist: 'Taylor Swift', genre: 'Synth Pop', mood: 'Confident', bpm: 95, key: 'B Minor', imageUrl: 'https://picsum.photos/400/400?random=108'),
    Song(title: 'Uptown Funk', artist: 'Mark Ronson', genre: 'Funk', mood: 'Happy', bpm: 115, key: 'D Minor', imageUrl: 'https://picsum.photos/400/400?random=109'),
    Song(title: 'Take Me to Church', artist: 'Hozier', genre: 'Soul', mood: 'Powerful', bpm: 128, key: 'E Minor', imageUrl: 'https://picsum.photos/400/400?random=110'),
    Song(title: 'Centuries', artist: 'Fall Out Boy', genre: 'Arena Rock', mood: 'Epic', bpm: 176, key: 'E Minor', imageUrl: 'https://picsum.photos/400/400?random=111'),
    Song(title: 'Jealous', artist: 'Nick Jonas', genre: 'RnB', mood: 'Aggressive', bpm: 93, key: 'F Major', imageUrl: 'https://picsum.photos/400/400?random=112'),
    Song(title: 'Burnin\' Up', artist: 'Jessie J', genre: 'Pop', mood: 'Energetic', bpm: 118, key: 'A Minor', imageUrl: 'https://picsum.photos/400/400?random=113'),
    Song(title: 'Cool for the Summer', artist: 'Demi Lovato', genre: 'Pop Rock', mood: 'Confident', bpm: 114, key: 'C Minor', imageUrl: 'https://picsum.photos/400/400?random=114'),
    Song(title: 'Locked Away', artist: 'R. City', genre: 'Reggae Fusion', mood: 'Nostalgic', bpm: 118, key: 'C# Minor', imageUrl: 'https://picsum.photos/400/400?random=115'),
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
      await MatchingEngine().findMatches();
    } catch (e) { debugPrint('MatchingEngine failed: $e'); }
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
