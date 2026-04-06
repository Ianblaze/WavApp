# Provider State Management Refactor — Design Spec

**Date:** 2026-03-19
**App:** Wavs (music-taste matching app)
**Status:** Approved for implementation

---

## Goal

Introduce Provider-based state management across the entire Wavs Flutter app. Remove all direct `FirebaseAuth.instance` and `FirebaseFirestore.instance` calls from UI widgets and pages. Pages become pure UI — they read from providers and call methods on them. Firebase is never touched directly by a widget.

---

## Architecture

Five `ChangeNotifier` providers registered at app root via `MultiProvider` in `main.dart`. Each provider owns one domain of state and exposes a clean method API. Services (`AuthService`, `ChatService`, `MatchService`, `TasteService`) remain as internal implementation details owned by providers — they are not deleted, but widgets no longer import or call them directly.

Typed model classes replace all `Map<String, dynamic>` data passing between layers.

---

## Folder Structure Changes

### New directories
- `lib/providers/` — all five provider files
- `lib/models/` — typed data models
- `lib/widgets/` — reusable widgets extracted from pages

### Files moving out of `lib/pages/`
- `card_stack.dart` → `lib/widgets/card_stack.dart`
- `MatchCard` class (currently in `match_page.dart`) → `lib/widgets/match_card.dart`
- `chat_service.dart` → `lib/services/chat_service.dart`
- `match_service.dart` → `lib/services/match_service.dart`
- `taste_service.dart` → `lib/services/taste_service.dart`

### Files staying exactly as-is (name and location unchanged)
`wav_page.dart`, `home_page.dart`, `chat_page.dart`, `match_page.dart`,
`profile_page.dart`, `splash.dart`, `profile_setup_dialog.dart`,
`setup_firestore.dart`, `match_popup.dart`, `match_dock_popup.dart`,
`match_notification.dart`

### File deleted
- `lib/services/match_notification_service.dart` — absorbed into `MatchProvider`

---

## Models

### `lib/models/song.dart`
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
    'title': title, 'artist': artist, 'genre': genre,
    'mood': mood, 'bpm': bpm.toString(), 'key': key, 'image': imageUrl,
  };
}
```

### `lib/models/match.dart`
```dart
class Match {
  final String userId;
  final String username;
  final String photoUrl;
  final String status;      // pending | incoming | connected | abandoned
  final String decision;
  final String reason;
  final String assignedRole; // initiator | receiver
  final String? chatId;

  const Match({
    required this.userId,
    required this.username,
    required this.photoUrl,
    required this.status,
    required this.decision,
    required this.reason,
    required this.assignedRole,
    this.chatId,
  });
}
```

### `lib/models/message.dart`
```dart
class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime? timestamp;
  final String status;       // sent | delivered | read
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

### `lib/models/user_profile.dart`
```dart
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

---

## Providers

### `lib/providers/auth_provider.dart`

**State owned:**
- `User? currentUser`
- `AuthStatus status` — enum: `loading | unauthenticated | authenticated | emailUnverified`

**Methods exposed:**
- `Future<void> signInWithGoogle()`
- `Future<void> signInWithEmail({required String email, required String password})`
- `Future<void> signUpWithEmail({required String email, required String password, required String name})`
- `Future<void> signInWithPhone({required String phoneNumber, required Function(String) onCodeSent, required Function(String) onError})`
- `Future<void> verifyOtp({required String otp, required String verificationId, required Function(String) onError})`
- `Future<void> signOut()`
- `Future<void> sendVerificationEmail()`
- `Future<void> checkEmailVerification()`

**Phone/Google auth fix:**
`AuthStatus.emailUnverified` only applies when `authProvider == 'email'`. Phone and Google auth users go straight to `authenticated` regardless of `emailVerified` flag.

**Internal implementation:**
Delegates to existing `AuthService` and `PhoneAuthService` from `lib/auth/auth_service.dart` — those classes are NOT deleted. Provider listens to `FirebaseAuth.instance.authStateChanges()` in constructor and updates state accordingly.

**Forbidden:**
Navigation, showing dialogs, any BuildContext usage.

---

### `lib/providers/songs_provider.dart`

**State owned:**
- `List<Song> songs`
- `int likesLeft`
- `bool isLoading`
- `bool songLoadFailed`
- `Timestamp? likesLastReset`

**Methods exposed:**
- `Future<void> loadSongs()` — called once on init
- `Future<void> swipeLike(Song song)` — decrements likes, records swipe, updates taste profile, triggers match processing
- `Future<void> swipeDislike(Song song)` — records dislike swipe
- `Future<void> restoreLikes()` — debug only, gated behind `kDebugMode`

**Internal implementation:**
Owns all Firestore logic currently in `WavPage`: `_loadSongsFromFirestore`, `_initLikesFromFirestore`, `_writeLikesToFirestore`, `_recordSwipe`, `_processAfterLike`. Delegates taste profile updates to `TasteService` and match processing to `MatchService`.

**CardStack interaction:**
`CardStack` widget still owns its own animation and gesture state. It calls `onLike(Song)` and `onDislike(Song)` callbacks that are wired to `SongsProvider.swipeLike()` and `SongsProvider.swipeDislike()` from `WavPage`. The `(s as dynamic).triggerLike()` anti-pattern is replaced: `CardStack` exposes a `CardStackController` (similar to `TextEditingController`) that `WavPage` holds and passes to the action buttons.

**Forbidden:**
Card animation logic, navigation, any BuildContext usage.

---

### `lib/providers/match_provider.dart`

**State owned:**
- `List<Match> matches` — real-time stream from Firestore
- `bool isLoading`
- `String? error`

**Methods exposed:**
- `Future<void> acceptMatch(String otherUserId)`
- `Future<void> declineMatch(String otherUserId, String? reason)`
- `Future<void> sendMatchRequest(String otherUserId)`
- `void startNotificationListener(BuildContext context)` — starts the incoming match popup listener
- `void stopNotificationListener()`

**Absorbs `MatchNotificationService`:**
The singleton `MatchNotificationService` is deleted. Its stream listener, duplicate-prevention set (`_processedMatches`), and popup-showing logic move directly into `MatchProvider`. `HomePage` calls `context.read<MatchProvider>().startNotificationListener(context)` in `initState`.

**`_computeSimilarity` deduplication:**
The duplicated method (currently in both `MatchService` and `MatchNotificationService`) is moved to a single static helper in `lib/services/match_service.dart` and called from both `MatchProvider` and wherever else it's needed.

**Forbidden:**
Chat logic, navigation beyond showing the match popup.

---

### `lib/providers/chat_provider.dart`

**State owned:**
- `List<Message> messages` — real-time stream for the active chat
- `bool isSending`
- `Message? replyingTo`
- `String? activeChatId`

**Lifecycle:**
Created when a chat opens. `WavPage` and `MatchPage` do NOT use this provider. Only `ChatPage` consumes it. `ChatPage` calls `context.read<ChatProvider>().openChat(chatId)` in `initState` and the provider subscribes to the Firestore stream. On `ChatPage` dispose, `context.read<ChatProvider>().closeChat()` is called.

**Methods exposed:**
- `void openChat(String chatId)`
- `void closeChat()`
- `Future<void> sendMessage(String text)`
- `void setReply(Message? message)`
- `void cancelReply()`
- `Future<void> markMessagesRead(String otherUserId)`

**`chatId` generation fix:**
`MatchCard`'s inline Firestore write for `chatId` is removed. `ChatProvider.openChat()` calls `ChatService.createOrGetChat(otherUserId)` which already handles this correctly.

**Internal implementation:**
Delegates to `ChatService` from `lib/services/chat_service.dart`.

**Forbidden:**
Match logic, user profile fetching, navigation.

---

### `lib/providers/user_profile_provider.dart`

**State owned:**
- `UserProfile? profile` — real-time Firestore stream of current user's doc

**Methods exposed:**
- `Future<void> updateProfile({String? username, String? photoUrl})`
- `void startListening(String uid)` — subscribes to Firestore stream
- `void stopListening()`

**Internal implementation:**
Owns the `StreamBuilder` logic currently inside `ProfilePage`. Listens to `FirebaseFirestore.instance.collection('users').doc(uid).snapshots()` and maps docs to `UserProfile` model.

**Forbidden:**
Auth logic, match logic.

---

## `main.dart` Changes

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => SongsProvider()),
    ChangeNotifierProvider(create: (_) => MatchProvider()),
    ChangeNotifierProvider(create: (_) => ChatProvider()),
    ChangeNotifierProvider(create: (_) => UserProfileProvider()),
  ],
  child: MaterialApp(...),
)
```

`AuthWrapper` becomes a `Consumer<AuthProvider>` — no more `StreamBuilder<User?>` directly on `FirebaseAuth.instance.authStateChanges()`.

---

## Migration Order (Phases)

Each phase leaves the app in a fully runnable state.

1. **Foundation** — Create all models, all provider files (empty shells), wire `MultiProvider` in `main.dart`. App runs exactly as before.
2. **Auth** — `AuthProvider` fully implemented. `LoginPage`, `AuthWrapper` switch to consuming it. Direct `FirebaseAuth` calls removed from these files.
3. **Songs** — `SongsProvider` fully implemented. `WavPage` switches to consuming it. `CardStackController` introduced.
4. **Matches** — `MatchProvider` fully implemented. `MatchPage`, `HomePage` switch to consuming it. `MatchNotificationService` deleted.
5. **Chat** — `ChatProvider` fully implemented. `ChatPage` switches to consuming it. `MatchCard` chatId logic fixed.
6. **Profile** — `UserProfileProvider` fully implemented. `ProfilePage` switches to consuming it.
7. **Cleanup** — Remove dead comments, gate `restoreLikes` behind `kDebugMode`, fix phone/Google email verification bug, move service files to `lib/services/`, extract `CardStack` and `MatchCard` to `lib/widgets/`.

---

## Rules for All Providers

- Never import `package:flutter/material.dart` for BuildContext usage (exception: `MatchProvider.startNotificationListener` which needs context only to show a popup)
- Never call `Navigator` from a provider
- Always call `notifyListeners()` after state changes
- Always cancel stream subscriptions in `dispose()`
- Use `debugPrint()` not `print()` everywhere
- Gate test/debug helpers behind `kDebugMode`

---

## Bugs Fixed During This Refactor

1. **Phone/Google auth email verification bug** — users authenticated via phone or Google were incorrectly sent to `EmailVerificationRequiredScreen` because `user.emailVerified` is false by default for those providers. Fixed in `AuthProvider` by checking `authProvider` field.
2. **`(s as dynamic).triggerLike()` anti-pattern** — replaced with `CardStackController`.
3. **`_computeSimilarity` duplication** — single implementation in `MatchService`, called from `MatchProvider`.
4. **`MatchCard` inline chatId Firestore writes** — moved into `ChatProvider.openChat()`.
5. **`print()` calls** — replaced with `debugPrint()` across all files.
6. **`_restoreLikesForTest` visible in production** — gated behind `kDebugMode`.

---

## Out of Scope

- Firestore read bomb in `processMatchesForUser()` — this is a separate refactor (Cloud Functions) tracked separately.
- Card animation refactor (manual frame loop → `AnimationController`) — separate task.
- Any new features.

