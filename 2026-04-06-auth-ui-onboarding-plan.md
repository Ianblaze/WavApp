# Auth UI & Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the auth visual experience and add a 3-step onboarding flow (photo → genres → artists) that seeds the user's taste profile before they reach `HomePage`.

**Architecture:** A new `AuthStatus.onboarding` state is added to `AuthProvider`. `AuthWrapper` routes to the onboarding flow when the user is authenticated but has not completed onboarding (detected via a `onboardingComplete: bool` flag in their Firestore doc). The landing page gains floating orbs + live counter as purely additive UI on top of the existing card stack — the Sign Up / Log In cards and provider cards are untouched. Each onboarding screen is a dedicated `StatefulWidget`. A shared `OnboardingController` provider manages step state and writes to Firestore atomically on completion.

**Tech Stack:** Flutter, Firebase Auth, Firestore, Firebase Storage, `screenshot` package (for shareable card), Provider, existing Y2K palette + Circular font.

**Prerequisites:** Main auth upgrade plan (`2026-04-04-auth-upgrade-plan.md`) must be complete. The `AuthStatus` enum and `AuthWrapper` switch will be modified here.

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| **Modify** | `lib/auth/auth_wrapper.dart` | Add `onboarding` case → route to `OnboardingFlow` |
| **Modify** | `lib/providers/auth_provider.dart` | Add `AuthStatus.onboarding`; check `onboardingComplete` on login |
| **Modify** | `lib/auth/login_page.dart` | Add floating orbs + live counter to landing layer (behind existing cards) |
| **Create** | `lib/onboarding/onboarding_controller.dart` | `ChangeNotifier` managing step (0–2), selections, Firestore write |
| **Create** | `lib/onboarding/onboarding_flow.dart` | `PageView`-based shell: progress bar, step routing, back handling |
| **Create** | `lib/onboarding/steps/photo_step.dart` | Step 1 — avatar upload, skippable |
| **Create** | `lib/onboarding/steps/genre_step.dart` | Step 2 — pick exactly 5 genres, required |
| **Create** | `lib/onboarding/steps/artist_step.dart` | Step 3 — pick exactly 5 from grid + search, required |
| **Create** | `lib/onboarding/done_screen.dart` | Celebration + shareable profile card |
| **Create** | `lib/onboarding/widgets/progress_worm.dart` | Animated stretchy progress bar |
| **Create** | `lib/onboarding/widgets/genre_chip.dart` | Spring-animated selectable chip |
| **Create** | `lib/onboarding/widgets/artist_card.dart` | Selectable artist card with check mark |
| **Create** | `lib/onboarding/widgets/floating_orbs.dart` | Three animated orbs for landing page |
| **Create** | `lib/onboarding/data/genre_list.dart` | Static list of 12 genre strings |
| **Create** | `lib/onboarding/data/artist_list.dart` | Static list of 10 `ArtistOption` objects |
| **Modify** | `lib/models/user_profile.dart` | Add `genres`, `topArtists`, `onboardingComplete` fields |
| **Modify** | `lib/pages/taste_service.dart` | Seed `tasteProfile` from onboarding data on first write |
| **Modify** | `pubspec.yaml` | Add `screenshot: ^2.3.0` |

---

## Task 1: Add `screenshot` package + update `UserProfile` model

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/models/user_profile.dart`

- [ ] **Step 1: Add `screenshot` to `pubspec.yaml`**

Under `dependencies:`:
```yaml
screenshot: ^2.3.0
```

Run:
```bash
flutter pub get
```
Expected: resolves cleanly.

- [ ] **Step 2: Update `UserProfile` model**

Replace the entire contents of `lib/models/user_profile.dart`:

```dart
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
    final d = doc.data() as Map<String, dynamic>;
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
```

- [ ] **Step 3: Commit**
```bash
git add pubspec.yaml lib/models/user_profile.dart
git commit -m "feat(onboarding): add screenshot package; extend UserProfile with genres/artists/onboardingComplete"
```

---

## Task 2: Add `AuthStatus.onboarding` and detection logic

**Files:**
- Modify: `lib/providers/auth_provider.dart`

The rule: after the user is `authenticated`, check their Firestore doc. If `onboardingComplete != true`, set status to `onboarding`. This means new users (and existing users who never completed it) get routed to the flow.

- [ ] **Step 1: Add `onboarding` to the enum**

In `lib/providers/auth_provider.dart`, change:
```dart
enum AuthStatus { loading, unauthenticated, authenticated, emailUnverified }
```
To:
```dart
enum AuthStatus { loading, unauthenticated, authenticated, emailUnverified, onboarding, passwordUpgradeRequired }
```

Note: `passwordUpgradeRequired` is included here for consistency with the edge cases plan — add it now so both plans don't conflict.

- [ ] **Step 2: Replace `_onAuthStateChanged` with async version that checks Firestore**

```dart
void _onAuthStateChanged(User? user) {
  _currentUser = user;
  if (user == null) {
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    return;
  }
  // Async check — sets status once Firestore responds
  _resolveAuthStatus(user);
}

Future<void> _resolveAuthStatus(User user) async {
  final providerId = user.providerData.isNotEmpty
      ? user.providerData.first.providerId
      : '';
  final isEmailProvider = providerId == 'password';

  if (isEmailProvider && !user.emailVerified) {
    _status = AuthStatus.emailUnverified;
    notifyListeners();
    return;
  }

  // Check password strength flag (edge cases plan)
  if (isEmailProvider) {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      final pwVerified = data?['passwordStrengthVerified'] as bool? ?? true;
      if (!pwVerified) {
        _status = AuthStatus.passwordUpgradeRequired;
        notifyListeners();
        return;
      }
      // Check onboarding
      final onboardingDone = data?['onboardingComplete'] as bool? ?? false;
      if (!onboardingDone) {
        _status = AuthStatus.onboarding;
        notifyListeners();
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AuthProvider: Firestore check error: $e');
    }
  } else {
    // Social / phone login — still check onboarding
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final onboardingDone =
          doc.data()?['onboardingComplete'] as bool? ?? false;
      if (!onboardingDone) {
        _status = AuthStatus.onboarding;
        notifyListeners();
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AuthProvider: onboarding check error: $e');
    }
  }

  _status = AuthStatus.authenticated;
  notifyListeners();
}
```

- [ ] **Step 3: Commit**
```bash
git add lib/providers/auth_provider.dart
git commit -m "feat(onboarding): add AuthStatus.onboarding; detect incomplete onboarding via Firestore on login"
```

---

## Task 3: Route `onboarding` in `AuthWrapper`

**Files:**
- Modify: `lib/auth/auth_wrapper.dart`

- [ ] **Step 1: Add the `onboarding` case to the switch**

In `lib/auth/auth_wrapper.dart`, inside the `Consumer<AuthProvider>` switch, add after `emailUnverified`:

```dart
case AuthStatus.onboarding:
  Future.microtask(() {
    context.read<UserProfileProvider>().startListening(auth.currentUid!);
  });
  return const OnboardingFlow();

case AuthStatus.passwordUpgradeRequired:
  return ReauthPasswordScreen(user: auth.currentUser!);
```

Add imports at top of file:
```dart
import '../onboarding/onboarding_flow.dart';
import 'screens/reauth_password_screen.dart';
```

- [ ] **Step 2: Hot-reload. Verify the switch compiles with no missing case warnings.**

- [ ] **Step 3: Commit**
```bash
git add lib/auth/auth_wrapper.dart
git commit -m "feat(onboarding): AuthWrapper routes AuthStatus.onboarding → OnboardingFlow"
```

---

## Task 4: Static data — genres and artists

**Files:**
- Create: `lib/onboarding/data/genre_list.dart`
- Create: `lib/onboarding/data/artist_list.dart`

- [ ] **Step 1: Create `genre_list.dart`**

```dart
// lib/onboarding/data/genre_list.dart

const List<String> kGenres = [
  'pop',
  'indie',
  'r&b',
  'hip-hop',
  'electronic',
  'jazz',
  'k-pop',
  'soul',
  'metal',
  'afrobeats',
  'latin',
  'classical',
];
```

- [ ] **Step 2: Create `artist_list.dart`**

```dart
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
```

- [ ] **Step 3: Commit**
```bash
git add lib/onboarding/data/
git commit -m "feat(onboarding): static genre and artist data"
```

---

## Task 5: `OnboardingController` — state and Firestore write

**Files:**
- Create: `lib/onboarding/onboarding_controller.dart`

This is the single source of truth for onboarding state. It holds selected genres, selected artists, the photo URL, and current step. On `complete()` it does one atomic Firestore write.

- [ ] **Step 1: Create the file**

```dart
// lib/onboarding/onboarding_controller.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

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
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'photoUrl':           _photoUrl ?? '',
        'genres':             _genres,
        'topArtists':         _artists,
        'onboardingComplete': true,
        'tasteProfile': {
          'topGenre':   _genres.isNotEmpty  ? _genres.first  : '',
          'topArtist':  _artists.isNotEmpty ? _artists.first : '',
          'updatedAt':  FieldValue.serverTimestamp(),
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
```

- [ ] **Step 2: Register `OnboardingController` in `main.dart`**

In `lib/main.dart`, add to `MultiProvider`:
```dart
ChangeNotifierProvider(create: (_) => OnboardingController()),
```

Add import:
```dart
import 'onboarding/onboarding_controller.dart';
```

- [ ] **Step 3: Commit**
```bash
git add lib/onboarding/onboarding_controller.dart lib/main.dart
git commit -m "feat(onboarding): OnboardingController — step state, selections, atomic Firestore write"
```

---

## Task 6: Shared onboarding widgets

**Files:**
- Create: `lib/onboarding/widgets/progress_worm.dart`
- Create: `lib/onboarding/widgets/genre_chip.dart`
- Create: `lib/onboarding/widgets/artist_card.dart`
- Create: `lib/onboarding/widgets/floating_orbs.dart`

- [ ] **Step 1: Create `progress_worm.dart`**

```dart
// lib/onboarding/widgets/progress_worm.dart
import 'package:flutter/material.dart';

class ProgressWorm extends StatelessWidget {
  final int currentStep;   // 0-indexed
  final int totalSteps;

  const ProgressWorm({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / totalSteps;
    return LayoutBuilder(builder: (ctx, constraints) {
      return Stack(
        children: [
          // Track
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Fill — animates width
          AnimatedContainer(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOutCubic,
            height: 5,
            width: constraints.maxWidth * progress,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              // Slight scale on the leading edge for the "worm" feel
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.6),
                  blurRadius: 4,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}
```

- [ ] **Step 2: Create `genre_chip.dart`**

```dart
// lib/onboarding/widgets/genre_chip.dart
import 'package:flutter/material.dart';

// Colour ramp matching Y2K palette — cycles through selections
const _chipColors = [
  Color(0xFFFFB3D9), // hot pink
  Color(0xFFD9B3FF), // lavender
  Color(0xFFB3D9FF), // electric blue
  Color(0xFFFFD4B3), // peach
  Color(0xFFB3FFD9), // mint
];
const _chipTextColors = [
  Color(0xFF4B1528),
  Color(0xFF26215C),
  Color(0xFF042C53),
  Color(0xFF412402),
  Color(0xFF04342C),
];

class GenreChip extends StatefulWidget {
  final String label;
  final bool selected;
  final int selectionIndex; // 0–4 when selected, drives colour
  final VoidCallback onTap;

  const GenreChip({
    super.key,
    required this.label,
    required this.selected,
    required this.selectionIndex,
    required this.onTap,
  });

  @override
  State<GenreChip> createState() => _GenreChipState();
}

class _GenreChipState extends State<GenreChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.86), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.86, end: 1.10), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.10, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _handleTap() {
    _ctrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final idx = widget.selectionIndex.clamp(0, 4);
    final bg   = widget.selected ? _chipColors[idx]     : Colors.white.withOpacity(0.45);
    final text = widget.selected ? _chipTextColors[idx] : const Color(0xFF8A7EA5);
    final border = widget.selected
        ? _chipColors[idx].withOpacity(0)
        : Colors.white.withOpacity(0.3);

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'Circular',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Create `artist_card.dart`**

```dart
// lib/onboarding/widgets/artist_card.dart
import 'package:flutter/material.dart';
import '../data/artist_list.dart';

class ArtistCard extends StatefulWidget {
  final ArtistOption artist;
  final bool selected;
  final VoidCallback onTap;

  const ArtistCard({
    super.key,
    required this.artist,
    required this.selected,
    required this.onTap,
  });

  @override
  State<ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<ArtistCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.90), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.05), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0),  weight: 20),
    ]).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final a = widget.artist;
    final c1 = Color(a.gradientColors[0]);
    final c2 = Color(a.gradientColors[1]);

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: () { _ctrl.forward(from: 0); widget.onTap(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.selected
                ? Colors.white.withOpacity(0.72)
                : Colors.white.withOpacity(0.38),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.selected
                  ? const Color(0xFFFF99CC)
                  : Colors.white.withOpacity(0.25),
              width: widget.selected ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [c1, c2],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  if (widget.selected)
                    Positioned(
                      top: 2, right: 2,
                      child: Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF99CC),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                a.name,
                style: const TextStyle(
                  fontFamily: 'Circular',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A0D26),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                a.genre,
                style: const TextStyle(
                  fontFamily: 'Circular',
                  fontSize: 9,
                  color: Color(0xFF8A7EA5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create `floating_orbs.dart`**

```dart
// lib/onboarding/widgets/floating_orbs.dart
import 'dart:math';
import 'package:flutter/material.dart';

/// Three floating gradient orbs matching the landing reference image.
/// Drop this behind your existing content with a [Stack].
class FloatingOrbs extends StatefulWidget {
  const FloatingOrbs({super.key});

  @override
  State<FloatingOrbs> createState() => _FloatingOrbsState();
}

class _FloatingOrbsState extends State<FloatingOrbs>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  // Orb specs: [color, diameter, baseTop%, baseLeft%, duration-ms, delay-ms]
  static const _orbs = [
    [0xFFFFB3D9, 80.0, 0.20, 0.14, 3200, 0],
    [0xFFC9B3FF, 86.0, 0.17, 0.50, 2800, 400],
    [0xFFA8D4FF, 78.0, 0.22, 0.82, 3600, 200],
  ];

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(_orbs.length, (i) => AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _orbs[i][4] as int),
    )..repeat(reverse: true));

    _anims = List.generate(_orbs.length, (i) => Tween<double>(
      begin: -10.0, end: 10.0,
    ).animate(CurvedAnimation(
      parent: _ctrls[i],
      curve: Curves.easeInOut,
    )));
  }

  @override
  void dispose() {
    for (final c in _ctrls) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      return Stack(
        children: List.generate(_orbs.length, (i) {
          final orb  = _orbs[i];
          final d    = orb[1] as double;
          final topF = orb[2] as double;
          final lftF = orb[3] as double;
          return AnimatedBuilder(
            animation: _anims[i],
            builder: (_, __) => Positioned(
              top:  h * topF + _anims[i].value,
              left: w * lftF - d / 2,
              child: Container(
                width: d, height: d,
                decoration: BoxDecoration(
                  color: Color(orb[0] as int),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      );
    });
  }
}
```

- [ ] **Step 5: Commit**
```bash
git add lib/onboarding/widgets/
git commit -m "feat(onboarding): shared widgets — ProgressWorm, GenreChip, ArtistCard, FloatingOrbs"
```

---

## Task 7: Add floating orbs + live counter to `LoginPage`

**Files:**
- Modify: `lib/auth/login_page.dart`

The existing card stack animation stays completely unchanged. We insert `FloatingOrbs` and a live counter **behind** the existing content using a `Stack`. The orbs sit in a top section above the cards.

- [ ] **Step 1: Add import**

At the top of `lib/auth/login_page.dart`:
```dart
import '../onboarding/widgets/floating_orbs.dart';
```

- [ ] **Step 2: Add `_matchCount` state and ticker to `_LoginPageState`**

In the state class fields:
```dart
int _matchCount = 47;
Timer? _matchTimer;
```

In `initState()`, after existing controller setup:
```dart
// Tick match count every 4 seconds for social proof
_matchTimer = Timer.periodic(const Duration(seconds: 4), (_) {
  if (mounted) {
    setState(() {
      _matchCount = 35 + (DateTime.now().millisecondsSinceEpoch % 40).toInt();
    });
  }
});
```

In `dispose()`:
```dart
_matchTimer?.cancel();
```

Add import at top:
```dart
import 'dart:async';
```

- [ ] **Step 3: Wrap the existing `Scaffold` body in a `Stack` and insert orbs + counter**

Find the outermost `Container` or `Scaffold` `body:` in `LoginPage.build()`. Wrap its content in a `Stack` and prepend these two layers as the first children (behind everything else):

```dart
// Layer 1: Floating orbs (top ~35% of screen)
Positioned(
  top: 0, left: 0, right: 0,
  height: MediaQuery.of(context).size.height * 0.38,
  child: const FloatingOrbs(),
),

// Layer 2: Live match counter
Positioned(
  top: MediaQuery.of(context).size.height * 0.30,
  left: 0, right: 0,
  child: AnimatedSwitcher(
    duration: const Duration(milliseconds: 400),
    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
    child: Container(
      key: ValueKey(_matchCount),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE1F5EE),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF5DCAA5), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7, height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF5DCAA5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$_matchCount matched in the last hour',
              style: const TextStyle(
                fontFamily: 'Circular',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF085041),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
),
```

- [ ] **Step 4: Hot-reload. Verify orbs float behind the cards and counter ticks. Tap Sign Up / Log In — confirm the existing card animation plays exactly as before.**

- [ ] **Step 5: Commit**
```bash
git add lib/auth/login_page.dart
git commit -m "feat(auth): add floating orbs and live match counter to landing — cards untouched"
```

---

## Task 8: `OnboardingFlow` shell

**Files:**
- Create: `lib/onboarding/onboarding_flow.dart`

This is a `PageView`-based container with a back button and the progress worm. It drives `OnboardingController.step`.

- [ ] **Step 1: Create the file**

```dart
// lib/onboarding/onboarding_flow.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'onboarding_controller.dart';
import 'steps/photo_step.dart';
import 'steps/genre_step.dart';
import 'steps/artist_step.dart';
import 'done_screen.dart';
import 'widgets/progress_worm.dart';

// Y2K palette — same as rest of auth
const _bgGradients = [
  [Color(0xFFFFD4FF), Color(0xFFEDD4FF)],  // step 0 — pink/lavender
  [Color(0xFFEDD4FF), Color(0xFFD4E4FF)],  // step 1 — lavender/blue
  [Color(0xFFD4E4FF), Color(0xFFEDD4FF)],  // step 2 — blue/lavender
];

class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OnboardingController(),
      child: const _OnboardingShell(),
    );
  }
}

class _OnboardingShell extends StatefulWidget {
  const _OnboardingShell();

  @override
  State<_OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends State<_OnboardingShell> {
  final _pageCtrl = PageController();

  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  void _goTo(int step) {
    _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<OnboardingController>();

    // Once done, show done screen
    if (ctrl.step >= 3) {
      return const DoneScreen();
    }

    final grads = _bgGradients[ctrl.step.clamp(0, 2)];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: grads,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar: back + progress
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    if (ctrl.step > 0)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFF1A0D26), size: 20),
                        onPressed: () {
                          context.read<OnboardingController>().prevStep();
                          _goTo(ctrl.step - 1);
                        },
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: ProgressWorm(
                        currentStep: ctrl.step,
                        totalSteps: 3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Step label
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'step ${ctrl.step + 1} of 3',
                      style: const TextStyle(
                        fontFamily: 'Circular',
                        fontSize: 11,
                        color: Color(0xFF8A7EA5),
                      ),
                    ),
                    if (ctrl.step == 0)
                      GestureDetector(
                        onTap: () {
                          context.read<OnboardingController>().nextStep();
                          _goTo(1);
                        },
                        child: const Text(
                          'skip',
                          style: TextStyle(
                            fontFamily: 'Circular',
                            fontSize: 11,
                            color: Color(0xFFB69CFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Page content
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(), // controlled programmatically
                  children: [
                    PhotoStep(onNext: () { context.read<OnboardingController>().nextStep(); _goTo(1); }),
                    GenreStep(onNext: () { context.read<OnboardingController>().nextStep(); _goTo(2); }),
                    ArtistStep(onNext: () { context.read<OnboardingController>().nextStep(); }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**
```bash
git add lib/onboarding/onboarding_flow.dart
git commit -m "feat(onboarding): OnboardingFlow shell — PageView, animated background, progress worm, back/skip"
```

---

## Task 9: Step 1 — Photo

**Files:**
- Create: `lib/onboarding/steps/photo_step.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/onboarding/steps/photo_step.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../onboarding_controller.dart';

class PhotoStep extends StatefulWidget {
  final VoidCallback onNext;
  const PhotoStep({super.key, required this.onNext});

  @override
  State<PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends State<PhotoStep> {
  final _picker = ImagePicker();
  bool _uploading = false;
  Uint8List? _previewBytes;

  Future<void> _pick() async {
    final img = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;

    setState(() => _uploading = true);
    final bytes = await img.readAsBytes();
    setState(() => _previewBytes = bytes);

    final ctrl = context.read<OnboardingController>();
    if (kIsWeb) {
      await ctrl.uploadPhoto(bytes);
    } else {
      // ignore: avoid_dynamic_calls
      await ctrl.uploadPhoto(img);
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<OnboardingController>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('add a photo',
              style: TextStyle(fontFamily: 'Circular', fontSize: 26,
                  fontWeight: FontWeight.w800, color: Color(0xFF1A0D26),
                  letterSpacing: -.4)),
          const SizedBox(height: 4),
          const Text('helps others recognise you',
              style: TextStyle(fontFamily: 'Circular', fontSize: 14,
                  color: Color(0xFF8A7EA5))),
          const Spacer(),
          Center(
            child: GestureDetector(
              onTap: _uploading ? null : _pick,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.3),
                  border: Border.all(
                    color: ctrl.photoUrl != null
                        ? const Color(0xFFFF99CC)
                        : Colors.white.withOpacity(0.5),
                    width: ctrl.photoUrl != null ? 2.5 : 1.5,
                    style: ctrl.photoUrl != null
                        ? BorderStyle.solid
                        : BorderStyle.none,
                  ),
                  image: _previewBytes != null
                      ? DecorationImage(
                          image: MemoryImage(_previewBytes!),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: _previewBytes == null
                    ? _uploading
                        ? const CircularProgressIndicator(
                            color: Color(0xFFFF99CC), strokeWidth: 2)
                        : const Icon(Icons.add_a_photo_rounded,
                            size: 36, color: Color(0xFFFF99CC))
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _uploading
                  ? 'uploading...'
                  : ctrl.photoUrl != null
                      ? 'looking good!'
                      : 'tap to upload',
              style: TextStyle(
                fontFamily: 'Circular',
                fontSize: 13,
                color: ctrl.photoUrl != null
                    ? const Color(0xFF5DCAA5)
                    : const Color(0xFF8A7EA5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB3D9),
                foregroundColor: const Color(0xFF4B1528),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
                elevation: 0,
              ),
              onPressed: _uploading ? null : widget.onNext,
              child: Text(
                ctrl.photoUrl != null ? 'next →' : 'skip for now →',
                style: const TextStyle(fontFamily: 'Circular',
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**
```bash
git add lib/onboarding/steps/photo_step.dart
git commit -m "feat(onboarding): PhotoStep — avatar upload with preview, skippable"
```

---

## Task 10: Step 2 — Genres

**Files:**
- Create: `lib/onboarding/steps/genre_step.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/onboarding/steps/genre_step.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../onboarding_controller.dart';
import '../data/genre_list.dart';
import '../widgets/genre_chip.dart';

class GenreStep extends StatelessWidget {
  final VoidCallback onNext;
  const GenreStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<OnboardingController>();
    final selected = ctrl.genres;
    final done = ctrl.genresDone;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('your music taste',
              style: TextStyle(fontFamily: 'Circular', fontSize: 26,
                  fontWeight: FontWeight.w800, color: Color(0xFF1A0D26),
                  letterSpacing: -.4)),
          const SizedBox(height: 4),
          const Text('pick exactly 5 genres to continue',
              style: TextStyle(fontFamily: 'Circular', fontSize: 14,
                  color: Color(0xFF8A7EA5))),
          const SizedBox(height: 16),
          // Selection counter
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: done
                  ? const Color(0xFFE1F5EE)
                  : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: done
                    ? const Color(0xFF5DCAA5)
                    : Colors.white.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              '${selected.length} / 5 selected',
              style: TextStyle(
                fontFamily: 'Circular', fontSize: 12, fontWeight: FontWeight.w700,
                color: done ? const Color(0xFF085041) : const Color(0xFF8A7EA5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Chip grid
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: List.generate(kGenres.length, (i) {
                  final g = kGenres[i];
                  final isSelected = selected.contains(g);
                  final selIdx = isSelected ? selected.indexOf(g) : 0;
                  return GenreChip(
                    label: g,
                    selected: isSelected,
                    selectionIndex: selIdx,
                    onTap: () => context.read<OnboardingController>().toggleGenre(g),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 52,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: done ? 1.0 : 0.4,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB3D9),
                  foregroundColor: const Color(0xFF4B1528),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                  elevation: 0,
                ),
                onPressed: done ? onNext : null,
                child: Text(
                  done ? 'next →' : 'pick ${5 - selected.length} more',
                  style: const TextStyle(fontFamily: 'Circular',
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**
```bash
git add lib/onboarding/steps/genre_step.dart
git commit -m "feat(onboarding): GenreStep — pick 5 genres, spring chip animation, gated continue button"
```

---

## Task 11: Step 3 — Artists

**Files:**
- Create: `lib/onboarding/steps/artist_step.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/onboarding/steps/artist_step.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../onboarding_controller.dart';
import '../data/artist_list.dart';
import '../widgets/artist_card.dart';

class ArtistStep extends StatefulWidget {
  final VoidCallback onNext;
  const ArtistStep({super.key, required this.onNext});

  @override
  State<ArtistStep> createState() => _ArtistStepState();
}

class _ArtistStepState extends State<ArtistStep> {
  String _query = '';

  List<ArtistOption> get _filtered => _query.isEmpty
      ? kArtists
      : kArtists.where((a) =>
          a.name.toLowerCase().contains(_query.toLowerCase()) ||
          a.genre.toLowerCase().contains(_query.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<OnboardingController>();
    final selected = ctrl.artists;
    final done = ctrl.artistsDone;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('favourite artists',
              style: TextStyle(fontFamily: 'Circular', fontSize: 26,
                  fontWeight: FontWeight.w800, color: Color(0xFF1A0D26),
                  letterSpacing: -.4)),
          const SizedBox(height: 4),
          const Text('pick 5 — shapes your matches',
              style: TextStyle(fontFamily: 'Circular', fontSize: 14,
                  color: Color(0xFF8A7EA5))),
          const SizedBox(height: 12),
          // Search box
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.white.withOpacity(0.4), width: 0.5),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontFamily: 'Circular', fontSize: 13,
                  color: Color(0xFF1A0D26)),
              decoration: InputDecoration(
                hintText: 'search artists...',
                hintStyle: const TextStyle(
                    fontFamily: 'Circular', fontSize: 13,
                    color: Color(0xFFB0A0C0)),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF8A7EA5), size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Counter
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: done
                  ? const Color(0xFFE1F5EE)
                  : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: done
                    ? const Color(0xFF5DCAA5)
                    : Colors.white.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              '${selected.length} / 5 selected',
              style: TextStyle(
                fontFamily: 'Circular', fontSize: 12, fontWeight: FontWeight.w700,
                color: done ? const Color(0xFF085041) : const Color(0xFF8A7EA5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Artist grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.05,
              ),
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final a = _filtered[i];
                return ArtistCard(
                  artist: a,
                  selected: selected.contains(a.name),
                  onTap: () =>
                      context.read<OnboardingController>().toggleArtist(a.name),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 52,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: done ? 1.0 : 0.4,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB3D9),
                  foregroundColor: const Color(0xFF4B1528),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                  elevation: 0,
                ),
                onPressed: done ? widget.onNext : null,
                child: Text(
                  done ? "let's go →" : 'pick ${5 - selected.length} more',
                  style: const TextStyle(fontFamily: 'Circular',
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**
```bash
git add lib/onboarding/steps/artist_step.dart
git commit -m "feat(onboarding): ArtistStep — 10-card grid + search, pick 5, gated continue"
```

---

## Task 12: Done screen — celebration + shareable profile card

**Files:**
- Create: `lib/onboarding/done_screen.dart`

The done screen does three things: triggers confetti, writes to Firestore via `OnboardingController.complete()`, and displays a shareable profile card. The `screenshot` package wraps the card widget so the user can save it as an image.

- [ ] **Step 1: Create the file**

```dart
// lib/onboarding/done_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:math';

import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import 'onboarding_controller.dart';

class DoneScreen extends StatefulWidget {
  const DoneScreen({super.key});

  @override
  State<DoneScreen> createState() => _DoneScreenState();
}

class _DoneScreenState extends State<DoneScreen>
    with SingleTickerProviderStateMixin {
  final _screenshotCtrl = ScreenshotController();
  late AnimationController _confettiCtrl;
  bool _saving = false;
  bool _saved = false;
  bool _writeComplete = false;

  static const _confettiColors = [
    Color(0xFFFFB3D9), Color(0xFFD9B3FF), Color(0xFFB3D9FF),
    Color(0xFFFF99CC), Color(0xFFFFD4B3), Color(0xFFB3FFD9),
  ];

  @override
  void initState() {
    super.initState();
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _writeOnboardingData();
  }

  Future<void> _writeOnboardingData() async {
    final ctrl = context.read<OnboardingController>();
    try {
      await ctrl.complete();
      // Notify AuthProvider to re-check status → will route to authenticated
      if (mounted) setState(() => _writeComplete = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save your profile. Please try again.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCard() async {
    setState(() => _saving = true);
    try {
      final Uint8List? bytes = await _screenshotCtrl.capture(pixelRatio: 3.0);
      if (bytes != null) {
        // TODO: use image_gallery_saver or share_plus to save/share
        // For now, show confirmation
        if (mounted) setState(() { _saving = false; _saved = true; });
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goHome() {
    // Re-trigger auth state check — AuthProvider will now see onboardingComplete=true
    // and route to authenticated → HomePage via AuthWrapper
    context.read<AuthProvider>().forceTokenRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<OnboardingController>();
    final profile = context.watch<UserProfileProvider>().profile;
    final username = profile?.username ??
        context.read<AuthProvider>().currentUser?.displayName ??
        'you';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD4FF), Color(0xFFEDD4FF), Color(0xFFD4E4FF)],
          ),
        ),
        child: Stack(
          children: [
            // Confetti layer
            _ConfettiLayer(controller: _confettiCtrl, colors: _confettiColors),

            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const Text("you're all set!",
                        style: TextStyle(fontFamily: 'Circular', fontSize: 28,
                            fontWeight: FontWeight.w800, color: Color(0xFF1A0D26),
                            letterSpacing: -.4)),
                    const SizedBox(height: 4),
                    const Text('your wav card is ready to share',
                        style: TextStyle(fontFamily: 'Circular', fontSize: 14,
                            color: Color(0xFF8A7EA5))),
                    const SizedBox(height: 24),

                    // Shareable card wrapped in Screenshot widget
                    Screenshot(
                      controller: _screenshotCtrl,
                      child: _WavProfileCard(
                        username: username,
                        genres: ctrl.genres,
                        artists: ctrl.artists,
                        photoUrl: ctrl.photoUrl,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Share button
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A0D26),
                          side: const BorderSide(
                              color: Color(0xFFFF99CC), width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25)),
                        ),
                        onPressed: _saving ? null : _saveCard,
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFFF99CC)))
                            : const Icon(Icons.ios_share_rounded, size: 18),
                        label: Text(
                          _saved ? 'saved to photos!' : 'share my wav card',
                          style: const TextStyle(fontFamily: 'Circular',
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Start matching CTA
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB3D9),
                          foregroundColor: const Color(0xFF4B1528),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26)),
                          elevation: 0,
                        ),
                        onPressed: _writeComplete ? _goHome : null,
                        child: const Text('start matching →',
                            style: TextStyle(fontFamily: 'Circular',
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile card widget ───────────────────────────────────────────────────────
class _WavProfileCard extends StatelessWidget {
  final String username;
  final List<String> genres;
  final List<String> artists;
  final String? photoUrl;

  const _WavProfileCard({
    required this.username,
    required this.genres,
    required this.artists,
    this.photoUrl,
  });

  static const _chipColors = [
    Color(0xFFFFB3D9), Color(0xFFD9B3FF),
    Color(0xFFB3D9FF), Color(0xFFFFD4B3), Color(0xFFB3FFD9),
  ];
  static const _chipText = [
    Color(0xFF4B1528), Color(0xFF26215C),
    Color(0xFF042C53), Color(0xFF412402), Color(0xFF04342C),
  ];
  static const _artistGrads = [
    [Color(0xFFFFB3D9), Color(0xFFFF6FE8)],
    [Color(0xFFD9B3FF), Color(0xFFB69CFF)],
    [Color(0xFFB3D9FF), Color(0xFF7BA7FF)],
    [Color(0xFFFFD4B3), Color(0xFFFF9966)],
    [Color(0xFFB3FFD9), Color(0xFF5DCAA5)],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0D26), Color(0xFF2D1642)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB3D9), Color(0xFFD9B3FF)],
                  ),
                  image: photoUrl != null && photoUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(photoUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: photoUrl == null || photoUrl!.isEmpty
                    ? const Icon(Icons.person_rounded,
                        color: Colors.white, size: 24)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@$username',
                        style: const TextStyle(fontFamily: 'Circular',
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const Text('wav · music matchmaking',
                        style: TextStyle(fontFamily: 'Circular', fontSize: 10,
                            color: Color(0xFF8A7EA5))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFF99CC).withOpacity(0.4)),
                ),
                child: const Text('wav',
                    style: TextStyle(fontFamily: 'Circular', fontSize: 10,
                        color: Color(0xFFFF99CC), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 0.5, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 14),

          // Genres
          const Text('genres',
              style: TextStyle(fontFamily: 'Circular', fontSize: 10,
                  color: Color(0xFF8A7EA5), letterSpacing: .06,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5, runSpacing: 5,
            children: List.generate(genres.length, (i) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _chipColors[i % 5].withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _chipColors[i % 5].withOpacity(0.35)),
              ),
              child: Text(genres[i],
                  style: TextStyle(fontFamily: 'Circular', fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _chipColors[i % 5])),
            )),
          ),
          const SizedBox(height: 14),
          Container(height: 0.5, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 14),

          // Artists
          const Text('top artists',
              style: TextStyle(fontFamily: 'Circular', fontSize: 10,
                  color: Color(0xFF8A7EA5), letterSpacing: .06,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...List.generate(artists.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: _artistGrads[i % 5],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(artists[i],
                    style: const TextStyle(fontFamily: 'Circular',
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: Color(0xFFE0D0F0))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ── Confetti layer ────────────────────────────────────────────────────────────
class _ConfettiLayer extends StatelessWidget {
  final AnimationController controller;
  final List<Color> colors;

  const _ConfettiLayer({required this.controller, required this.colors});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (ctx, _) {
        final rng = Random(42);
        return CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
              progress: controller.value, rng: rng, colors: colors),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final Random rng;
  final List<Color> colors;
  static const _count = 28;

  _ConfettiPainter({
    required this.progress,
    required this.rng,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (int i = 0; i < _count; i++) {
      final seed = i * 137.508;
      final startX = (sin(seed) * 0.5 + 0.5) * size.width;
      final delay = (i / _count);
      final t = ((progress - delay) % 1.0 + 1.0) % 1.0;
      final y = t * (size.height + 40) - 20;
      final x = startX + sin(t * pi * 3 + seed) * 30;
      final rotation = t * pi * 4 + seed;
      final color = colors[i % colors.length].withOpacity(1.0 - t * 0.5);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      paint.color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-4, -4, 8, 8), const Radius.circular(1.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
```

- [ ] **Step 2: Commit**
```bash
git add lib/onboarding/done_screen.dart
git commit -m "feat(onboarding): DoneScreen — confetti, shareable profile card, Firestore write, route to Home"
```

---

## Task 13: Seed `TasteService` from onboarding data

**Files:**
- Modify: `lib/pages/taste_service.dart`

When the card stack runs `updateTasteProfileFromSong`, it recalculates `tasteProfile` from `tasteHistory`. But it should also **preserve** the onboarding genres and artists as a base signal. Add a merge step that pulls `genres` and `topArtists` from the user doc and factors them into the profile calculation.

- [ ] **Step 1: Update `_recalculateProfile` to merge onboarding data**

In `lib/pages/taste_service.dart`, at the start of `_recalculateProfile`, add:

```dart
// Pull onboarding seeds into the calculation
final userDoc = await _db.collection('users').doc(uid).get();
final onboardingGenres =
    List<String>.from(userDoc.data()?['genres'] ?? []);
final onboardingArtists =
    List<String>.from(userDoc.data()?['topArtists'] ?? []);

// Treat each onboarding pick as 3 swipe-equivalent votes
for (final g in onboardingGenres) {
  genres.add(g); genres.add(g); genres.add(g);
}
for (final a in onboardingArtists) {
  artists.add(a); artists.add(a); artists.add(a);
}
```

Place this block right after the `List<String> artists = [];` declarations and before the `for (var doc in snap.docs)` loop.

- [ ] **Step 2: Commit**
```bash
git add lib/pages/taste_service.dart
git commit -m "feat(onboarding): seed TasteService profile calculation with onboarding genres and artists (3x weight)"
```

---

## Task 14: Final wiring + smoke test

- [ ] **Step 1: Verify `main.dart` has `SplashScreen` as home (not `HomePage` directly)**

`lib/main.dart` should have:
```dart
home: const SplashScreen(),
```
Not `HomePage()`. The splash navigates to `AuthWrapper` which then routes correctly. If it currently says `HomePage`, change it.

- [ ] **Step 2: Full user journey smoke test — new user**

```
App opens → SplashScreen plays → AuthWrapper shows LoginPage
Tap "Sign Up" card → provider cards appear → tap email
EmailSignUpScreen → fill form → submit
Verify email screen → click link in email → auto-routes
OnboardingFlow appears:
  Step 1 (photo) → skip → step 2
  Step 2 (genres) → select 5 → next → step 3
  Step 3 (artists) → select 5 → let's go
DoneScreen → confetti plays → profile card renders with username/genres/artists
Tap "start matching" → HomePage ✓
```

- [ ] **Step 3: Smoke test — returning user (already onboarded)**

```
Sign out from HomePage → LoginPage
Sign in → AuthProvider checks onboardingComplete=true → routes directly to HomePage ✓
Onboarding does NOT show ✓
```

- [ ] **Step 4: Smoke test — Google/phone sign-in new user**

```
New Google sign-in → onboardingComplete not set → OnboardingFlow appears ✓
Complete onboarding → DoneScreen → HomePage ✓
```

- [ ] **Step 5: Verify floating orbs on landing page**

```
Log out → LoginPage
Orbs float behind the Sign Up / Log In cards ✓
Counter ticks every 4 seconds ✓
Sign Up / Log In card tap animation plays exactly as before ✓
Provider card animation plays exactly as before ✓
```

- [ ] **Step 6: Final commit**
```bash
git add -A
git commit -m "feat(onboarding): complete auth UI + onboarding flow — all screens wired and tested"
```

---

## Summary

| What changed | How |
|---|---|
| Landing page | Floating orbs + live counter added behind existing card stack |
| Sign Up / Log In cards | Untouched |
| Provider cards (Gmail, Google, Phone) | Untouched |
| Auth screens | Already full-screen from auth upgrade plan |
| New: onboarding flow | 3 steps: photo (skippable), genres (required 5), artists (required 5) |
| New: done screen | Confetti + shareable dark profile card + "start matching" CTA |
| Data model | `UserProfile` extended with `genres`, `topArtists`, `onboardingComplete` |
| Routing | `AuthStatus.onboarding` → `OnboardingFlow`; `onboardingComplete=true` skips it on return |
| Taste seeding | Onboarding picks weighted 3x into `TasteService` profile calculation |
