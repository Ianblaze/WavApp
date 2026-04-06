 # Wav Auth Upgrade — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the auth system from a high-school-grade prototype to industry-standard quality — fixing security issues, splitting the monolith, removing redundant navigation, adding a country picker for phone auth, replacing polling with streams, and cleaning up all debug logging.

**Architecture:** Three clean layers — `AuthRepository` (pure Firebase logic) → `AuthProvider` (state, single source of truth) → screen widgets (one file per screen). The `AuthWrapper` remains the single routing authority; all manual `Navigator.pushAndRemoveUntil` calls are removed. Auth state flows down via Provider, never pushed up via callbacks.

**Tech Stack:** Flutter, Firebase Auth, Cloud Firestore, Provider, `country_code_picker` package, `flutter_dotenv` for secrets, `flutter/foundation.dart` `kDebugMode` for log gating.

---

## File Map — What Changes and Why

| Action | File | Reason |
|--------|------|--------|
| **Rename → `AuthRepository`** | `lib/auth/auth_service.dart` | `AuthService` becomes `AuthRepository` with no public print calls and no hardcoded client ID |
| **Rewrite** | `lib/providers/auth_provider.dart` | Switch verification polling → `idTokenChanges()` stream; remove redundant SharedPreferences logic |
| **Rewrite** | `lib/auth/auth_wrapper.dart` | Keep as sole router, remove UI clutter in verification screen, keep resend/check buttons |
| **Rewrite** | `lib/auth/login_page.dart` | Remove direct `AuthService` instantiation; remove `_checkAutoLogin`; remove `_navigateToHome`; keep all animations |
| **Delete** | `lib/auth/login_dialogs.dart` | Monolith. Split into 4 focused files below |
| **Create** | `lib/auth/screens/email_signup_screen.dart` | Full-screen email sign-up (was a dialog) |
| **Create** | `lib/auth/screens/email_login_screen.dart` | Full-screen email login (was a dialog) |
| **Create** | `lib/auth/screens/phone_auth_screen.dart` | Full-screen phone OTP with country picker |
| **Create** | `lib/auth/widgets/auth_text_field.dart` | Shared styled text field extracted from dialogs |
| **Create** | `lib/auth/widgets/password_requirements.dart` | Password strength widget |
| **Create** | `lib/auth/utils/auth_error_messages.dart` | `FirebaseAuthException` → human string mapper |
| **Create** | `lib/auth/utils/rate_limiter.dart` | Simple cooldown timer for OTP / resend buttons |
| **Create** | `.env` | `GOOGLE_WEB_CLIENT_ID=...` (gitignored) |
| **Modify** | `pubspec.yaml` | Add `country_code_picker`, `flutter_dotenv` |
| **Modify** | `lib/main.dart` | Load `.env` at startup |
| **Modify** | `lib/pages/home_page.dart` | Remove `Navigator.pushReplacement(LoginPage)` on sign-out — let AuthWrapper handle it |

---

## Task 1: Secrets out of source, packages in

**Files:**
- Create: `.env`
- Create: `.gitignore` entry
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`

- [ ] **Step 1: Add packages to `pubspec.yaml`**

In the `dependencies:` section add:
```yaml
country_code_picker: ^3.0.0
flutter_dotenv: ^5.1.0
```

Run:
```bash
flutter pub get
```
Expected: resolves without conflict.

- [ ] **Step 2: Create `.env` at project root**

```
GOOGLE_WEB_CLIENT_ID=473711579608-up2ti7fp7rm5r91e00l2sd9tb14s2uif.apps.googleusercontent.com
```

- [ ] **Step 3: Add `.env` to `.gitignore`**

Open `.gitignore`, append:
```
.env
```

- [ ] **Step 4: Register `.env` as a Flutter asset**

In `pubspec.yaml` under `flutter:` → `assets:`:
```yaml
flutter:
  assets:
    - .env
```

- [ ] **Step 5: Load `.env` in `main()`**

In `lib/main.dart`, add import and load call:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');          // ADD THIS LINE
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```

- [ ] **Step 6: Commit**
```bash
git add pubspec.yaml .env .gitignore lib/main.dart
git commit -m "feat(auth): load secrets from .env, add country_code_picker + flutter_dotenv"
```

---

## Task 2: Create `auth_error_messages.dart` utility

**Files:**
- Create: `lib/auth/utils/auth_error_messages.dart`

This is a pure, side-effect-free function. Nothing to test with Firebase, so just verify the switch compiles.

- [ ] **Step 1: Create the file**

```dart
// lib/auth/utils/auth_error_messages.dart
import 'package:firebase_auth/firebase_auth.dart';

String authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'weak-password':
      return 'Choose a stronger password (8+ chars, upper, number, symbol).';
    case 'email-already-in-use':
      return 'An account already exists with this email.';
    case 'invalid-email':
      return 'That email address looks invalid.';
    case 'user-not-found':
      return 'No account found with this email.';
    case 'wrong-password':
      return 'Incorrect password.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'too-many-requests':
      return 'Too many attempts — wait a few minutes and try again.';
    case 'operation-not-allowed':
      return 'This sign-in method is not enabled.';
    case 'network-request-failed':
      return 'Network error. Check your connection.';
    case 'invalid-verification-code':
      return 'That OTP is wrong. Please try again.';
    case 'session-expired':
      return 'The OTP expired. Request a new one.';
    default:
      return e.message ?? 'Something went wrong. Please try again.';
  }
}
```

- [ ] **Step 2: Commit**
```bash
git add lib/auth/utils/auth_error_messages.dart
git commit -m "feat(auth): add centralized FirebaseAuthException → message mapper"
```

---

## Task 3: Create `rate_limiter.dart` utility

**Files:**
- Create: `lib/auth/utils/rate_limiter.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/auth/utils/rate_limiter.dart
import 'dart:async';

/// Enforces a cooldown between calls (e.g. OTP send, email resend).
/// Usage:
///   final _limiter = RateLimiter(cooldown: Duration(seconds: 60));
///   if (!_limiter.allow()) { showError('Wait...'); return; }
class RateLimiter {
  final Duration cooldown;
  DateTime? _lastCall;
  Timer? _timer;
  final void Function(int secondsLeft)? onTick;   // optional countdown callback
  final void Function()? onReady;                  // fires when cooldown ends

  RateLimiter({
    required this.cooldown,
    this.onTick,
    this.onReady,
  });

  /// Returns true if the call is allowed, false if still in cooldown.
  bool allow() {
    final now = DateTime.now();
    if (_lastCall == null || now.difference(_lastCall!) >= cooldown) {
      _lastCall = now;
      _startCountdown();
      return true;
    }
    return false;
  }

  int get secondsRemaining {
    if (_lastCall == null) return 0;
    final elapsed = DateTime.now().difference(_lastCall!);
    final remaining = cooldown.inSeconds - elapsed.inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isInCooldown => secondsRemaining > 0;

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = secondsRemaining;
      onTick?.call(left);
      if (left <= 0) {
        t.cancel();
        onReady?.call();
      }
    });
  }

  void dispose() => _timer?.cancel();
}
```

- [ ] **Step 2: Commit**
```bash
git add lib/auth/utils/rate_limiter.dart
git commit -m "feat(auth): add RateLimiter for OTP/resend cooldown enforcement"
```

---

## Task 4: Create shared `auth_text_field.dart` widget

**Files:**
- Create: `lib/auth/widgets/auth_text_field.dart`

This is the styled input field that was duplicated across `login_dialogs.dart`. One source of truth.

- [ ] **Step 1: Create the file**

```dart
// lib/auth/widgets/auth_text_field.dart
import 'package:flutter/material.dart';

// Matches the Y2K palette used across login screens
const _cardHotPink = Color(0xFFFFB3D9);

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffixWidget;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final Widget? prefixWidget;         // for country code picker

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffixWidget,
    this.onChanged,
    this.validator,
    this.prefixWidget,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: onChanged,
        validator: validator,
        style: const TextStyle(
          fontFamily: 'Circular',
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: 'Circular',
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
          ),
          prefixIcon: prefixWidget ??
              Icon(icon, color: Colors.white.withOpacity(0.7), size: 20),
          suffixIcon: suffixWidget,
          filled: true,
          fillColor: Colors.white.withOpacity(0.15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _cardHotPink, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**
```bash
git add lib/auth/widgets/auth_text_field.dart
git commit -m "feat(auth): extract AuthTextField shared widget"
```

---

## Task 5: Create `password_requirements.dart` widget

**Files:**
- Create: `lib/auth/widgets/password_requirements.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/auth/widgets/password_requirements.dart
import 'package:flutter/material.dart';

class PasswordRequirements extends StatelessWidget {
  final String password;

  const PasswordRequirements({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Requirement('At least 8 characters', password.length >= 8),
        _Requirement('One uppercase letter',
            password.contains(RegExp(r'[A-Z]'))),
        _Requirement('One number', password.contains(RegExp(r'[0-9]'))),
        _Requirement('One special character',
            password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  final String label;
  final bool met;

  const _Requirement(this.label, this.met);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: met ? Colors.greenAccent : Colors.white54,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Circular',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: met ? Colors.greenAccent : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**
```bash
git add lib/auth/widgets/password_requirements.dart
git commit -m "feat(auth): extract PasswordRequirements widget"
```

---

## Task 6: Rewrite `AuthRepository` (was `AuthService`)

**Files:**
- Modify: `lib/auth/auth_service.dart`

Key changes: read client ID from `dotenv`, remove all `print()` calls, replace with `kDebugMode`-gated `debugPrint()`, keep all existing method signatures intact so nothing else breaks.

- [ ] **Step 1: Rewrite `lib/auth/auth_service.dart`**

```dart
// lib/auth/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  GoogleSignIn get _googleSignIn => GoogleSignIn(
        scopes: ['email'],
        clientId: kIsWeb ? dotenv.env['GOOGLE_WEB_CLIENT_ID'] : null,
      );

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Google Sign-In ───────────────────────────────────────────────
  Future<User?> signInWithGoogle() async {
    final gs = _googleSignIn;
    final googleUser = await gs.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    final result = await _auth.signInWithCredential(credential);
    if (result.user != null) await _saveUserToFirestore(result.user!);
    return result.user;
  }

  // ── Email Sign-Up ────────────────────────────────────────────────
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = result.user;
    if (user != null) {
      await user.updateDisplayName(name);
      await user.reload();
      await _db.collection('users').doc(user.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'authProvider': 'email',
      });
    }
    return user;
  }

  // ── Email Login ──────────────────────────────────────────────────
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  // ── Password Reset ───────────────────────────────────────────────
  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  // ── Sign Out ─────────────────────────────────────────────────────
  Future<void> signOut() async {
    final gs = _googleSignIn;
    if (await gs.isSignedIn()) await gs.signOut();
    await _auth.signOut();
  }

  // ── Internal: Firestore user doc ─────────────────────────────────
  Future<void> _saveUserToFirestore(User user) async {
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await _db.collection('users').doc(user.uid).set({
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'authProvider': 'google',
      });
    } else {
      await _db
          .collection('users')
          .doc(user.uid)
          .update({'lastLogin': FieldValue.serverTimestamp()});
    }
  }
}

// ── Phone Auth ───────────────────────────────────────────────────────
class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? verificationId;

  Future<void> sendOtp({
    required String phoneNumber,      // must already include country code: +91...
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        final result = await _auth.signInWithCredential(credential);
        if (result.user != null) await _saveUserToFirestore(result.user!);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (kDebugMode) debugPrint('Phone verification failed: ${e.code}');
        onError(e.message ?? 'Phone verification failed');
      },
      codeSent: (String verId, int? resendToken) {
        verificationId = verId;
        onCodeSent(verId);
      },
      codeAutoRetrievalTimeout: (String verId) {
        verificationId = verId;
      },
    );
  }

  Future<User?> verifyOtp({
    required String otp,
    required String verificationId,
    required void Function(String error) onError,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      final result = await _auth.signInWithCredential(credential);
      if (result.user != null) await _saveUserToFirestore(result.user!);
      return result.user;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) debugPrint('OTP verify error: ${e.code}');
      onError(e.code == 'invalid-verification-code'
          ? 'Invalid OTP. Please try again.'
          : e.message ?? 'Invalid OTP');
      return null;
    }
  }

  Future<void> _saveUserToFirestore(User user) async {
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await _db.collection('users').doc(user.uid).set({
        'name': user.displayName ?? '',
        'phoneNumber': user.phoneNumber ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'authProvider': 'phone',
      });
    } else {
      await _db
          .collection('users')
          .doc(user.uid)
          .update({'lastLogin': FieldValue.serverTimestamp()});
    }
  }
}
```

- [ ] **Step 2: Hot-reload the app, verify Google sign-in still works end to end**

- [ ] **Step 3: Commit**
```bash
git add lib/auth/auth_service.dart
git commit -m "refactor(auth): move client ID to .env, remove all print() calls, clean up AuthService"
```

---

## Task 7: Rewrite `AuthProvider` — replace polling with `idTokenChanges()` stream

**Files:**
- Modify: `lib/providers/auth_provider.dart`

The key change: remove `checkEmailVerification()` manual polling. Instead, listen to `_auth.idTokenChanges()` — Firebase fires this stream whenever the token refreshes, including after a user clicks the verification link. This means verification is detected **automatically** with no button press needed — though the "I've verified" button remains as a manual fallback.

- [ ] **Step 1: Rewrite `lib/providers/auth_provider.dart`**

```dart
// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';

enum AuthStatus { loading, unauthenticated, authenticated, emailUnverified }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final PhoneAuthService _phoneAuthService = PhoneAuthService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  AuthStatus _status = AuthStatus.loading;
  User? _currentUser;
  StreamSubscription<User?>? _idTokenSub;

  AuthStatus get status => _status;
  User? get currentUser => _currentUser;
  String? get currentUid => _currentUser?.uid;

  AuthProvider() {
    // idTokenChanges fires on: sign-in, sign-out, token refresh,
    // AND when email gets verified (token refreshes with emailVerified=true).
    // This replaces the manual polling approach entirely.
    _idTokenSub = _firebaseAuth.idTokenChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) {
    _currentUser = user;
    if (user == null) {
      _status = AuthStatus.unauthenticated;
    } else {
      final providerId = user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : '';
      final isEmailProvider = providerId == 'password';
      _status = (isEmailProvider && !user.emailVerified)
          ? AuthStatus.emailUnverified
          : AuthStatus.authenticated;
    }
    notifyListeners();
  }

  // ── Google ───────────────────────────────────────────────────────
  Future<void> signInWithGoogle() => _authService.signInWithGoogle();

  // ── Email ────────────────────────────────────────────────────────
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _authService.signInWithEmail(email: email, password: password);

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) => _authService.signUpWithEmail(
      email: email, password: password, name: name);

  // ── Phone ────────────────────────────────────────────────────────
  Future<void> signInWithPhone({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
  }) => _phoneAuthService.sendOtp(
      phoneNumber: phoneNumber, onCodeSent: onCodeSent, onError: onError);

  Future<void> verifyOtp({
    required String otp,
    required String verificationId,
    required void Function(String error) onError,
  }) => _phoneAuthService.verifyOtp(
      otp: otp, verificationId: verificationId, onError: onError);

  // ── Email verification ───────────────────────────────────────────
  Future<void> sendVerificationEmail() =>
      _currentUser?.sendEmailVerification() ?? Future.value();

  /// Manual fallback: force a token refresh so idTokenChanges fires immediately
  /// if the user has already clicked the verification link but the stream
  /// hasn't fired yet in this session.
  Future<void> forceTokenRefresh() async {
    await _currentUser?.reload();
    final refreshed = _firebaseAuth.currentUser;
    if (refreshed != null) _onAuthStateChanged(refreshed);
  }

  // ── Sign out ─────────────────────────────────────────────────────
  Future<void> signOut() => _authService.signOut();

  @override
  void dispose() {
    _idTokenSub?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 2: Hot-reload, open app, sign up with email — verify the `emailUnverified` screen appears**

- [ ] **Step 3: In a separate browser tab, click the verification link. Verify the app automatically transitions to `HomePage` within a few seconds without pressing any button.** (This is the stream doing its job.)

- [ ] **Step 4: Commit**
```bash
git add lib/providers/auth_provider.dart
git commit -m "feat(auth): replace verification polling with idTokenChanges() stream — auto-detect verification"
```

---

## Task 8: Update `AuthWrapper` verification screen

**Files:**
- Modify: `lib/auth/auth_wrapper.dart`

Changes: call `forceTokenRefresh()` (not the old `checkEmailVerification()`) on the manual button press. Everything else in the verification screen stays the same.

- [ ] **Step 1: In `_checkEmailVerification()` method, replace the body**

Find this in `auth_wrapper.dart`:
```dart
Future<void> _checkEmailVerification() async {
    setState(() => _isChecking = true);

    try {
      await context.read<AuthProvider>().checkEmailVerification();
```

Replace with:
```dart
Future<void> _checkEmailVerification() async {
    setState(() => _isChecking = true);

    try {
      await context.read<AuthProvider>().forceTokenRefresh();
```

The rest of the method stays identical.

- [ ] **Step 2: Hot-reload, verify the manual "I've verified my email" button still works**

- [ ] **Step 3: Commit**
```bash
git add lib/auth/auth_wrapper.dart
git commit -m "refactor(auth): update AuthWrapper to use forceTokenRefresh() instead of removed polling method"
```

---

## Task 9: Create `EmailSignUpScreen`

**Files:**
- Create: `lib/auth/screens/email_signup_screen.dart`

This replaces `showEmailSignUpDialog` in `login_dialogs.dart`. It's a full screen (pushed onto the nav stack from `LoginPage`) with the same Y2K glassmorphism look. It uses `AuthProvider` — no direct `AuthService` instantiation.

- [ ] **Step 1: Create the file**

```dart
// lib/auth/screens/email_signup_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' show ImageFilter;

import '../../providers/auth_provider.dart';
import '../utils/auth_error_messages.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/password_requirements.dart';

const _cardHotPink  = Color(0xFFFFB3D9);
const _accentGlow   = Color(0xFFFF99CC);
const _cardNeonPurple = Color(0xFFD9B3FF);
const _cardLavenderPop = Color(0xFFE6CCFF);
const _cardElectricBlue = Color(0xFFB3D9FF);

class EmailSignUpScreen extends StatefulWidget {
  const EmailSignUpScreen({super.key});

  @override
  State<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends State<EmailSignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _usernameError;
  bool _usernameChecking = false;
  bool _usernameAvailable = false;

  late final AnimationController _bgCtrl;
  late final Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Username availability ─────────────────────────────────────────
  Future<void> _checkUsername(String raw) async {
    final username = raw.toLowerCase().trim();
    if (username.length < 3) {
      setState(() { _usernameError = 'At least 3 characters'; _usernameAvailable = false; });
      return;
    }
    if (username.length > 20) {
      setState(() { _usernameError = 'Max 20 characters'; _usernameAvailable = false; });
      return;
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      setState(() { _usernameError = 'Only lowercase letters, numbers, _'; _usernameAvailable = false; });
      return;
    }
    setState(() { _usernameChecking = true; _usernameError = null; });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(username)
          .get();
      setState(() {
        _usernameChecking = false;
        _usernameAvailable = !snap.exists;
        _usernameError = snap.exists ? 'Username already taken' : null;
      });
    } catch (e) {
      setState(() { _usernameChecking = false; _usernameError = 'Could not check — try again'; });
    }
  }

  // ── Submit ────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_usernameAvailable) {
      _showSnack('Pick an available username', Colors.orange);
      return;
    }
    setState(() => _loading = true);
    try {
      final username = _usernameCtrl.text.toLowerCase().trim();
      await context.read<AuthProvider>().signUpWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        name: username,
      );
      // Reserve the username
      final uid = context.read<AuthProvider>().currentUid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('usernames')
            .doc(username)
            .set({'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
      }
      // Auth stream fires → AuthWrapper routes to emailUnverified screen
      // Send verification email
      await context.read<AuthProvider>().sendVerificationEmail();
      // No manual navigation needed — AuthWrapper handles it
    } on FirebaseAuthException catch (e) {
      if (mounted) _showSnack(authErrorMessage(e), Colors.red);
    } catch (e) {
      if (kDebugMode) debugPrint('SignUp error: $e');
      if (mounted) _showSnack('Something went wrong. Please try again.', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Circular', color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgAnim,
        builder: (ctx, child) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(_accentGlow, _cardNeonPurple, _bgAnim.value)!.withOpacity(0.85),
                Color.lerp(_cardHotPink, _cardLavenderPop, _bgAnim.value)!.withOpacity(0.75),
                Color.lerp(_cardLavenderPop, _cardElectricBlue, _bgAnim.value)!.withOpacity(0.7),
              ],
            ),
          ),
          child: child,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Create account',
                                style: TextStyle(fontFamily: 'Circular', fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(height: 8),
                            Text('Pick a username and get started',
                                style: TextStyle(fontFamily: 'Circular', fontSize: 15, color: Colors.white.withOpacity(0.8))),
                            const SizedBox(height: 28),

                            // Username
                            AuthTextField(
                              controller: _usernameCtrl,
                              hint: 'username',
                              icon: Icons.alternate_email_rounded,
                              onChanged: _checkUsername,
                            ),
                            if (_usernameChecking)
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 4),
                                child: Row(children: [
                                  const SizedBox(width: 14, height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
                                  const SizedBox(width: 8),
                                  Text('Checking...', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Circular')),
                                ]),
                              ),
                            if (_usernameError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 4),
                                child: Text(_usernameError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontFamily: 'Circular')),
                              ),
                            if (_usernameAvailable && _usernameCtrl.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 4),
                                child: Text('✓ Available', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'Circular', fontWeight: FontWeight.w600)),
                              ),
                            const SizedBox(height: 14),

                            // Email
                            AuthTextField(
                              controller: _emailCtrl,
                              hint: 'email address',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Invalid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Password
                            AuthTextField(
                              controller: _passwordCtrl,
                              hint: 'password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscure,
                              onChanged: (_) => setState(() {}),
                              suffixWidget: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: Colors.white60, size: 20),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                              validator: (v) {
                                if (v == null || v.length < 8) return 'At least 8 characters';
                                if (!v.contains(RegExp(r'[A-Z]'))) return 'Add an uppercase letter';
                                if (!v.contains(RegExp(r'[0-9]'))) return 'Add a number';
                                if (!v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return 'Add a special character';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Password strength
                            PasswordRequirements(password: _passwordCtrl.text),
                            const SizedBox(height: 28),

                            // Submit
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: _cardHotPink,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 6,
                                ),
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const SizedBox(width: 22, height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: _cardHotPink))
                                    : const Text('Create account',
                                        style: TextStyle(fontFamily: 'Circular', fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Hot-reload. Navigate to sign-up from `LoginPage` (step 11 will wire this). Confirm form validation and username availability check work.**

- [ ] **Step 3: Commit**
```bash
git add lib/auth/screens/email_signup_screen.dart
git commit -m "feat(auth): EmailSignUpScreen — full screen replaces dialog, uses AuthProvider"
```

---

## Task 10: Create `EmailLoginScreen`

**Files:**
- Create: `lib/auth/screens/email_login_screen.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/auth/screens/email_login_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' show ImageFilter;

import '../../providers/auth_provider.dart';
import '../utils/auth_error_messages.dart';
import '../widgets/auth_text_field.dart';

const _cardHotPink     = Color(0xFFFFB3D9);
const _accentGlow      = Color(0xFFFF99CC);
const _cardNeonPurple  = Color(0xFFD9B3FF);
const _cardLavenderPop = Color(0xFFE6CCFF);
const _cardElectricBlue = Color(0xFFB3D9FF);

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  late final AnimationController _bgCtrl;
  late final Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      // AuthWrapper listens to idTokenChanges() → routes to Home or emailUnverified automatically
    } on FirebaseAuthException catch (e) {
      if (mounted) _showSnack(authErrorMessage(e), Colors.red);
    } catch (e) {
      if (kDebugMode) debugPrint('Login error: $e');
      if (mounted) _showSnack('Something went wrong. Try again.', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Enter your email address first', Colors.orange);
      return;
    }
    try {
      await context.read<AuthProvider>().sendVerificationEmail();
      // Use AuthService directly for reset (AuthProvider doesn't expose it — fine for now)
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnack('Reset link sent to $email', _accentGlow);
    } on FirebaseAuthException catch (e) {
      _showSnack(authErrorMessage(e), Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Circular', color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgAnim,
        builder: (ctx, child) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(_accentGlow, _cardNeonPurple, _bgAnim.value)!.withOpacity(0.85),
                Color.lerp(_cardHotPink, _cardLavenderPop, _bgAnim.value)!.withOpacity(0.75),
                Color.lerp(_cardLavenderPop, _cardElectricBlue, _bgAnim.value)!.withOpacity(0.7),
              ],
            ),
          ),
          child: child,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Welcome back',
                                style: TextStyle(fontFamily: 'Circular', fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(height: 8),
                            Text('Sign in to your account',
                                style: TextStyle(fontFamily: 'Circular', fontSize: 15, color: Colors.white.withOpacity(0.8))),
                            const SizedBox(height: 28),

                            AuthTextField(
                              controller: _emailCtrl,
                              hint: 'email address',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 14),

                            AuthTextField(
                              controller: _passwordCtrl,
                              hint: 'password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscure,
                              suffixWidget: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: Colors.white60, size: 20),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 8),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _forgotPassword,
                                child: Text('Forgot password?',
                                    style: TextStyle(fontFamily: 'Circular', color: Colors.white.withOpacity(0.85),
                                        fontSize: 13, fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.white.withOpacity(0.85))),
                              ),
                            ),
                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: _cardHotPink,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 6,
                                ),
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const SizedBox(width: 22, height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: _cardHotPink))
                                    : const Text('Sign in',
                                        style: TextStyle(fontFamily: 'Circular', fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**
```bash
git add lib/auth/screens/email_login_screen.dart
git commit -m "feat(auth): EmailLoginScreen — full screen, uses AuthProvider, no manual navigation"
```

---

## Task 11: Create `PhoneAuthScreen` with country picker

**Files:**
- Create: `lib/auth/screens/phone_auth_screen.dart`

This is the most significant UX change — replacing the hardcoded +91 with a proper country code picker, and wrapping the OTP send button with a 60-second cooldown using `RateLimiter`.

- [ ] **Step 1: Create the file**

```dart
// lib/auth/screens/phone_auth_screen.dart
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' show ImageFilter;

import '../../providers/auth_provider.dart';
import '../utils/auth_error_messages.dart';
import '../utils/rate_limiter.dart';
import '../widgets/auth_text_field.dart';

const _cardHotPink     = Color(0xFFFFB3D9);
const _accentGlow      = Color(0xFFFF99CC);
const _cardNeonPurple  = Color(0xFFD9B3FF);
const _cardLavenderPop = Color(0xFFE6CCFF);
const _cardElectricBlue = Color(0xFFB3D9FF);

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen>
    with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();

  String _countryCode = '+91';   // default India, user can change
  String? _verificationId;
  bool _loading = false;
  bool _otpSent = false;
  int _cooldownSeconds = 0;

  late final RateLimiter _rateLimiter;
  late final AnimationController _bgCtrl;
  late final Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();
    _rateLimiter = RateLimiter(
      cooldown: const Duration(seconds: 60),
      onTick: (s) { if (mounted) setState(() => _cooldownSeconds = s); },
      onReady: () { if (mounted) setState(() => _cooldownSeconds = 0); },
    );
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _rateLimiter.dispose();
    _bgCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ── Send OTP ──────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final number = _phoneCtrl.text.trim();
    if (number.isEmpty) { _showSnack('Enter your phone number', Colors.orange); return; }
    if (!_rateLimiter.allow()) {
      _showSnack('Wait $_cooldownSeconds seconds before resending', Colors.orange);
      return;
    }
    setState(() => _loading = true);
    await context.read<AuthProvider>().signInWithPhone(
      phoneNumber: '$_countryCode$number',
      onCodeSent: (verId) {
        setState(() { _verificationId = verId; _otpSent = true; _loading = false; });
        _showSnack('OTP sent!', _accentGlow);
      },
      onError: (err) {
        if (mounted) { setState(() => _loading = false); _showSnack(err, Colors.red); }
      },
    );
  }

  // ── Verify OTP ────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) { _showSnack('Enter the 6-digit code', Colors.orange); return; }
    if (_verificationId == null) { _showSnack('Request an OTP first', Colors.orange); return; }
    setState(() => _loading = true);
    await context.read<AuthProvider>().verifyOtp(
      otp: otp,
      verificationId: _verificationId!,
      onError: (err) {
        if (mounted) { setState(() => _loading = false); _showSnack(err, Colors.red); }
      },
    );
    // On success, AuthWrapper streams the new auth state → routes to Home automatically
    if (mounted) setState(() => _loading = false);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Circular', color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgAnim,
        builder: (ctx, child) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(_accentGlow, _cardNeonPurple, _bgAnim.value)!.withOpacity(0.85),
                Color.lerp(_cardHotPink, _cardLavenderPop, _bgAnim.value)!.withOpacity(0.75),
                Color.lerp(_cardLavenderPop, _cardElectricBlue, _bgAnim.value)!.withOpacity(0.7),
              ],
            ),
          ),
          child: child,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Phone sign-in',
                              style: TextStyle(fontFamily: 'Circular', fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 8),
                          Text(_otpSent ? 'Enter the 6-digit code we sent you' : 'We\'ll send you a one-time code',
                              style: TextStyle(fontFamily: 'Circular', fontSize: 15, color: Colors.white.withOpacity(0.8))),
                          const SizedBox(height: 28),

                          if (!_otpSent) ...[
                            // Country code picker + phone number row
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  child: CountryCodePicker(
                                    onChanged: (c) => setState(() => _countryCode = c.dialCode ?? '+91'),
                                    initialSelection: 'IN',
                                    favorite: const ['IN', 'US', 'GB'],
                                    showCountryOnly: false,
                                    showOnlyCountryWhenClosed: false,
                                    alignLeft: false,
                                    textStyle: const TextStyle(color: Colors.white, fontFamily: 'Circular', fontSize: 15),
                                    flagDecoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: AuthTextField(
                                    controller: _phoneCtrl,
                                    hint: 'phone number',
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: _cardHotPink,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 6,
                                ),
                                onPressed: (_loading || _cooldownSeconds > 0) ? null : _sendOtp,
                                child: _loading
                                    ? const SizedBox(width: 22, height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: _cardHotPink))
                                    : Text(
                                        _cooldownSeconds > 0
                                            ? 'Resend in ${_cooldownSeconds}s'
                                            : 'Send OTP',
                                        style: const TextStyle(fontFamily: 'Circular', fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],

                          if (_otpSent) ...[
                            AuthTextField(
                              controller: _otpCtrl,
                              hint: '6-digit OTP',
                              icon: Icons.sms_outlined,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            // Resend link with cooldown
                            TextButton(
                              onPressed: _cooldownSeconds > 0 ? null : _sendOtp,
                              child: Text(
                                _cooldownSeconds > 0
                                    ? 'Resend in ${_cooldownSeconds}s'
                                    : 'Resend OTP',
                                style: TextStyle(
                                  fontFamily: 'Circular',
                                  color: _cooldownSeconds > 0
                                      ? Colors.white38
                                      : Colors.white.withOpacity(0.85),
                                  fontWeight: FontWeight.w600,
                                  decoration: _cooldownSeconds > 0
                                      ? TextDecoration.none
                                      : TextDecoration.underline,
                                  decorationColor: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: _cardHotPink,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 6,
                                ),
                                onPressed: _loading ? null : _verifyOtp,
                                child: _loading
                                    ? const SizedBox(width: 22, height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: _cardHotPink))
                                    : const Text('Verify',
                                        style: TextStyle(fontFamily: 'Circular', fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Hot-reload. Test the country picker renders correctly on the phone auth screen.**

- [ ] **Step 3: Test OTP send — verify the 60-second cooldown countdown appears after sending.**

- [ ] **Step 4: Commit**
```bash
git add lib/auth/screens/phone_auth_screen.dart
git commit -m "feat(auth): PhoneAuthScreen with country picker + 60s OTP resend cooldown"
```

---

## Task 12: Rewrite `LoginPage` — wire new screens, remove redundant code

**Files:**
- Modify: `lib/auth/login_page.dart`

Changes: remove `_checkAutoLogin()` (redundant — Firebase Auth handles session persistence), remove `_navigateToHome()` (AuthWrapper is the sole router), remove direct `AuthService` instantiation, wire the three method buttons to `Navigator.push` the new screens instead of calling dialog functions.

Keep all animations unchanged — the visual design is untouched.

- [ ] **Step 1: Remove `_checkAutoLogin` call from `initState`**

Find:
```dart
    _entranceController.forward();
    
    // Check for auto-login (Remember Me)
    _checkAutoLogin();
```
Replace with:
```dart
    _entranceController.forward();
    // Session persistence is handled by Firebase Auth natively.
    // AuthWrapper observes idTokenChanges() and routes accordingly.
```

- [ ] **Step 2: Remove the `_checkAutoLogin` method entirely**

Delete the entire `Future<void> _checkAutoLogin() async { ... }` method block from `_LoginPageState`.

- [ ] **Step 3: Remove `_navigateToHome` method entirely**

Delete the entire `void _navigateToHome() { ... }` method block.

- [ ] **Step 4: Remove direct AuthService and PhoneAuthService instantiation**

Find:
```dart
  final AuthService authService = AuthService();
  final PhoneAuthService phoneAuthService = PhoneAuthService();
```
Delete both lines. The screens use `AuthProvider` directly.

- [ ] **Step 5: Add imports for new screens at the top of `login_page.dart`**

```dart
import 'screens/email_signup_screen.dart';
import 'screens/email_login_screen.dart';
import 'screens/phone_auth_screen.dart';
```
Remove:
```dart
import 'login_dialogs.dart';
```

- [ ] **Step 6: Wire the "Sign up with email" button**

Find where `LoginDialogsHelper.showEmailSignUpDialog(...)` is called (it's inside `_showAuthMethodsWithAnimation(true)` UI block). Replace the call with:
```dart
Navigator.push(context, MaterialPageRoute(builder: (_) => const EmailSignUpScreen()));
```

- [ ] **Step 7: Wire the "Sign in with email" button**

Find where `LoginDialogsHelper.showEmailLoginDialog(...)` is called. Replace with:
```dart
Navigator.push(context, MaterialPageRoute(builder: (_) => const EmailLoginScreen()));
```

- [ ] **Step 8: Wire the "Sign in with phone" button**

Find where `LoginDialogsHelper.showPhoneSignInDialog(...)` is called. Replace with:
```dart
Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneAuthScreen()));
```

- [ ] **Step 9: Wire Google sign-in button to use `AuthProvider`**

Find where `LoginDialogsHelper.handleGoogleSignIn(...)` is called. Replace with:
```dart
setState(() => isLoading = true);
try {
  await context.read<AuthProvider>().signInWithGoogle();
  // AuthWrapper handles routing — no manual navigation
} on FirebaseAuthException catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(authErrorMessage(e),
          style: const TextStyle(fontFamily: 'Circular', color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Sign-in cancelled or failed', style: TextStyle(fontFamily: 'Circular', color: Colors.white)),
      backgroundColor: Colors.orange,
      behavior: SnackBarBehavior.floating,
    ));
  }
} finally {
  if (mounted) setState(() => isLoading = false);
}
```

Add import at top:
```dart
import 'utils/auth_error_messages.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
```

- [ ] **Step 10: Remove SharedPreferences import and all `SharedPreferences` usage from `login_page.dart`**

- [ ] **Step 11: Hot-reload. Walk through all three auth paths end to end. Confirm AuthWrapper routes correctly after each.**

- [ ] **Step 12: Commit**
```bash
git add lib/auth/login_page.dart
git commit -m "refactor(auth): LoginPage — remove manual nav + polling, wire new screens, use AuthProvider for Google"
```

---

## Task 13: Fix `HomePage` — remove manual sign-out navigation

**Files:**
- Modify: `lib/pages/home_page.dart`

- [ ] **Step 1: Find and remove the manual navigation to `LoginPage` on sign-out**

Find (around line 257):
```dart
Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (_) => const LoginPage()),
);
```

Delete these lines entirely. The sign-out call (`AuthProvider.signOut()`) will cause `idTokenChanges()` to emit null → `AuthWrapper` routes to `LoginPage` automatically.

Verify the sign-out call itself is still present (just the navigation after it gets removed):
```dart
await context.read<AuthProvider>().signOut();
// ← no Navigator call here — AuthWrapper handles it
```

- [ ] **Step 2: Hot-reload, sign out, confirm the app routes back to `LoginPage` cleanly.**

- [ ] **Step 3: Commit**
```bash
git add lib/pages/home_page.dart
git commit -m "fix(auth): remove manual LoginPage navigation on sign-out — AuthWrapper handles routing"
```

---

## Task 14: Delete `login_dialogs.dart`

**Files:**
- Delete: `lib/auth/login_dialogs.dart`

Only do this step after completing all previous tasks and verifying the app compiles cleanly.

- [ ] **Step 1: Search for any remaining imports of `login_dialogs.dart`**

```bash
grep -r "login_dialogs" lib/
```
Expected: no results. If any file still imports it, fix that file first.

- [ ] **Step 2: Delete the file**

```bash
rm lib/auth/login_dialogs.dart
```

- [ ] **Step 3: Confirm the app compiles**

```bash
flutter analyze
```
Expected: no errors referencing `login_dialogs`.

- [ ] **Step 4: Commit**
```bash
git add -A
git commit -m "chore(auth): delete login_dialogs.dart monolith — replaced by focused screen files"
```

---

## Task 15: Final audit — debug logs and SharedPreferences cleanup

**Files:**
- Search and fix across all modified files

- [ ] **Step 1: Find remaining raw `print()` calls in auth files**

```bash
grep -rn "print(" lib/auth/ lib/providers/auth_provider.dart
```
For each result: wrap in `if (kDebugMode) { debugPrint(...); }` or delete if it's noise.

- [ ] **Step 2: Find remaining SharedPreferences usage related to remember_me**

```bash
grep -rn "remember_me\|SharedPreferences" lib/auth/
```
Expected: zero results. If found, remove — Firebase Auth handles session persistence natively.

- [ ] **Step 3: Run a full Flutter analyze**

```bash
flutter analyze
```
Fix any warnings or errors.

- [ ] **Step 4: Do a full smoke test of all 3 auth paths**

```
Email sign-up → receive verification email → click link → auto-route to Home ✓
Email login (verified user) → route to Home ✓  
Email login (unverified) → route to verification screen ✓
Google sign-in → route to Home ✓
Phone OTP (with non-India country code) → OTP received → verify → route to Home ✓
Sign-out → route to LoginPage ✓
```

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore(auth): final cleanup — gate all debug prints behind kDebugMode, remove SharedPreferences remnants"
```

---

## Summary of Changes

| Was | Is Now |
|-----|--------|
| Client ID hardcoded in source | Loaded from `.env` via `flutter_dotenv` |
| `print()` everywhere | `kDebugMode`-gated `debugPrint()` only |
| Phone defaults to +91 silently | Country code picker, +91 is just the default |
| Verification polling loop (10s) | `idTokenChanges()` stream — auto-detects, instant |
| 2948-line `login_dialogs.dart` | 4 focused screen files + 3 widget/utility files |
| `LoginPage` creates its own `AuthService` | All auth goes through `AuthProvider` |
| `Navigator.pushAndRemoveUntil` in `LoginPage` | Removed — `AuthWrapper` is sole router |
| `Navigator.pushReplacement(LoginPage)` in `HomePage` | Removed — `AuthWrapper` handles it |
| No OTP rate limiting | 60s cooldown via `RateLimiter` |
| Redundant `SharedPreferences` session check | Removed — Firebase handles session natively |
