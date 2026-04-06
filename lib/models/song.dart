class Song {
  final String title;
  final String artist;
  final String genre;
  final String mood;
  final int bpm;
  final String key;
  final String imageUrl;

  const Song({
    required this.title,
    required this.artist,
    required this.genre,
    required this.mood,
    required this.bpm,
    required this.key,
    required this.imageUrl,
  });

  factory Song.fromMap(Map<String, dynamic> data) => Song(
    title: (data['title'] ?? '').toString(),
    artist: (data['artist'] ?? '').toString(),
    genre: (data['genre'] ?? '').toString(),
    mood: (data['mood'] ?? '').toString(),
    bpm: int.tryParse(data['bpm']?.toString() ?? '0') ?? 0,
    key: (data['key'] ?? '').toString(),
    imageUrl: (data['cover'] ?? '').toString(),
  );

  Map<String, String> toSwipeMap() => {
    'title': title,
    'artist': artist,
    'genre': genre,
    'mood': mood,
    'bpm': bpm.toString(),
    'key': key,
    'image': imageUrl,
  };
}
