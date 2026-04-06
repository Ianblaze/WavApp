import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreSetupService {
  final _db = FirebaseFirestore.instance;

  /// -----------------------------------------------------
  /// RUN THIS ONCE ONLY — Creates system structure & songs
  /// -----------------------------------------------------
  Future<void> initialize() async {
    await _createGlobalCollections();
    await _createSongCollection(); // adds 10 sample songs
    print("🔥 Firestore fully initialized!");
  }

  /// --------------------------------------------------------------------
  /// 1) Create global “system” collections needed for queue + matchmaking
  /// --------------------------------------------------------------------
  Future<void> _createGlobalCollections() async {
    // This ensures the collections exist even if empty
    await _db.collection("matchQueue").doc("_placeholder").set({
      "created": FieldValue.serverTimestamp(),
    });

    await _db.collection("songMetadata").doc("_placeholder").set({
      "created": FieldValue.serverTimestamp(),
    });
  }

  /// --------------------------------------------------------------------
  /// 2) Create taste structure for the currently logged-in user
  /// (You will call this ONLY when a new user signs up)
  /// --------------------------------------------------------------------
  Future<void> createUserTasteStructure(String uid) async {
    final userRef = _db.collection("users").doc(uid);

    await userRef.set({
      "tasteProfile": {
        "topArtist": "",
        "topGenre": "",
        "topMood": "",
        "bpmRange": "",
        "key": "",
        "updatedAt": FieldValue.serverTimestamp(),
      },
      "matchQueueState": {
        "processedCompatible": false,
        "lastProcessedAt": FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));

    // create tasteHistory subcollection root
    await userRef.collection("tasteHistory").doc("_placeholder").set({
      "init": true,
    });

    print("🎵 Taste structure created for user $uid");
  }

  /// --------------------------------------------------------------------
  /// 3) ADD 10 SAMPLE SONGS
  /// --------------------------------------------------------------------
  Future<void> _createSongCollection() async {
    final songs = _db.collection("songs");

    final List<Map<String, dynamic>> sampleSongs = [
      {
        "title": "Blinding Lights",
        "artist": "The Weeknd",
        "genre": "Synthwave",
        "bpm": 170,
        "key": "F Minor",
        "mood": "Energetic",
        "cover": "https://picsum.photos/400?random=1",
        "preview30": "",
        "fullTrack": "",
      },
      {
        "title": "Levitating",
        "artist": "Dua Lipa",
        "genre": "Disco Pop",
        "bpm": 110,
        "key": "G Major",
        "mood": "Happy",
        "cover": "https://picsum.photos/400?random=2",
        "preview30": "",
        "fullTrack": "",
      },
      {
        "title": "Save Your Tears",
        "artist": "The Weeknd",
        "genre": "Synth-Pop",
        "bpm": 118,
        "key": "C Major",
        "mood": "Sad",
        "cover": "https://picsum.photos/400?random=3",
        "preview30": "",
        "fullTrack": "",
      },
      {
        "title": "As It Was",
        "artist": "Harry Styles",
        "genre": "Pop Rock",
        "bpm": 174,
        "key": "D Major",
        "mood": "Melancholic",
        "cover": "https://picsum.photos/400?random=4",
        "preview30": "",
        "fullTrack": "",
      },
      {
        "title": "Calm Down",
        "artist": "Rema",
        "genre": "Afrobeats",
        "bpm": 107,
        "key": "A Minor",
        "mood": "Chill",
        "cover": "https://picsum.photos/400?random=5",
        "preview30": "",
        "fullTrack": "",
      },
      {
        "title": "Heat Waves",
        "artist": "Glass Animals",
        "genre": "Indie Pop",
        "bpm": 141,
        "key": "E Major",
        "mood": "Warm",
        "cover": "https://picsum.photos/400?random=6",
        "preview30": "",
        "fullTrack": "",
      },
      {
        "title": "Industry Baby",
        "artist": "Lil Nas X",
        "genre": "Hip Hop",
        "bpm": 150,
        "key": "G Minor",
        "mood": "Confident",
        "cover": "https://picsum.photos/400?random=7",
        "preview30": "",
        "fullTrack": "",
      },
      {
        "title": "Bad Habit",
        "artist": "Steve Lacy",
        "genre": "Indie R&B",
        "bpm": 169,
        "key": "B Major",
        "mood": "Soft",
        "cover": "https://picsum.photos/400?random=8",
        "preview30": "",
        "fullTrack": "",
      },
      {
        "title": "Anti-Hero",
        "artist": "Taylor Swift",
        "genre": "Synth Pop",
        "bpm": 97,
        "key": "F Major",
        "mood": "Reflective",
        "cover": "https://picsum.photos/400?random=9",
        "preview30": "",
        "fullTrack": "",
      },
      {
        "title": "Die For You",
        "artist": "The Weeknd",
        "genre": "R&B",
        "bpm": 164,
        "key": "D Minor",
        "mood": "Emotional",
        "cover": "https://picsum.photos/400?random=10",
        "preview30": "",
        "fullTrack": "",
      },
    ];

    for (var song in sampleSongs) {
      final docId = song["title"]
          .toString()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), "_")
          .trim();

      await songs.doc(docId).set(song, SetOptions(merge: true));
    }

    print("🎶 Added 10 sample songs.");
  }
}
