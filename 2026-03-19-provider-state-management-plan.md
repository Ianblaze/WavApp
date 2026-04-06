# Provider State Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce Provider-based state management across the Wavs Flutter app so pages never touch Firebase directly.

**Architecture:** Five `ChangeNotifier` providers registered at app root via `MultiProvider`. Typed models replace `Map<String, dynamic>`. Services remain as internal implementation details owned by providers. Migration is incremental — app stays runnable after every task.

**Tech Stack:** Flutter, Dart, `provider: ^6.1.0`, Firebase Auth, Cloud Firestore

**Spec:** `docs/2026-03-19-provider-state-management-design.md`

---

## File Map

### Created
- `lib/models/song.dart`
- `lib/models/match.dart`
- `lib/models/message.dart`
- `lib/models/user_profile.dart`
- `lib/providers/auth_provider.dart`
- `lib/providers/songs_provider.dart`
- `lib/providers/match_provider.dart`
- `lib/providers/chat_provider.dart`
- `lib/providers/user_profile_provider.dart`
- `lib/widgets/card_stack.dart` (moved from pages)
- `lib/widgets/match_card.dart` (extracted from match_page.dart)
- `lib/widgets/card_stack_controller.dart`

### Modified
- `pubspec.yaml` — add provider dependency
- `lib/main.dart` — add MultiProvider
- `lib/auth/auth_wrapper.dart` — consume AuthProvider
- `lib/auth/login_page.dart` — consume AuthProvider
- `lib/auth/login_dialogs.dart` — consume AuthProvider
- `lib/pages/home_page.dart` — consume MatchProvider
- `lib/pages/wav_page.dart` — consume SongsProvider
- `lib/pages/match_page.dart` — consume MatchProvider, extract MatchCard
- `lib/pages/chat_page.dart` — consume ChatProvider
- `lib/pages/profile_page.dart` — consume UserProfileProvider
- `lib/pages/splash.dart` — consume AuthProvider

### Moved to lib/services/
- `lib/services/chat_service.dart` (from lib/pages/)
- `lib/services/match_service.dart` (from lib/pages/)
- `lib/services/taste_service.dart` (from lib/pages/)

### Deleted
- `lib/services/match_notification_service.dart`

---

## Task 1: Add provider dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add provider to pubspec.yaml**

Open `pubspec.yaml` and add under `dependencies:`:
```yaml
provider: ^6.1.0
```

- [ ] **Step 2: Install**

```bash
flutter pub get
```
Expected: resolves without conflicts.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add provider dependency"
```

---

## Task 2: Create typed models

**Files:**
- Create: `lib/models/song.dart`
- Create: `lib/models/match.dart`
- Create: `lib/models/message.dart`
- Create: `lib/models/user_profile.dart`

- [ ] **Step 1: Create `lib/models/song.dart`**

```dart
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
```

- [ ] **Step 2: Create `lib/models/match.dart`**

```dart
class Match {
  final String userId;
  final String username;
  final String photoUrl;
  final String status;
  final String decision;
  final String reason;
  final String assignedRole;
  final String? chatId;
  final String? docId;

  const Match({
    required this.userId,
    required this.username,
    required this.photoUrl,
    required this.status,
    required this.decision,
    required this.reason,
    required this.assignedRole,
    this.chatId,
    this.docId,
  });
}
```

- [ ] **Step 3: Create `lib/models/message.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime? timestamp;
  final String status;
  final String? replyToText;
  final String? replyToSenderId;

  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    this.timestamp,
    required this.status,
    this.replyToText,
    this.replyToSenderId,
  });

  factory Message.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: d['senderId'] ?? '',
      text: d['text'] ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate(),
      status: d['status'] ?? 'sent',
      replyToText: d['replyTo'],
      replyToSenderId: d['replyToSender'],
    );
  }
}
```

- [ ] **Step 4: Create `lib/models/user_profile.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String username;
  final String photoUrl;
  final String email;
  final Map<String, dynamic> tasteProfile;

  const UserProfile({
    required this.uid,
    required this.username,
    required this.photoUrl,
    required this.email,
    required this.tasteProfile,
  });

  factory UserProfile.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      username: d['username'] ?? '',
      photoUrl: d['photoUrl'] ?? '',
      email: d['email'] ?? '',
      tasteProfile: (d['tasteProfile'] as Map<String, dynamic>?) ?? {},
    );
  }
}
```

- [ ] **Step 5: Verify models compile**

```bash
flutter analyze lib/models/
```
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/models/
git commit -m "feat: add typed models (Song, Match, Message, UserProfile)"
```

---

## Task 3: Wire MultiProvider in main.dart (empty provider shells)

**Files:**
- Create: `lib/providers/auth_provider.dart`
- Create: `lib/providers/songs_provider.dart`
- Create: `lib/providers/match_provider.dart`
- Create: `lib/providers/chat_provider.dart`
- Create: `lib/providers/user_profile_provider.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Create empty provider shells**

Create each file with just the class skeleton — no logic yet:

`lib/providers/auth_provider.dart`:
```dart
import 'package:flutter/foundation.dart';

enum AuthStatus { loading, unauthenticated, authenticated, emailUnverified }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.loading;
  AuthStatus get status => _status;
}
```

`lib/providers/songs_provider.dart`:
```dart
import 'package:flutter/foundation.dart';
import '../models/song.dart';

class SongsProvider extends ChangeNotifier {
  List<Song> _songs = [];
  List<Song> get songs => _songs;
  int _likesLeft = 12;
  int get likesLeft => _likesLeft;
  bool _isLoading = true;
  bool get isLoading => _isLoading;
}
```

`lib/providers/match_provider.dart`:
```dart
import 'package:flutter/foundation.dart';
import '../models/match.dart';

class MatchProvider extends ChangeNotifier {
  List<Match> _matches = [];
  List<Match> get matches => _matches;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
}
```

`lib/providers/chat_provider.dart`:
```dart
import 'package:flutter/foundation.dart';
import '../models/message.dart';

class ChatProvider extends ChangeNotifier {
  List<Message> _messages = [];
  List<Message> get messages => _messages;
  bool _isSending = false;
  bool get isSending => _isSending;
  Message? _replyingTo;
  Message? get replyingTo => _replyingTo;
}
```

`lib/providers/user_profile_provider.dart`:
```dart
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

class UserProfileProvider extends ChangeNotifier {
  UserProfile? _profile;
  UserProfile? get profile => _profile;
}
```

- [ ] **Step 2: Wire MultiProvider in main.dart**

Add import at top of `lib/main.dart`:
```dart
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/songs_provider.dart';
import 'providers/match_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/user_profile_provider.dart';
```

Wrap `MaterialApp` with `MultiProvider`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SongsProvider()),
        ChangeNotifierProvider(create: (_) => MatchProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "Wav",
        theme: ThemeData.dark(),
        routes: {
          '/chat': (context) {
            final args = ModalRoute.of(context)!.settings.arguments
                as Map<String, dynamic>;
            final currentUid = args['currentUserId'];
            final otherUid = args['otherUserId'];
            final chatId = currentUid.hashCode <= otherUid.hashCode
                ? "${currentUid}_$otherUid"
                : "${otherUid}_$currentUid";
            return ChatPage(
              chatId: chatId,
              otherUserId: args['otherUserId'],
              otherUsername: args['otherUsername'],
              otherPhotoUrl: args['otherPhotoUrl'],
            );
          },
        },
        home: const SplashScreen(),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify app still runs**

```bash
flutter analyze lib/
flutter run
```
Expected: App launches exactly as before. No behaviour changes yet.

- [ ] **Step 4: Commit**

```bash
git add lib/providers/ lib/main.dart
git commit -m "feat: wire MultiProvider with empty provider shells"
```

---

## Task 4: Implement AuthProvider and migrate auth files

**Files:**
- Modify: `lib/providers/auth_provider.dart`
- Modify: `lib/auth/auth_wrapper.dart`
- Modify: `lib/auth/login_page.dart`
- Modify: `lib/auth/login_dialogs.dart`
- Modify: `lib/pages/splash.dart`

- [ ] **Step 1: Implement AuthProvider**

Replace the shell in `lib/providers/auth_provider.dart` with full implementation:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';

enum AuthStatus { loading, unauthenticated, authenticated, emailUnverified }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final PhoneAuthService _phoneAuthService = PhoneAuthService();

  AuthStatus _status = AuthStatus.loading;
  User? _currentUser;

  AuthStatus get status => _status;
  User? get currentUser => _currentUser;
  String? get currentUid => _currentUser?.uid;

  AuthProvider() {
    FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) {
    _currentUser = user;
    if (user == null) {
      _status = AuthStatus.unauthenticated;
    } else {
      final provider = user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : '';
      final isEmailProvider = provider == 'password';
      if (isEmailProvider && !user.emailVerified) {
        _status = AuthStatus.emailUnverified;
      } else {
        _status = AuthStatus.authenticated;
      }
    }
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    await _authService.signInWithGoogle();
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _authService.signInWithEmail(email: email, password: password);
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    await _authService.signUpWithEmail(
        email: email, password: password, name: name);
  }

  Future<void> signInWithPhone({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    await _phoneAuthService.sendOtp(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onError: onError,
    );
  }

  Future<void> verifyOtp({
    required String otp,
    required String verificationId,
    required Function(String error) onError,
  }) async {
    await _phoneAuthService.verifyOtp(
      otp: otp,
      verificationId: verificationId,
      onError: onError,
    );
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<void> sendVerificationEmail() async {
    await _currentUser?.sendEmailVerification();
  }

  Future<void> checkEmailVerification() async {
    await _currentUser?.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed != null) {
      _onAuthStateChanged(refreshed);
    }
  }
}
```

- [ ] **Step 2: Migrate AuthWrapper to consume AuthProvider**

Replace `lib/auth/auth_wrapper.dart` body. The `StreamBuilder<User?>` over `FirebaseAuth.instance.authStateChanges()` is replaced with `Consumer<AuthProvider>`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart';
import '../pages/home_page.dart';
import 'dart:ui' show ImageFilter;

// Keep existing Y2K color constants unchanged

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.loading:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case AuthStatus.unauthenticated:
            return const LoginPage();
          case AuthStatus.emailUnverified:
            return EmailVerificationRequiredScreen(user: auth.currentUser!);
          case AuthStatus.authenticated:
            return const HomePage();
        }
      },
    );
  }
}

// EmailVerificationRequiredScreen — keep existing implementation unchanged.
// Only change: replace direct FirebaseAuth calls:
//   widget.user.reload() → context.read<AuthProvider>().checkEmailVerification()
//   widget.user.sendEmailVerification() → context.read<AuthProvider>().sendVerificationEmail()
//   FirebaseAuth.instance.signOut() → context.read<AuthProvider>().signOut()
```

- [ ] **Step 3: Migrate LoginPage**

In `lib/auth/login_page.dart`, replace:
```dart
final AuthService authService = AuthService();
final PhoneAuthService phoneAuthService = PhoneAuthService();
```
With:
```dart
// Remove — provider handles these
```

Replace `_navigateToHome()` navigation logic — keep it as-is since it uses `Navigator`, which is fine in UI.

Replace `_checkAutoLogin()` — instead of calling `FirebaseAuth.instance.currentUser` directly, read from provider:
```dart
Future<void> _checkAutoLogin() async {
  final prefs = await SharedPreferences.getInstance();
  final rememberMe = prefs.getBool('remember_me') ?? false;
  if (!rememberMe) return;
  final auth = context.read<AuthProvider>();
  if (auth.status == AuthStatus.authenticated) {
    if (mounted) _navigateToHome();
  }
}
```

Pass `context.read<AuthProvider>()` methods into `LoginDialogsHelper` calls instead of `authService` and `phoneAuthService` instances.

- [ ] **Step 4: Update login_dialogs.dart**

In `lib/auth/login_dialogs.dart`, update method signatures to accept `AuthProvider` instead of `AuthService`/`PhoneAuthService`:

```dart
// Change signature from:
static Future<void> showEmailSignUpDialog({
  required AuthService authService,
  ...
})

// To:
static Future<void> showEmailSignUpDialog({
  required AuthProvider authProvider,
  ...
})
```

Replace all `authService.signUpWithEmail(...)` calls with `authProvider.signUpWithEmail(...)`.
Replace all `authService.signInWithEmail(...)` calls with `authProvider.signInWithEmail(...)`.
Replace `handleGoogleSignIn` to use `authProvider.signInWithGoogle()`.
Replace phone auth calls to use `authProvider.signInWithPhone(...)` and `authProvider.verifyOtp(...)`.

- [ ] **Step 5: Migrate splash.dart**

In `lib/pages/splash.dart`, replace any direct `FirebaseAuth.instance` check with:
```dart
// In the navigation decision after splash delay:
final auth = context.read<AuthProvider>();
if (auth.status == AuthStatus.authenticated) {
  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
} else {
  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
}
```

- [ ] **Step 6: Verify**

```bash
flutter analyze lib/auth/ lib/pages/splash.dart lib/providers/auth_provider.dart
flutter run
```
Expected: Login, signup, Google auth, phone auth all work. Email verification screen appears for unverified email users only (not phone/Google users).

- [ ] **Step 7: Commit**

```bash
git add lib/providers/auth_provider.dart lib/auth/ lib/pages/splash.dart
git commit -m "feat: implement AuthProvider, migrate auth files"
```

---

## Task 5: Create CardStackController

**Files:**
- Create: `lib/widgets/card_stack_controller.dart`
- Modify: `lib/pages/card_stack.dart` (in-place, before moving)

- [ ] **Step 1: Create `lib/widgets/card_stack_controller.dart`**

```dart
import 'package:flutter/foundation.dart';

class CardStackController extends ChangeNotifier {
  VoidCallback? _triggerLike;
  VoidCallback? _triggerDislike;

  void attach({
    required VoidCallback triggerLike,
    required VoidCallback triggerDislike,
  }) {
    _triggerLike = triggerLike;
    _triggerDislike = triggerDislike;
  }

  void detach() {
    _triggerLike = null;
    _triggerDislike = null;
  }

  void like() {
    _triggerLike?.call();
  }

  void dislike() {
    _triggerDislike?.call();
  }
}
```

- [ ] **Step 2: Update CardStack to accept controller**

In `lib/pages/card_stack.dart`, add `controller` parameter:

```dart
class CardStack extends StatefulWidget {
  final List<Map<String, String>> songs;
  final Future<void> Function(Map<String, String>)? onLike;
  final Future<void> Function(Map<String, String>)? onDislike;
  final bool canLike;
  final Function(bool isLiking, bool isDisliking)? onSwipeThreshold;
  final CardStackController? controller; // NEW

  const CardStack({
    super.key,
    required this.songs,
    this.onLike,
    this.onDislike,
    this.canLike = true,
    this.onSwipeThreshold,
    this.controller, // NEW
  });
  ...
}
```

In `_CardStackState.initState()`, attach controller:
```dart
@override
void initState() {
  super.initState();
  // existing animation setup...
  widget.controller?.attach(
    triggerLike: triggerLike,
    triggerDislike: triggerDislike,
  );
}

@override
void dispose() {
  widget.controller?.detach();
  _rotationController.dispose();
  super.dispose();
}
```

- [ ] **Step 3: Verify CardStack still compiles**

```bash
flutter analyze lib/pages/card_stack.dart lib/widgets/card_stack_controller.dart
```
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/card_stack_controller.dart lib/pages/card_stack.dart
git commit -m "feat: introduce CardStackController, remove dynamic cast anti-pattern"
```

---

## Task 6: Implement SongsProvider and migrate WavPage

**Files:**
- Modify: `lib/providers/songs_provider.dart`
- Modify: `lib/pages/wav_page.dart`

- [ ] **Step 1: Implement SongsProvider**

Replace the shell with full implementation. Move all logic from `WavPage` into the provider:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/match_service.dart';
import '../services/taste_service.dart';

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
```

- [ ] **Step 2: Migrate WavPage**

Replace all internal state and Firebase logic in `lib/pages/wav_page.dart` with Provider consumption. The page keeps only UI state (`_likeHovered`, `_dislikePressed`, etc.) and the `CardStackController`.

Key changes:
- Remove `songs`, `_loadingSongs`, `_likesLeft`, `_likesShown`, `_user`, all Firestore methods
- Add `final CardStackController _cardController = CardStackController();`
- In `build()`, wrap with `Consumer<SongsProvider>`
- Replace `CardStack(key: _stackKey, ...)` with `CardStack(controller: _cardController, ...)`
- Replace action button `(s as dynamic).triggerLike()` with `_cardController.like()`
- Replace action button `(s as dynamic).triggerDislike()` with `_cardController.dislike()`
- `onLike` callback: call `context.read<SongsProvider>().swipeLike(song)`
- `onDislike` callback: call `context.read<SongsProvider>().swipeDislike(song)`
- `_restoreLikesForTest` button: wrap in `if (kDebugMode)`
- Likes counter reads from `songsProvider.likesLeft`

- [ ] **Step 3: Verify**

```bash
flutter analyze lib/providers/songs_provider.dart lib/pages/wav_page.dart
flutter run
```
Expected: Wav page loads songs, swiping works, daily likes count correctly, debug restore button only visible in debug builds.

- [ ] **Step 4: Commit**

```bash
git add lib/providers/songs_provider.dart lib/pages/wav_page.dart
git commit -m "feat: implement SongsProvider, migrate WavPage"
```

---

## Task 7: Implement MatchProvider and migrate MatchPage + HomePage

**Files:**
- Modify: `lib/providers/match_provider.dart`
- Modify: `lib/pages/match_page.dart`
- Modify: `lib/pages/home_page.dart`
- Delete: `lib/services/match_notification_service.dart`

- [ ] **Step 1: Deduplicate _computeSimilarity in MatchService**

In `lib/pages/match_service.dart` (before moving), make `_computeSimilarity` a public static method:

```dart
static double computeSimilarity(
    Map<String, dynamic> a, Map<String, dynamic> b) {
  int matches = 0;
  final keys = ['topArtist', 'topGenre', 'topMood', 'bpmRange', 'key'];
  for (var k in keys) {
    final va = (a[k] ?? '').toString().toLowerCase();
    final vb = (b[k] ?? '').toString().toLowerCase();
    if (va.isNotEmpty && va == vb) matches++;
  }
  return (matches / keys.length) * 100;
}
```

Remove the private `_computeSimilarity` from `match_notification_service.dart` — it will be deleted anyway.

- [ ] **Step 2: Implement MatchProvider**

Replace shell with full implementation:

```dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/match.dart';
import '../pages/match_dock_popup.dart';
import '../services/match_service.dart';

class MatchProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Match> _matches = [];
  bool _isLoading = false;
  String? _error;

  List<Match> get matches => _matches;
  bool get isLoading => _isLoading;
  String? get error => _error;

  StreamSubscription<QuerySnapshot>? _matchStream;
  StreamSubscription<QuerySnapshot>? _notificationStream;
  BuildContext? _notificationContext;
  final Set<String> _processedMatches = {};

  void startMatchStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _isLoading = true;
    notifyListeners();
    _matchStream = _db
        .collection('users').doc(uid).collection('matches')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snap) async {
      final List<Match> resolved = [];
      for (var doc in snap.docs) {
        final data = doc.data();
        final otherId = doc.id;
        final otherDoc = await _db.collection('users').doc(otherId).get();
        final otherData = otherDoc.data() ?? {};
        resolved.add(Match(
          userId: otherId,
          username: otherData['username'] ?? 'Unknown',
          photoUrl: otherData['photoUrl'] ?? '',
          status: data['status'] ?? '',
          decision: data['decision'] ?? '',
          reason: data['reason'] ?? '',
          assignedRole: data['assignedRole'] ?? '',
          chatId: data['chatId'],
          docId: doc.id,
        ));
      }
      _matches = resolved;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  void startNotificationListener(BuildContext context) {
    _notificationContext = context;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _notificationStream = _db
        .collection('users').doc(uid).collection('matches')
        .where('status', isEqualTo: 'incoming')
        .snapshots()
        .listen((snap) {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final matchId = change.doc.id;
          if (_processedMatches.contains(matchId)) continue;
          _processedMatches.add(matchId);
          _showMatchPopup(change.doc);
        }
      }
    });
  }

  Future<void> _showMatchPopup(DocumentSnapshot matchDoc) async {
    if (_notificationContext == null || !_notificationContext!.mounted) return;
    try {
      final otherId = matchDoc.id;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final otherDoc = await _db.collection('users').doc(otherId).get();
      final otherData = otherDoc.data() ?? {};
      final myDoc = await _db.collection('users').doc(uid).get();
      final myProfile = (myDoc.data()?['tasteProfile'] as Map<String, dynamic>?) ?? {};
      final otherProfile = (otherData['tasteProfile'] as Map<String, dynamic>?) ?? {};
      final similarity = MatchService.computeSimilarity(myProfile, otherProfile);
      if (_notificationContext != null && _notificationContext!.mounted) {
        Navigator.of(_notificationContext!).push(PageRouteBuilder(
          opaque: false,
          barrierDismissible: false,
          pageBuilder: (ctx, anim, _) => MatchDockPopup(
            username: otherData['username'] ?? 'Unknown',
            photoUrl: otherData['photoUrl'] ?? '',
            similarity: similarity.toStringAsFixed(0),
            onConnect: () async {
              Navigator.pop(ctx);
              await acceptMatch(otherId);
            },
            onAbandon: (reason) async {
              Navigator.pop(ctx);
              await declineMatch(otherId, reason);
            },
            onDismiss: () => Navigator.pop(ctx),
          ),
        ));
      }
    } catch (e, st) {
      debugPrint('Error showing match popup: $e\n$st');
    }
  }

  Future<void> acceptMatch(String otherUserId) async {
    await MatchService().acceptIncomingRequest(otherUserId);
  }

  Future<void> declineMatch(String otherUserId, String? reason) async {
    await MatchService().declineIncomingRequest(otherUserId, reason);
  }

  Future<void> sendMatchRequest(String otherUserId) async {
    await MatchService().sendMatchRequest(otherUserId);
  }

  void stopNotificationListener() {
    _notificationStream?.cancel();
    _notificationStream = null;
    _notificationContext = null;
    _processedMatches.clear();
  }

  @override
  void dispose() {
    _matchStream?.cancel();
    _notificationStream?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 3: Migrate MatchPage**

In `lib/pages/match_page.dart`:
- Remove `_matchesStream()` method and `StreamBuilder`
- Add `Consumer<MatchProvider>` at the top of `build()`
- Read matches from `matchProvider.matches`
- Group incoming/outgoing/connected/abandoned from `matchProvider.matches`
- Remove `MatchCard` class from this file (it moves to `lib/widgets/match_card.dart`)

- [ ] **Step 4: Extract MatchCard to lib/widgets/match_card.dart**

Create `lib/widgets/match_card.dart` containing the `MatchCard` widget. Update its chat button `onTap` to remove inline Firestore writes — replace with:
```dart
onTap: () async {
  final chatProvider = context.read<ChatProvider>();
  final chatId = await chatProvider.createOrGetChat(
    currentUserId: currentUserId,
    otherUserId: otherUserId,
  );
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => ChatPage(
      chatId: chatId,
      otherUserId: otherUserId,
      otherUsername: username,
      otherPhotoUrl: photoUrl,
    ),
  ));
},
```

Update `match_page.dart` import to `lib/widgets/match_card.dart`.

- [ ] **Step 5: Migrate HomePage**

In `lib/pages/home_page.dart`:
- Replace `MatchNotificationService().initialize(context)` with `context.read<MatchProvider>().startNotificationListener(context)`
- Replace `MatchNotificationService().dispose()` with `context.read<MatchProvider>().stopNotificationListener()`
- Remove import of `match_notification_service.dart`

- [ ] **Step 6: Delete match_notification_service.dart**

```bash
rm lib/services/match_notification_service.dart
```

- [ ] **Step 7: Verify**

```bash
flutter analyze lib/providers/match_provider.dart lib/pages/match_page.dart lib/pages/home_page.dart lib/widgets/match_card.dart
flutter run
```
Expected: Match page loads matches, incoming popups appear, accept/decline work. No duplicate notifications.

- [ ] **Step 8: Commit**

```bash
git add lib/providers/match_provider.dart lib/pages/match_page.dart lib/pages/home_page.dart lib/widgets/match_card.dart
git rm lib/services/match_notification_service.dart
git commit -m "feat: implement MatchProvider, migrate MatchPage and HomePage, delete MatchNotificationService"
```

---

## Task 8: Implement ChatProvider and migrate ChatPage

**Files:**
- Modify: `lib/providers/chat_provider.dart`
- Modify: `lib/pages/chat_page.dart`

- [ ] **Step 1: Implement ChatProvider**

```dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  List<Message> _messages = [];
  bool _isSending = false;
  Message? _replyingTo;
  String? _activeChatId;
  StreamSubscription<QuerySnapshot>? _messageStream;

  List<Message> get messages => _messages;
  bool get isSending => _isSending;
  Message? get replyingTo => _replyingTo;

  Future<String> createOrGetChat({
    required String currentUserId,
    required String otherUserId,
  }) async {
    return await _chatService.createOrGetChat(otherUserId);
  }

  void openChat(String chatId) {
    _activeChatId = chatId;
    _messages = [];
    notifyListeners();
    _messageStream = _chatService.messagesStream(chatId).listen((snap) {
      _messages = snap.docs.map((d) => Message.fromDoc(d)).toList();
      notifyListeners();
    });
  }

  void closeChat() {
    _messageStream?.cancel();
    _messageStream = null;
    _activeChatId = null;
    _messages = [];
    _replyingTo = null;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (_activeChatId == null || text.trim().isEmpty || _isSending) return;
    _isSending = true;
    final reply = _replyingTo;
    _replyingTo = null;
    notifyListeners();
    try {
      await _chatService.sendMessage(_activeChatId!, text, replyTo: reply);
    } catch (e) {
      debugPrint('sendMessage error: $e');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void setReply(Message message) {
    _replyingTo = message;
    notifyListeners();
  }

  void cancelReply() {
    _replyingTo = null;
    notifyListeners();
  }

  Future<void> markMessagesRead(String otherUserId) async {
    if (_activeChatId == null) return;
    // Delegates to ChatService
    final msgs = await _chatService.unreadMessages(_activeChatId!, otherUserId);
    for (final id in msgs) {
      await _chatService.markMessageRead(_activeChatId!, id);
    }
  }

  @override
  void dispose() {
    _messageStream?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 2: Update ChatService to support new methods**

In `lib/services/chat_service.dart`, add `unreadMessages` helper:
```dart
Future<List<String>> unreadMessages(String chatId, String otherUserId) async {
  final snap = await _db
      .collection('chats').doc(chatId).collection('messages')
      .where('senderId', isEqualTo: otherUserId)
      .where('status', isNotEqualTo: 'read')
      .get();
  return snap.docs.map((d) => d.id).toList();
}
```

Update `sendMessage` to accept optional reply parameter:
```dart
Future<void> sendMessage(String chatId, String text,
    {Message? replyTo}) async {
  final me = FirebaseAuth.instance.currentUser?.uid;
  if (me == null) throw Exception('Not signed in');
  final chatRef = _db.collection('chats').doc(chatId);
  final msgRef = chatRef.collection('messages').doc();
  final batch = _db.batch();
  final data = <String, dynamic>{
    'senderId': me,
    'text': text,
    'timestamp': FieldValue.serverTimestamp(),
    'status': 'sent',
    'readBy': [me],
  };
  if (replyTo != null) {
    data['replyTo'] = replyTo.text;
    data['replyToSender'] = replyTo.senderId;
  }
  batch.set(msgRef, data);
  batch.update(chatRef, {
    'lastMessage': text,
    'lastTimestamp': FieldValue.serverTimestamp(),
  });
  await batch.commit();
}
```

- [ ] **Step 3: Migrate ChatPage**

In `lib/pages/chat_page.dart`:
- Remove `_messageController` stream setup — replaced by provider
- In `initState`, add:
```dart
Future.microtask(() {
  context.read<ChatProvider>().openChat(widget.chatId);
  context.read<ChatProvider>().markMessagesRead(widget.otherUserId);
});
```
- In `dispose`, add:
```dart
context.read<ChatProvider>().closeChat();
```
- Replace `_chatStream()` StreamBuilder with `Consumer<ChatProvider>`
- Messages come from `chatProvider.messages` (already ordered ascending)
- Replace `_replyingTo` local state with `chatProvider.replyingTo`
- Replace `_sendMessage()` with `context.read<ChatProvider>().sendMessage(text)`
- Replace `_replyToMessage()` with `context.read<ChatProvider>().setReply(msg)`
- Replace `_cancelReply()` with `context.read<ChatProvider>().cancelReply()`

- [ ] **Step 4: Verify**

```bash
flutter analyze lib/providers/chat_provider.dart lib/pages/chat_page.dart lib/services/chat_service.dart
flutter run
```
Expected: Chat opens, messages stream in real-time, send works, reply works, read receipts update.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/chat_provider.dart lib/pages/chat_page.dart lib/services/chat_service.dart
git commit -m "feat: implement ChatProvider, migrate ChatPage"
```

---

## Task 9: Implement UserProfileProvider and migrate ProfilePage

**Files:**
- Modify: `lib/providers/user_profile_provider.dart`
- Modify: `lib/pages/profile_page.dart`

- [ ] **Step 1: Implement UserProfileProvider**

```dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

class UserProfileProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserProfile? _profile;
  StreamSubscription<DocumentSnapshot>? _profileStream;

  UserProfile? get profile => _profile;

  void startListening(String uid) {
    _profileStream?.cancel();
    _profileStream = _db.collection('users').doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        _profile = UserProfile.fromDoc(doc);
        notifyListeners();
      }
    });
  }

  void stopListening() {
    _profileStream?.cancel();
    _profileStream = null;
    _profile = null;
    notifyListeners();
  }

  Future<void> updateProfile({String? username, String? photoUrl}) async {
    if (_profile == null) return;
    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (updates.isEmpty) return;
    await _db.collection('users').doc(_profile!.uid).update(updates);
  }

  @override
  void dispose() {
    _profileStream?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 2: Start profile listener in AuthWrapper**

In `lib/auth/auth_wrapper.dart`, when status becomes `authenticated`, start the profile listener:
```dart
case AuthStatus.authenticated:
  // Start profile listener
  Future.microtask(() {
    context.read<UserProfileProvider>()
        .startListening(auth.currentUid!);
  });
  return const HomePage();
```

When status becomes `unauthenticated`, stop it:
```dart
case AuthStatus.unauthenticated:
  Future.microtask(() {
    context.read<UserProfileProvider>().stopListening();
  });
  return const LoginPage();
```

- [ ] **Step 3: Migrate ProfilePage**

In `lib/pages/profile_page.dart`:
- Remove `StreamBuilder<DocumentSnapshot>` and Firestore setup
- Replace with `Consumer<UserProfileProvider>`
- Read `profile.username`, `profile.photoUrl` from provider
- Note: `likedSongs` and `recentMatches` shown in ProfilePage currently come from fields that don't exist in the Firestore schema — leave these as empty lists with a `// TODO` comment rather than breaking the UI

- [ ] **Step 4: Verify**

```bash
flutter analyze lib/providers/user_profile_provider.dart lib/pages/profile_page.dart
flutter run
```
Expected: Profile page shows username and photo, updates in real-time after profile setup dialog.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/user_profile_provider.dart lib/pages/profile_page.dart lib/auth/auth_wrapper.dart
git commit -m "feat: implement UserProfileProvider, migrate ProfilePage"
```

---

## Task 10: Move services and widgets, cleanup

**Files:**
- Move: `lib/pages/chat_service.dart` → `lib/services/chat_service.dart`
- Move: `lib/pages/match_service.dart` → `lib/services/match_service.dart`
- Move: `lib/pages/taste_service.dart` → `lib/services/taste_service.dart`
- Move: `lib/pages/card_stack.dart` → `lib/widgets/card_stack.dart`
- Update all imports

- [ ] **Step 1: Move service files**

```bash
mv lib/pages/chat_service.dart lib/services/chat_service.dart
mv lib/pages/match_service.dart lib/services/match_service.dart
mv lib/pages/taste_service.dart lib/services/taste_service.dart
mv lib/pages/card_stack.dart lib/widgets/card_stack.dart
```

- [ ] **Step 2: Update all imports across the codebase**

Find and replace import paths. Use your IDE's global find-replace or:
```bash
# On macOS/Linux:
grep -r "pages/chat_service" lib/ --include="*.dart" -l
grep -r "pages/match_service" lib/ --include="*.dart" -l
grep -r "pages/taste_service" lib/ --include="*.dart" -l
grep -r "pages/card_stack" lib/ --include="*.dart" -l
```
Update each found file to use the new `services/` or `widgets/` path.

- [ ] **Step 3: Remove dead code and comments from home_page.dart**

In `lib/pages/home_page.dart`, delete all commented-out blocks marked with `// ❌ REMOVE THIS`. These are:
- The old `_matchListener` declaration
- The old `_startMatchListener()` method stub
- The old `_showMatchPopup()` method stub

- [ ] **Step 4: Replace all print() with debugPrint()**

```bash
grep -rn "print(" lib/ --include="*.dart" | grep -v "debugPrint"
```
Replace each found `print(` with `debugPrint(`.

- [ ] **Step 5: Verify full clean build**

```bash
flutter analyze lib/
flutter run
```
Expected: Zero analyzer warnings related to this refactor. Full app runs end-to-end.

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "refactor: move services to lib/services/, widgets to lib/widgets/, remove dead code, replace print with debugPrint"
```

---

## Verification Checklist (run after all tasks complete)

- [ ] `flutter analyze lib/` — zero errors
- [ ] App launches from cold start
- [ ] Login with email/password works
- [ ] Login with Google works
- [ ] Login with phone/OTP works
- [ ] Phone/Google users go directly to HomePage (not email verification screen)
- [ ] Email users who haven't verified see the verification screen
- [ ] Wav page loads songs and swipe animations work
- [ ] Like button decrements daily counter
- [ ] Debug restore button visible in debug build, hidden in release
- [ ] Match page loads matches grouped by status
- [ ] Incoming match popup appears and accept/decline work
- [ ] Chat opens from MatchCard and messages stream in real-time
- [ ] Reply-to message works
- [ ] Profile page shows username and photo
- [ ] No `FirebaseAuth.instance` or `FirebaseFirestore.instance` calls remain in any page file
- [ ] No `print()` calls remain anywhere

