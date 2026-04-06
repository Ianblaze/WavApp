# Auth Edge Cases — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the auth system against 7 real-world edge cases — weak passwords after Firebase reset, account linking conflicts, username race conditions, network dropout during signup, expired OTP handling, banned user detection, and missing Firestore docs on login.

**Architecture:** All fixes live in `AuthRepository` (logic) and `AuthProvider` (state exposure). Screens receive structured error types, not raw strings, so the UI can react intelligently rather than just showing a snackbar. A new `AuthException` sealed class replaces stringly-typed error passing throughout auth.

**Tech Stack:** Flutter, Firebase Auth, Cloud Firestore (transactions + batched writes), `firebase_auth` `FirebaseAuthException` codes, Provider.

**Prerequisite:** The main auth upgrade plan (`2026-04-04-auth-upgrade-plan.md`) must be fully implemented before starting this plan. The file paths below assume that plan is complete.

---

## File Map

| Action | File | Reason |
|--------|------|--------|
| **Create** | `lib/auth/utils/auth_exception.dart` | Typed exception class replacing raw strings |
| **Modify** | `lib/auth/utils/auth_error_messages.dart` | Handle new exception codes |
| **Modify** | `lib/auth/auth_service.dart` | Atomic batch write, account linking, `getOrCreate` doc, `reauthenticate` |
| **Modify** | `lib/providers/auth_provider.dart` | Expose `reauthenticate`, `linkWithGoogle`, `resetPassword`, ban detection |
| **Modify** | `lib/providers/user_profile_provider.dart` | Sign out on doc deletion (ban detection) |
| **Modify** | `lib/auth/screens/email_signup_screen.dart` | Use batch write path; handle `account-exists-with-different-credential` |
| **Modify** | `lib/auth/screens/email_login_screen.dart` | Handle `requires-recent-login`; call `resetPassword` via `AuthProvider` |
| **Modify** | `lib/auth/screens/phone_auth_screen.dart` | Auto-reset to phone step on `session-expired` |
| **Create** | `lib/auth/screens/reauth_password_screen.dart` | In-app re-auth + forced strong password after reset |

---

## Edge Case 1: Weak password after Firebase-hosted reset

**The problem:** Firebase's password reset page has no strength requirements. A user who resets via email can end up with `abc123` as their password — completely bypassing your 8-char + uppercase + number + symbol validator.

**The fix:** After any login, check if Firebase flags the session as `requires-recent-login` (it does this when a reset was performed). If so, intercept the route and force the user through an in-app "set a new password" screen where your regex runs. This is done by catching `FirebaseAuthException` with code `requires-recent-login` on any sensitive operation, then prompting re-authentication followed by an in-app password change.

Additionally, `AuthProvider` exposes a `needsPasswordStrengthUpgrade` flag: on login with email provider, if the user's Firebase metadata shows `lastSignInTime == creationTime` it's a fresh reset — not foolproof, but a useful heuristic combined with the exception catch.

### Task 1: Create `AuthException` typed error class

**Files:**
- Create: `lib/auth/utils/auth_exception.dart`

- [ ] **Step 1: Create the file**

```dart
// lib/auth/utils/auth_exception.dart

/// Typed auth exception that screens can switch on,
/// instead of matching raw Firebase error code strings everywhere.
enum AuthErrorCode {
  weakPassword,
  emailAlreadyInUse,
  invalidEmail,
  userNotFound,
  wrongPassword,
  userDisabled,           // account banned / disabled
  tooManyRequests,
  networkError,
  invalidOtp,
  otpSessionExpired,      // OTP window expired — must resend
  requiresRecentLogin,    // password was reset via email — force reauth
  accountExistsWithDifferentCredential,  // social login collision
  unknown,
}

class AuthException implements Exception {
  final AuthErrorCode code;
  final String message;
  final Object? original;   // original FirebaseAuthException if needed

  const AuthException({
    required this.code,
    required this.message,
    this.original,
  });

  @override
  String toString() => 'AuthException(${code.name}): $message';
}
```

- [ ] **Step 2: Update `auth_error_messages.dart` to also accept `AuthException`**

In `lib/auth/utils/auth_error_messages.dart`, add a second function below the existing one:

```dart
import 'auth_exception.dart';

String authExceptionMessage(AuthException e) => e.message;
```

- [ ] **Step 3: Update `authErrorMessage` to map new codes**

In the existing `authErrorMessage(FirebaseAuthException e)` function, add these cases to the switch:

```dart
case 'requires-recent-login':
  return 'For security, please re-enter your password to continue.';
case 'account-exists-with-different-credential':
  return 'An account already exists with this email using a different sign-in method.';
case 'session-expired':
  return 'Your OTP expired. Please request a new one.';
```

- [ ] **Step 4: Commit**
```bash
git add lib/auth/utils/auth_exception.dart lib/auth/utils/auth_error_messages.dart
git commit -m "feat(auth): typed AuthException class + new Firebase error code mappings"
```

---

### Task 2: Add `reauthenticate` and `updatePassword` to `AuthRepository`

**Files:**
- Modify: `lib/auth/auth_service.dart`

- [ ] **Step 1: Add these methods to the `AuthService` class**

```dart
// lib/auth/auth_service.dart — add inside AuthService class

/// Re-authenticates the current user with their current password.
/// Required before sensitive operations (password change, account delete).
/// Throws [AuthException] with code [requiresRecentLogin] if credentials are wrong.
Future<void> reauthenticateWithPassword(String currentPassword) async {
  final user = _auth.currentUser;
  if (user == null) throw AuthException(
    code: AuthErrorCode.userNotFound,
    message: 'No signed-in user found.',
  );
  final email = user.email;
  if (email == null) throw AuthException(
    code: AuthErrorCode.invalidEmail,
    message: 'Account has no email address.',
  );
  try {
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
  } on FirebaseAuthException catch (e) {
    throw AuthException(
      code: e.code == 'wrong-password'
          ? AuthErrorCode.wrongPassword
          : AuthErrorCode.requiresRecentLogin,
      message: authErrorMessage(e),
      original: e,
    );
  }
}

/// Updates the current user's password.
/// Must call [reauthenticateWithPassword] first.
/// [newPassword] is validated against strength rules before calling Firebase.
Future<void> updatePassword(String newPassword) async {
  final user = _auth.currentUser;
  if (user == null) throw AuthException(
    code: AuthErrorCode.userNotFound,
    message: 'No signed-in user found.',
  );
  // Enforce strength rules server-side in app — Firebase has no minimum
  if (newPassword.length < 8 ||
      !newPassword.contains(RegExp(r'[A-Z]')) ||
      !newPassword.contains(RegExp(r'[0-9]')) ||
      !newPassword.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
    throw AuthException(
      code: AuthErrorCode.weakPassword,
      message: 'Password must be 8+ characters with uppercase, number, and symbol.',
    );
  }
  try {
    await user.updatePassword(newPassword);
  } on FirebaseAuthException catch (e) {
    throw AuthException(
      code: e.code == 'requires-recent-login'
          ? AuthErrorCode.requiresRecentLogin
          : AuthErrorCode.unknown,
      message: authErrorMessage(e),
      original: e,
    );
  }
}

/// Expose resetPassword via AuthService for consistency
Future<void> resetPassword(String email) async {
  try {
    await _auth.sendPasswordResetEmail(email: email);
  } on FirebaseAuthException catch (e) {
    throw AuthException(
      code: AuthErrorCode.userNotFound,
      message: authErrorMessage(e),
      original: e,
    );
  }
}
```

Add the import at the top of `auth_service.dart`:
```dart
import 'utils/auth_exception.dart';
import 'utils/auth_error_messages.dart';
```

- [ ] **Step 2: Expose these methods on `AuthProvider`**

In `lib/providers/auth_provider.dart`, add:

```dart
Future<void> reauthenticateWithPassword(String password) =>
    _authService.reauthenticateWithPassword(password);

Future<void> updatePassword(String newPassword) =>
    _authService.updatePassword(newPassword);

Future<void> resetPassword(String email) =>
    _authService.resetPassword(email);
```

- [ ] **Step 3: Fix `EmailLoginScreen` to use `AuthProvider.resetPassword` instead of direct Firebase call**

In `lib/auth/screens/email_login_screen.dart`, find `_forgotPassword()` and replace the direct Firebase call:

```dart
// REMOVE:
await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

// REPLACE WITH:
await context.read<AuthProvider>().resetPassword(email);
```

- [ ] **Step 4: Commit**
```bash
git add lib/auth/auth_service.dart lib/providers/auth_provider.dart lib/auth/screens/email_login_screen.dart
git commit -m "feat(auth): add reauthenticate + updatePassword + resetPassword to AuthRepository and AuthProvider"
```

---

### Task 3: Create `ReauthPasswordScreen` — intercept weak post-reset passwords

**Files:**
- Create: `lib/auth/screens/reauth_password_screen.dart`
- Modify: `lib/auth/auth_wrapper.dart`
- Modify: `lib/providers/auth_provider.dart`

This screen is shown when we detect a user needs to set a strong password after a Firebase-hosted reset. The flow: user tries to log in → `signInWithEmail` succeeds (Firebase doesn't block login after reset) → `AuthProvider` detects the `requiresPasswordStrengthUpgrade` condition → `AuthWrapper` routes to this screen → user enters current (weak) password to re-auth + sets a new strong one.

**How we detect the need:** On every email login, after sign-in succeeds, check if `user.metadata.lastSignInTime` is within 5 minutes of `user.metadata.creationTime` **OR** if `user.providerData` shows the password was changed recently via the reset flow. The most reliable signal is: try a sensitive operation immediately after login — if Firebase returns `requires-recent-login`, the session came from a password reset.

In practice, the simplest reliable approach: add a `passwordStrengthVerified` boolean to the user's Firestore doc, set to `true` only when they set their password through your in-app flow. On login, read this flag. If `false`, route to `ReauthPasswordScreen`.

- [ ] **Step 1: Add `passwordStrengthVerified` to the user doc on signup**

In `lib/auth/auth_service.dart`, in `signUpWithEmail`, add the field to the Firestore write:

```dart
await _db.collection('users').doc(user.uid).set({
  'name': name,
  'email': email,
  'createdAt': FieldValue.serverTimestamp(),
  'authProvider': 'email',
  'passwordStrengthVerified': true,   // set via in-app flow ✓
});
```

- [ ] **Step 2: Add `needsPasswordUpgrade` state to `AuthProvider`**

In `lib/providers/auth_provider.dart`:

```dart
// Add to class fields:
bool _needsPasswordUpgrade = false;
bool get needsPasswordUpgrade => _needsPasswordUpgrade;

// Add new AuthStatus value — modify the enum in auth_provider.dart:
// enum AuthStatus { loading, unauthenticated, authenticated, emailUnverified, passwordUpgradeRequired }
```

In `_onAuthStateChanged`, after determining the user is `authenticated` (email provider, verified), add:

```dart
// Check if this user needs to set a strong password
if (_status == AuthStatus.authenticated) {
  _checkPasswordStrength(user);
}
```

Add the check method:

```dart
Future<void> _checkPasswordStrength(User user) async {
  final providerId = user.providerData.isNotEmpty
      ? user.providerData.first.providerId
      : '';
  if (providerId != 'password') return;  // only email users

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final verified = doc.data()?['passwordStrengthVerified'] as bool? ?? false;
    if (!verified) {
      _status = AuthStatus.passwordUpgradeRequired;
      notifyListeners();
    }
  } catch (e) {
    if (kDebugMode) debugPrint('Password strength check error: $e');
  }
}

/// Called after successful in-app password update to clear the flag
Future<void> markPasswordStrengthVerified() async {
  final uid = _currentUser?.uid;
  if (uid == null) return;
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .update({'passwordStrengthVerified': true});
  // Re-evaluate auth state
  if (_currentUser != null) _onAuthStateChanged(_currentUser);
}
```

Add `FirebaseFirestore` import to `auth_provider.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
```

- [ ] **Step 3: Update `AuthWrapper` to route `passwordUpgradeRequired` status**

In `lib/auth/auth_wrapper.dart`, add a case to the switch:

```dart
case AuthStatus.passwordUpgradeRequired:
  return ReauthPasswordScreen(user: auth.currentUser!);
```

Add import:
```dart
import 'screens/reauth_password_screen.dart';
```

- [ ] **Step 4: Create `ReauthPasswordScreen`**

```dart
// lib/auth/screens/reauth_password_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' show ImageFilter;
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/auth_provider.dart';
import '../utils/auth_exception.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/password_requirements.dart';

const _cardHotPink     = Color(0xFFFFB3D9);
const _accentGlow      = Color(0xFFFF99CC);
const _cardNeonPurple  = Color(0xFFD9B3FF);
const _cardLavenderPop = Color(0xFFE6CCFF);
const _cardElectricBlue = Color(0xFFB3D9FF);

class ReauthPasswordScreen extends StatefulWidget {
  final User user;
  const ReauthPasswordScreen({super.key, required this.user});

  @override
  State<ReauthPasswordScreen> createState() => _ReauthPasswordScreenState();
}

class _ReauthPasswordScreenState extends State<ReauthPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl     = TextEditingController();

  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  String? _error;

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
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentPasswordCtrl.text;
    final newPwd  = _newPasswordCtrl.text;

    if (current.isEmpty || newPwd.isEmpty) {
      setState(() => _error = 'Please fill in both fields.');
      return;
    }
    if (newPwd.length < 8 ||
        !newPwd.contains(RegExp(r'[A-Z]')) ||
        !newPwd.contains(RegExp(r'[0-9]')) ||
        !newPwd.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      setState(() => _error = 'New password doesn\'t meet the requirements below.');
      return;
    }
    if (current == newPwd) {
      setState(() => _error = 'New password must be different from your current one.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final auth = context.read<AuthProvider>();
      // Step 1: re-authenticate with current password
      await auth.reauthenticateWithPassword(current);
      // Step 2: set new strong password (validated in AuthRepository)
      await auth.updatePassword(newPwd);
      // Step 3: mark as verified in Firestore → AuthWrapper routes to Home
      await auth.markPasswordStrengthVerified();
    } on AuthException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      if (kDebugMode) debugPrint('ReauthPasswordScreen error: $e');
      if (mounted) setState(() { _loading = false; _error = 'Something went wrong. Please try again.'; });
    }
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
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
            child: ClipRRect(
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
                      // Lock icon
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                        ),
                        child: const Icon(Icons.lock_reset_rounded, size: 32, color: Colors.white),
                      ),
                      const SizedBox(height: 24),

                      const Text('Set a strong password',
                          style: TextStyle(fontFamily: 'Circular', fontSize: 26,
                              fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 10),
                      Text(
                        'Your password was recently reset. Please confirm your current password and choose a stronger one to keep your account secure.',
                        style: TextStyle(fontFamily: 'Circular', fontSize: 14,
                            color: Colors.white.withOpacity(0.85), height: 1.5),
                      ),
                      const SizedBox(height: 28),

                      // Current password
                      AuthTextField(
                        controller: _currentPasswordCtrl,
                        hint: 'current password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscureCurrent,
                        suffixWidget: IconButton(
                          icon: Icon(_obscureCurrent
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                              color: Colors.white60, size: 20),
                          onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // New password
                      AuthTextField(
                        controller: _newPasswordCtrl,
                        hint: 'new password',
                        icon: Icons.lock_rounded,
                        obscureText: _obscureNew,
                        onChanged: (_) => setState(() {}),
                        suffixWidget: IconButton(
                          icon: Icon(_obscureNew
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                              color: Colors.white60, size: 20),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      const SizedBox(height: 12),

                      PasswordRequirements(password: _newPasswordCtrl.text),

                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.4)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!,
                                style: const TextStyle(fontFamily: 'Circular',
                                    color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500))),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity, height: 54,
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
                              : const Text('Update password',
                                  style: TextStyle(fontFamily: 'Circular',
                                      fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Center(
                        child: TextButton(
                          onPressed: _signOut,
                          child: Text('Sign out instead',
                              style: TextStyle(fontFamily: 'Circular',
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white.withOpacity(0.75))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Smoke test the full flow**
  1. Create a test account via email signup → `passwordStrengthVerified: true` in Firestore ✓
  2. Trigger a Firebase password reset email for that account → set a weak password (`abc123`) on Firebase's page
  3. Log in with `abc123` → `ReauthPasswordScreen` should appear
  4. Enter `abc123` as current, set a strong new password → routes to `HomePage` ✓
  5. Sign out, log back in with new strong password → goes directly to `HomePage` ✓

- [ ] **Step 6: Commit**
```bash
git add lib/auth/utils/auth_exception.dart \
        lib/auth/screens/reauth_password_screen.dart \
        lib/auth/auth_service.dart \
        lib/providers/auth_provider.dart \
        lib/auth/auth_wrapper.dart
git commit -m "feat(auth): intercept weak post-reset passwords with ReauthPasswordScreen"
```

---

## Edge Case 2: Account linking conflict (same email, different provider)

**The problem:** User signs up with `jane@wav.com` + email/password. Later tries Google sign-in with the same Google account. Firebase throws `account-exists-with-different-credential`. Currently this surfaces as a generic error and the user is stuck.

**The fix:** Catch that specific code in `signInWithGoogle()`. Store the pending Google credential temporarily. Tell the user "you already have an account with this email — sign in with your password to link your accounts." After they authenticate with email/password, call `linkWithCredential` to merge both providers onto one account.

### Task 4: Handle account linking in `AuthRepository`

**Files:**
- Modify: `lib/auth/auth_service.dart`

- [ ] **Step 1: Add a pending credential holder and `linkWithGoogle` method to `AuthService`**

```dart
// lib/auth/auth_service.dart — add inside AuthService class

// Holds the Google credential when account-exists conflict is detected
OAuthCredential? _pendingGoogleCredential;
OAuthCredential? get pendingGoogleCredential => _pendingGoogleCredential;

@override // Replace existing signInWithGoogle with this version
Future<User?> signInWithGoogle() async {
  final gs = _googleSignIn;
  final googleUser = await gs.signIn();
  if (googleUser == null) return null;

  final googleAuth = await googleUser.authentication;
  final credential = GoogleAuthProvider.credential(
    idToken: googleAuth.idToken,
    accessToken: googleAuth.accessToken,
  );

  try {
    final result = await _auth.signInWithCredential(credential);
    _pendingGoogleCredential = null;   // clear any previous pending
    if (result.user != null) await _saveUserToFirestore(result.user!);
    return result.user;
  } on FirebaseAuthException catch (e) {
    if (e.code == 'account-exists-with-different-credential') {
      // Store credential so we can link after email auth
      _pendingGoogleCredential = credential;
      throw AuthException(
        code: AuthErrorCode.accountExistsWithDifferentCredential,
        message: 'An account already exists with this email. Sign in with your password to link your Google account.',
        original: e,
      );
    }
    throw AuthException(
      code: AuthErrorCode.unknown,
      message: authErrorMessage(e),
      original: e,
    );
  }
}

/// Call this after reauthenticating with email/password when
/// [pendingGoogleCredential] is set. Links Google to the existing account.
Future<void> linkPendingGoogleCredential() async {
  final user = _auth.currentUser;
  final pending = _pendingGoogleCredential;
  if (user == null || pending == null) return;

  try {
    await user.linkWithCredential(pending);
    _pendingGoogleCredential = null;
    // Update Firestore to reflect linked provider
    await _db.collection('users').doc(user.uid).update({
      'linkedProviders': FieldValue.arrayUnion(['google']),
      'lastLogin': FieldValue.serverTimestamp(),
    });
  } on FirebaseAuthException catch (e) {
    throw AuthException(
      code: AuthErrorCode.unknown,
      message: authErrorMessage(e),
      original: e,
    );
  }
}
```

- [ ] **Step 2: Expose on `AuthProvider`**

```dart
// lib/providers/auth_provider.dart
bool get hasPendingGoogleLink =>
    _authService.pendingGoogleCredential != null;

Future<void> linkPendingGoogleCredential() =>
    _authService.linkPendingGoogleCredential();
```

- [ ] **Step 3: Handle the `accountExistsWithDifferentCredential` error in `LoginPage`'s Google button**

In `lib/auth/login_page.dart`, in the Google sign-in button handler, add a specific catch before the generic one:

```dart
} on AuthException catch (e) {
  if (e.code == AuthErrorCode.accountExistsWithDifferentCredential) {
    if (mounted) {
      // Route to email login screen with a flag to trigger linking after auth
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const EmailLoginScreen(
            showLinkingBanner: true,
          ),
        ),
      );
    }
  } else {
    if (mounted) _showSnack(e.message, Colors.red);
  }
}
```

- [ ] **Step 4: Update `EmailLoginScreen` to accept and handle the linking banner**

In `lib/auth/screens/email_login_screen.dart`:

Add constructor parameter:
```dart
class EmailLoginScreen extends StatefulWidget {
  final bool showLinkingBanner;
  const EmailLoginScreen({super.key, this.showLinkingBanner = false});
  ...
}
```

At the top of the `Column` in `build()`, add:
```dart
if (widget.showLinkingBanner) ...[
  Container(
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.4)),
    ),
    child: Row(children: [
      const Icon(Icons.link_rounded, color: Colors.white, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'Sign in with your password to link your Google account.',
          style: TextStyle(fontFamily: 'Circular', fontSize: 13,
              color: Colors.white.withOpacity(0.95), height: 1.4,
              fontWeight: FontWeight.w500),
        ),
      ),
    ]),
  ),
],
```

In `_submit()`, after successful sign-in, add:
```dart
// Link pending Google credential if present
final auth = context.read<AuthProvider>();
if (auth.hasPendingGoogleLink) {
  await auth.linkPendingGoogleCredential();
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Google account linked successfully!',
          style: TextStyle(fontFamily: 'Circular', color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
// AuthWrapper routes to Home — no manual navigation
```

- [ ] **Step 5: Test the flow**
  1. Sign up with `test@wav.com` + password
  2. Sign out
  3. Try Google sign-in with the same `test@wav.com` Google account
  4. Should see `EmailLoginScreen` with linking banner ✓
  5. Enter password → Google account links → routes to `HomePage` ✓

- [ ] **Step 6: Commit**
```bash
git add lib/auth/auth_service.dart lib/providers/auth_provider.dart \
        lib/auth/login_page.dart lib/auth/screens/email_login_screen.dart
git commit -m "feat(auth): account linking — handle account-exists-with-different-credential for Google sign-in"
```

---

## Edge Case 3: Username race condition

**The problem:** Two users simultaneously check `usernames/jane` → both get `exists: false` → both call `.set()`. The second write silently overwrites the first. Both users end up thinking they own the username but only the last writer actually does.

**The fix:** Wrap the username reservation in a Firestore transaction with an existence check inside the transaction itself. If the document exists when the transaction runs, throw and surface the error before the Firebase Auth account is created.

### Task 5: Atomic username + user doc write via batch transaction

**Files:**
- Modify: `lib/auth/auth_service.dart`
- Modify: `lib/auth/screens/email_signup_screen.dart`

The transaction must:
1. Check `usernames/{username}` inside the transaction (reads before writes)
2. If it exists → abort with `username-taken` error
3. If it doesn't → write `usernames/{username}` and `users/{uid}` atomically

Because Firebase transactions can't span Auth + Firestore, we create the Auth user first, then run the transaction. If the transaction fails, we delete the orphaned Auth user immediately.

- [ ] **Step 1: Add `signUpWithEmailAtomic` to `AuthService`**

```dart
// lib/auth/auth_service.dart — add to AuthService class

/// Signs up with email and atomically reserves the username.
/// If the username is taken (race condition) the Auth user is deleted
/// and an [AuthException] is thrown — no orphaned accounts.
Future<User?> signUpWithEmailAtomic({
  required String email,
  required String password,
  required String username,   // already lowercased by the caller
}) async {
  // Step 1: Create Firebase Auth user
  UserCredential result;
  try {
    result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  } on FirebaseAuthException catch (e) {
    throw AuthException(
      code: e.code == 'email-already-in-use'
          ? AuthErrorCode.emailAlreadyInUse
          : AuthErrorCode.unknown,
      message: authErrorMessage(e),
      original: e,
    );
  }

  final user = result.user!;

  // Step 2: Atomic transaction — reserve username + create user doc
  try {
    await _db.runTransaction((txn) async {
      final usernameRef = _db.collection('usernames').doc(username);
      final userRef     = _db.collection('users').doc(user.uid);

      final usernameSnap = await txn.get(usernameRef);
      if (usernameSnap.exists) {
        // Race condition — someone grabbed it between the UI check and now
        throw AuthException(
          code: AuthErrorCode.unknown,
          message: 'That username was just taken. Please choose another.',
        );
      }

      txn.set(usernameRef, {
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      txn.set(userRef, {
        'username': username,
        'email': email,
        'name': username,
        'photoUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
        'authProvider': 'email',
        'passwordStrengthVerified': true,
      });
    });

    await user.updateDisplayName(username);
    return user;
  } catch (e) {
    // Transaction failed — delete the orphaned Auth user so the email
    // can be reused and the user can try again cleanly
    try { await user.delete(); } catch (_) {}

    if (e is AuthException) rethrow;
    throw AuthException(
      code: AuthErrorCode.unknown,
      message: 'Account creation failed. Please try again.',
      original: e,
    );
  }
}
```

- [ ] **Step 2: Update `AuthProvider` to expose the atomic version**

```dart
// lib/providers/auth_provider.dart
Future<void> signUpWithEmail({
  required String email,
  required String password,
  required String name,
}) => _authService.signUpWithEmailAtomic(
    email: email, password: password, username: name);
```

(This replaces the existing `signUpWithEmail` call — same method signature on `AuthProvider`, different implementation underneath.)

- [ ] **Step 3: Simplify `EmailSignUpScreen._submit()` — remove manual Firestore writes**

The screen no longer needs to write to `usernames` or `users` itself — the repository handles it atomically. Remove these lines from `_submit()`:

```dart
// REMOVE these lines entirely from _submit():
final uid = context.read<AuthProvider>().currentUid;
if (uid != null) {
  await FirebaseFirestore.instance
      .collection('usernames')
      .doc(username)
      .set({'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
}
```

The `signUpWithEmail` call on `AuthProvider` now does everything inside a transaction.

- [ ] **Step 4: Test**
  - Normal signup → user doc and username doc both exist ✓
  - Manually create a `usernames/testuser` doc in Firestore console, then try to sign up with `testuser` → error "That username was just taken" ✓
  - Verify no orphaned Auth user is created when transaction fails (check Firebase console)

- [ ] **Step 5: Commit**
```bash
git add lib/auth/auth_service.dart lib/providers/auth_provider.dart \
        lib/auth/screens/email_signup_screen.dart
git commit -m "feat(auth): atomic username reservation via Firestore transaction — eliminates race condition"
```

---

## Edge Case 4: Network dropout during signup

**The problem:** Firebase Auth succeeds (account created) but the Firestore write fails due to network loss. On next login, `UserProfileProvider.startListening()` fires a stream that emits nothing (doc doesn't exist), so `profile` is forever `null` and the app may crash or show a broken state.

**The fix:** Already partially addressed by `signUpWithEmailAtomic` (if the transaction fails, the Auth user is deleted). But we also need a safety net on login: a `getOrCreateUserDoc` check that runs when `UserProfileProvider` receives a snapshot where `doc.exists == false`. Instead of silently ignoring it, it creates a minimal doc from the Firebase Auth user object.

### Task 6: `getOrCreate` safety net in `UserProfileProvider`

**Files:**
- Modify: `lib/providers/user_profile_provider.dart`

- [ ] **Step 1: Add `_ensureUserDoc` to `UserProfileProvider`**

```dart
// lib/providers/user_profile_provider.dart

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/foundation.dart';

// Inside UserProfileProvider class, replace startListening with:

void startListening(String uid) {
  _profileStream?.cancel();
  _profileStream = _db.collection('users').doc(uid)
      .snapshots()
      .listen((doc) async {
    if (doc.exists) {
      _profile = UserProfile.fromDoc(doc);
      notifyListeners();
    } else {
      // Doc missing — create a minimal one from Firebase Auth data
      // This handles network dropout during signup
      await _ensureUserDoc(uid);
    }
  });
}

/// Creates a minimal user doc if one doesn't exist.
/// This is a recovery path — normal signup creates the doc atomically.
Future<void> _ensureUserDoc(String uid) async {
  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) return;

  try {
    final docRef = _db.collection('users').doc(uid);
    // Double-check inside the write — another device may have created it
    await _db.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists) {
        txn.set(docRef, {
          'uid': uid,
          'username': firebaseUser.displayName ?? '',
          'email': firebaseUser.email ?? '',
          'photoUrl': firebaseUser.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'authProvider': firebaseUser.providerData.isNotEmpty
              ? firebaseUser.providerData.first.providerId
              : 'unknown',
          'passwordStrengthVerified': false,  // will trigger ReauthPasswordScreen if email user
        });
        if (kDebugMode) debugPrint('UserProfileProvider: created missing user doc for $uid');
      }
    });
  } catch (e) {
    if (kDebugMode) debugPrint('UserProfileProvider: failed to create user doc: $e');
  }
}
```

- [ ] **Step 2: Test**
  1. Manually delete the `users/{uid}` doc in Firestore console for an existing user
  2. Force a stream refresh (restart the app or sign out/in)
  3. Verify the doc is recreated and the app doesn't crash ✓

- [ ] **Step 3: Commit**
```bash
git add lib/providers/user_profile_provider.dart
git commit -m "feat(auth): getOrCreate user doc safety net — recovers from network dropout during signup"
```

---

## Edge Case 5: Expired OTP — auto-reset to phone entry step

**The problem:** The OTP has a 60-second window. If the user takes too long, Firebase returns `session-expired`. Currently the `PhoneAuthScreen` stays on the OTP input step with an error — the user can't get back to the phone number step to request a new code without pressing the back button.

**The fix:** Catch `session-expired` specifically in `verifyOtp`. Instead of just showing a snackbar, reset the screen state back to the phone entry step (`_otpSent = false`, clear the OTP field) and show a clear explanation. The user is immediately back to where they need to be.

### Task 7: Auto-reset `PhoneAuthScreen` on OTP expiry

**Files:**
- Modify: `lib/auth/screens/phone_auth_screen.dart`

- [ ] **Step 1: Update `_verifyOtp()` in `PhoneAuthScreen`**

Replace the existing `onError` callback body with:

```dart
onError: (err) {
  if (!mounted) return;
  setState(() => _loading = false);

  // Check if it's an expiry — if so, reset to phone step
  // Firebase passes the error message through; also check verificationId
  final isExpired = err.toLowerCase().contains('expired') ||
                    err.toLowerCase().contains('session');
  if (isExpired) {
    setState(() {
      _otpSent = false;
      _verificationId = null;
      _otpCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text(
        'Your OTP expired. Enter your number again to get a new one.',
        style: TextStyle(fontFamily: 'Circular', color: Colors.white, fontWeight: FontWeight.w600),
      ),
      backgroundColor: Colors.orange,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 5),
    ));
  } else {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err,
          style: const TextStyle(fontFamily: 'Circular', color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
},
```

- [ ] **Step 2: Also catch expiry in `PhoneAuthService.verifyOtp` and surface it cleanly**

In `lib/auth/auth_service.dart`, in `PhoneAuthService.verifyOtp`, the catch block already handles `session-expired` — verify the error message passed to `onError` contains the word "expired":

```dart
} on FirebaseAuthException catch (e) {
  if (kDebugMode) debugPrint('OTP verify error: ${e.code}');
  switch (e.code) {
    case 'invalid-verification-code':
      onError('Invalid OTP. Please check and try again.');
    case 'session-expired':
      onError('Your OTP session expired. Please request a new code.');  // screen detects "expired"
    default:
      onError(e.message ?? 'Verification failed. Please try again.');
  }
  return null;
}
```

- [ ] **Step 3: Test**
  - Send OTP, wait 70 seconds, enter any 6-digit code
  - Verify screen resets to phone number entry with orange snackbar ✓
  - Verify the cooldown timer has expired too so they can immediately resend ✓

- [ ] **Step 4: Commit**
```bash
git add lib/auth/screens/phone_auth_screen.dart lib/auth/auth_service.dart
git commit -m "fix(auth): auto-reset PhoneAuthScreen to phone entry step on OTP session expiry"
```

---

## Edge Case 6: Banned user detection via Firestore doc deletion

**The problem:** If a user is banned mid-session (their Firestore doc is deleted or a `banned: true` field is set by an admin), `UserProfileProvider` receives a snapshot but the app does nothing. Firebase Auth still considers them authenticated. They continue using the app.

**The fix:** When `UserProfileProvider` receives a snapshot where `doc.exists == false` after the user was previously loaded (i.e. `_profile != null`), it's a ban signal — not a network dropout. Sign the user out immediately. Similarly, check for a `banned` field on every snapshot.

### Task 8: Sign out banned users in `UserProfileProvider`

**Files:**
- Modify: `lib/providers/user_profile_provider.dart`

- [ ] **Step 1: Update `startListening` to detect ban**

```dart
// Replace startListening entirely with this version:

void startListening(String uid) {
  _profileStream?.cancel();
  _profileStream = _db.collection('users').doc(uid)
      .snapshots()
      .listen((doc) async {
    if (!doc.exists) {
      if (_profile != null) {
        // Doc was deleted AFTER profile was loaded = ban or admin action
        // Sign out — AuthWrapper will route to LoginPage
        if (kDebugMode) debugPrint('User doc deleted mid-session — signing out');
        await FirebaseAuth.instance.signOut();
      } else {
        // Doc missing on first load = network dropout recovery path
        await _ensureUserDoc(uid);
      }
      return;
    }

    final data = doc.data() as Map<String, dynamic>;

    // Check for explicit ban flag
    final isBanned = data['banned'] as bool? ?? false;
    if (isBanned) {
      if (kDebugMode) debugPrint('User is banned — signing out');
      await FirebaseAuth.instance.signOut();
      return;
    }

    _profile = UserProfile.fromDoc(doc);
    notifyListeners();
  });
}
```

Add `FirebaseAuth` import to `user_profile_provider.dart`:
```dart
import 'package:firebase_auth/firebase_auth.dart';
```

- [ ] **Step 2: Test**
  - Sign in, observe app is on `HomePage`
  - In Firestore console, set `banned: true` on the user's doc
  - App should sign out within seconds and route to `LoginPage` ✓
  - Alternatively: delete the user doc entirely → same result ✓

- [ ] **Step 3: Commit**
```bash
git add lib/providers/user_profile_provider.dart
git commit -m "feat(auth): sign out banned users automatically via Firestore doc listener"
```

---

## Edge Case 7: Phone + email account deduplication

**The problem:** A user signs up with phone (+91 99999 99999). Later they try to sign up with email using an address they consider their "main" email. Firebase creates a *second* separate account — no link, no warning. They now have two accounts and their matches/profile are split across both.

**The fix:** This is the hardest edge case because Firebase treats phone and email as entirely separate identity providers with no automatic linking. The practical solution at this stage: on email signup, after creating the Auth user, check if the same device has an active phone-auth session. If `FirebaseAuth.instance.currentUser` already exists when `signUpWithEmailAtomic` is called, the user is already signed in with phone — offer to link the email to the existing phone account instead of creating a new one.

### Task 9: Detect and link phone + email on the same device

**Files:**
- Modify: `lib/auth/auth_service.dart`
- Modify: `lib/auth/screens/email_signup_screen.dart`

- [ ] **Step 1: Add `linkEmailToCurrentUser` to `AuthService`**

```dart
// lib/auth/auth_service.dart — add to AuthService class

/// Links email/password to an existing (phone-authed) account.
/// Call this instead of [signUpWithEmailAtomic] when a user is already
/// signed in with phone and wants to add email login.
Future<User?> linkEmailToCurrentUser({
  required String email,
  required String password,
  required String username,
}) async {
  final user = _auth.currentUser;
  if (user == null) {
    throw AuthException(
      code: AuthErrorCode.userNotFound,
      message: 'No active session to link to.',
    );
  }

  try {
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    final result = await user.linkWithCredential(credential);

    // Update Firestore doc with email and mark password as verified
    await _db.collection('users').doc(user.uid).update({
      'email': email,
      'username': username,
      'linkedProviders': FieldValue.arrayUnion(['password']),
      'passwordStrengthVerified': true,
    });

    // Reserve username (in a transaction)
    await _db.runTransaction((txn) async {
      final usernameRef = _db.collection('usernames').doc(username);
      final snap = await txn.get(usernameRef);
      if (snap.exists) {
        throw AuthException(
          code: AuthErrorCode.unknown,
          message: 'That username was just taken. Please choose another.',
        );
      }
      txn.set(usernameRef, {
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return result.user;
  } on FirebaseAuthException catch (e) {
    throw AuthException(
      code: e.code == 'email-already-in-use'
          ? AuthErrorCode.emailAlreadyInUse
          : AuthErrorCode.unknown,
      message: authErrorMessage(e),
      original: e,
    );
  }
}
```

- [ ] **Step 2: Update `EmailSignUpScreen._submit()` to detect existing phone session**

At the start of `_submit()`, before calling `signUpWithEmail`, add:

```dart
final existingUser = FirebaseAuth.instance.currentUser;
final isPhoneUser = existingUser != null &&
    existingUser.providerData.any((p) => p.providerId == 'phone');

if (isPhoneUser) {
  // Link email to existing phone account — don't create a new one
  try {
    await context.read<AuthProvider>().linkEmailToCurrentUser(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      username: username,
    );
    await context.read<AuthProvider>().sendVerificationEmail();
    // AuthWrapper routes to emailUnverified or Home depending on verification status
    return;
  } on AuthException catch (e) {
    _showSnack(e.message, Colors.red);
    setState(() => _loading = false);
    return;
  }
}

// No existing session — normal signup flow
await context.read<AuthProvider>().signUpWithEmail(...);
```

- [ ] **Step 3: Expose `linkEmailToCurrentUser` on `AuthProvider`**

```dart
// lib/providers/auth_provider.dart
Future<void> linkEmailToCurrentUser({
  required String email,
  required String password,
  required String username,
}) => _authService.linkEmailToCurrentUser(
    email: email, password: password, username: username);
```

- [ ] **Step 4: Test**
  1. Sign in with phone OTP
  2. Tap "Sign up with email" from within the app (or navigate to `EmailSignUpScreen`)
  3. Complete the signup form → `linkEmailToCurrentUser` fires instead of creating new account ✓
  4. Firebase console shows one account with both phone and password providers ✓

- [ ] **Step 5: Commit**
```bash
git add lib/auth/auth_service.dart lib/providers/auth_provider.dart \
        lib/auth/screens/email_signup_screen.dart
git commit -m "feat(auth): link email/password to existing phone account instead of creating duplicate"
```

---

## Final Audit

- [ ] **Run `flutter analyze`** — zero errors, zero warnings in auth files
- [ ] **Full smoke test matrix:**

| Scenario | Expected |
|----------|----------|
| Email signup → verification link → auto-route Home | ✓ |
| Email signup → Firebase-hosted password reset with weak pwd → `ReauthPasswordScreen` | ✓ |
| Google sign-in with email that has email/password account → linking flow | ✓ |
| Same username, two users simultaneously → only first succeeds | ✓ |
| Network drops during signup → no orphaned auth user | ✓ |
| OTP expires → screen resets to phone entry step automatically | ✓ |
| Admin deletes user doc mid-session → instant sign-out | ✓ |
| Admin sets `banned: true` mid-session → instant sign-out | ✓ |
| Phone-authed user adds email → linked, not duplicated | ✓ |

- [ ] **Final commit**
```bash
git add -A
git commit -m "feat(auth): all 7 edge cases covered — auth system production-grade"
```

---

## Summary

| Edge Case | Fix |
|-----------|-----|
| Weak password after Firebase reset | `passwordStrengthVerified` Firestore flag + `ReauthPasswordScreen` intercept |
| Google/email account collision | Detect `account-exists-with-different-credential`, store pending credential, link after email auth |
| Username race condition | Firestore transaction with existence check inside transaction; orphaned Auth user deleted on failure |
| Network dropout during signup | `signUpWithEmailAtomic` deletes orphaned Auth user on transaction failure; `getOrCreate` doc recovery on login |
| Expired OTP | Catch `session-expired` in `verifyOtp`, auto-reset screen to phone entry step |
| Banned user mid-session | `UserProfileProvider` Firestore listener signs out on doc deletion or `banned: true` |
| Phone + email duplicate account | Detect existing phone session on email signup screen, call `linkWithCredential` instead |
