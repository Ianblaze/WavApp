// lib/onboarding/data/artist_list.dart

class ArtistOption {
  final String name;
  final String genre;
  final List<int> gradientColors; // two hex ints for gradient

  const ArtistOption({
    required this.name,
    required this.genre,
    required this.gradientColors,
  });
}

const List<ArtistOption> kArtists = [
  ArtistOption(name: 'The Weeknd',       genre: 'r&b / pop',   gradientColors: [0xFFFFB3D9, 0xFFFF6FE8]),
  ArtistOption(name: 'Billie Eilish',    genre: 'alt / pop',   gradientColors: [0xFFD9B3FF, 0xFFB69CFF]),
  ArtistOption(name: 'Frank Ocean',      genre: 'r&b / soul',  gradientColors: [0xFFB3D9FF, 0xFF7BA7FF]),
  ArtistOption(name: 'SZA',             genre: 'r&b',          gradientColors: [0xFFFFD4B3, 0xFFFF9966]),
  ArtistOption(name: 'Doja Cat',         genre: 'pop / rap',   gradientColors: [0xFFB3FFD9, 0xFF5DCAA5]),
  ArtistOption(name: 'Tyler the Creator',genre: 'hip-hop',     gradientColors: [0xFFFFE5B3, 0xFFF9CB42]),
  ArtistOption(name: 'Lorde',            genre: 'indie / pop', gradientColors: [0xFFE5B3FF, 0xFFAFA9EC]),
  ArtistOption(name: 'Kendrick Lamar',   genre: 'hip-hop',     gradientColors: [0xFFFFB3B3, 0xFFE24B4A]),
  ArtistOption(name: 'Mitski',           genre: 'indie',       gradientColors: [0xFFB3E5FF, 0xFF85B7EB]),
  ArtistOption(name: 'Charli XCX',       genre: 'hyperpop',    gradientColors: [0xFFFFB3E5, 0xFFED93B1]),
];
