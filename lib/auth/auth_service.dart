import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'utils/auth_exception.dart';
import 'utils/auth_error_messages.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  GoogleSignIn get _googleSignIn => GoogleSignIn(
        scopes: ['email'],
        clientId: kIsWeb ? dotenv.env['GOOGLE_WEB_CLIENT_ID'] : null,
      );

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Holds the Google credential when account-exists conflict is detected
  OAuthCredential? _pendingGoogleCredential;
  OAuthCredential? get pendingGoogleCredential => _pendingGoogleCredential;

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

  // ── Email Sign-Up Atomic ─────────────────────────────────────────
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

  // ── Email Login ──────────────────────────────────────────────────
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        code: e.code == 'wrong-password' 
            ? AuthErrorCode.wrongPassword 
            : AuthErrorCode.unknown,
        message: authErrorMessage(e),
        original: e,
      );
    }
  }

  // ── Password Reset ───────────────────────────────────────────────
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

  // ── Re-authentication & Password Update ──────────────────────────
  Future<void> reauthenticateWithPassword(String currentPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException(
      code: AuthErrorCode.userNotFound,
      message: 'No signed-in user found.',
    );
    final email = user.email;
    if (email == null) throw const AuthException(
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

  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException(
      code: AuthErrorCode.userNotFound,
      message: 'No signed-in user found.',
    );
    
    // Enforce strength rules server-side in app — Firebase has no minimum
    if (newPassword.length < 8 ||
        !newPassword.contains(RegExp(r'[A-Z]')) ||
        !newPassword.contains(RegExp(r'[0-9]')) ||
        !newPassword.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      throw const AuthException(
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

  /// Links email/password to an existing (phone-authed) account.
  Future<User?> linkEmailToCurrentUser({
    required String email,
    required String password,
    required String username,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(
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
          throw const AuthException(
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

  // ── Update Username Atomic ───────────────────────────────────────
  Future<void> updateUsername(String newUsername, {Map<String, dynamic>? extraUpdates}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(
        code: AuthErrorCode.userNotFound,
        message: 'No active session to update.',
      );
    }

    final oldUsername = user.displayName;
    final isNameChange = oldUsername != newUsername;

    try {
      await _db.runTransaction((txn) async {
        final newNameRef = _db.collection('usernames').doc(newUsername);
        final oldNameRef = oldUsername != null && oldUsername.isNotEmpty 
            ? _db.collection('usernames').doc(oldUsername)
            : null;
        final userRef = _db.collection('users').doc(user.uid);

        if (isNameChange) {
          // Check availability of new name
          final snap = await txn.get(newNameRef);
          if (snap.exists) {
            throw const AuthException(
              code: AuthErrorCode.unknown,
              message: 'Username is already taken.',
            );
          }

          // 1. Reserve new name
          txn.set(newNameRef, {
            'uid': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // 2. Clear old name reservation
          if (oldNameRef != null) {
            txn.delete(oldNameRef);
          }
        }

        // 3. Update user document
        final finalUpdates = {
          'username': newUsername,
          'lastModified': FieldValue.serverTimestamp(),
          if (extraUpdates != null) ...extraUpdates,
        };
        txn.update(userRef, finalUpdates);
      });

      if (isNameChange) {
        await user.updateDisplayName(newUsername);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        code: AuthErrorCode.unknown,
        message: 'Failed to update username.',
        original: e,
      );
    }
  }

  // ── Delete Account Atomic ───────────────────────────────────────
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. Get username for reservation cleanup
      final snap = await _db.collection('users').doc(user.uid).get();
      final username = snap.data()?['username'] as String?;

      // 2. Create atomic batch (transaction) for cleanup
      await _db.runTransaction((txn) async {
        final userRef = _db.collection('users').doc(user.uid);
        if (username != null && username.isNotEmpty) {
          final nameRef = _db.collection('usernames').doc(username);
          txn.delete(nameRef);
        }
        txn.delete(userRef);
      });

      // 3. Finally delete the Auth user
      await user.delete();

    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const AuthException(
          code: AuthErrorCode.requiresRecentLogin,
          message: 'For security, please sign in again before deleting your account.',
        );
      }
      throw AuthException(
        code: AuthErrorCode.unknown,
        message: authErrorMessage(e),
        original: e,
      );
    } catch (e) {
      throw AuthException(
        code: AuthErrorCode.unknown,
        message: 'Account deletion failed.',
        original: e,
      );
    }
  }

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
        'authProvider': user.providerData.isNotEmpty 
            ? user.providerData.first.providerId 
            : 'unknown',
        'passwordStrengthVerified': true, // set via in-app flow ✓
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
        onError(authErrorMessage(e));
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
      switch (e.code) {
        case 'invalid-verification-code':
          onError('Invalid OTP. Please check and try again.');
        case 'session-expired':
          onError('Your OTP session expired. Please request a new code.');
        default:
          onError(e.message ?? 'Verification failed. Please try again.');
      }
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