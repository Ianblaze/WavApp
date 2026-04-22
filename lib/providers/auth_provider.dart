import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';

enum AuthStatus { 
  loading, 
  unauthenticated, 
  authenticated, 
  emailUnverified, 
  onboarding,
  passwordUpgradeRequired 
}

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
  
  bool get hasPendingGoogleLink =>
      _authService.pendingGoogleCredential != null;

  AuthProvider() {
    // idTokenChanges fires on: sign-in, sign-out, token refresh,
    // AND when email gets verified (token refreshes with emailVerified=true).
    _idTokenSub = _firebaseAuth.idTokenChanges().listen(_onAuthStateChanged);
  }

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

  Future<void> _checkPasswordStrength(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final verified = doc.data()?['passwordStrengthVerified'] as bool? ?? false;
      if (!verified) {
        _status = AuthStatus.passwordUpgradeRequired;
        // Don't call notifyListeners here — _onAuthStateChanged will do it
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

  // ── Google ───────────────────────────────────────────────────────
  Future<void> signInWithGoogle() => _authService.signInWithGoogle();
  
  Future<void> linkPendingGoogleCredential() =>
      _authService.linkPendingGoogleCredential();

  // ── Email ────────────────────────────────────────────────────────
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _authService.signInWithEmail(email: email, password: password);

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) => _authService.signUpWithEmailAtomic(
      email: email, password: password, username: name);
  
  Future<void> linkEmailToCurrentUser({
    required String email,
    required String password,
    required String username,
  }) => _authService.linkEmailToCurrentUser(
      email: email, password: password, username: username);

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

  Future<void> forceTokenRefresh() async {
    await _currentUser?.reload();
    final refreshed = _firebaseAuth.currentUser;
    if (refreshed != null) _onAuthStateChanged(refreshed);
  }

  // ── Password Management ──────────────────────────────────────────
  Future<void> resetPassword(String email) =>
      _authService.resetPassword(email);

  Future<void> reauthenticateWithPassword(String password) =>
      _authService.reauthenticateWithPassword(password);

  Future<void> updatePassword(String newPassword) =>
      _authService.updatePassword(newPassword);

  Future<void> updateUsername(String newName, {Map<String, dynamic>? extraUpdates}) =>
      _authService.updateUsername(newName, extraUpdates: extraUpdates);

  Future<void> deleteAccount() =>
      _authService.deleteAccount();

  // ── Sign out ─────────────────────────────────────────────────────
  Future<void> signOut() => _authService.signOut();

  @override
  void dispose() {
    _idTokenSub?.cancel();
    super.dispose();
  }
}
