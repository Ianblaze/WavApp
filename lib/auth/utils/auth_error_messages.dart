// lib/auth/utils/auth_error_messages.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_exception.dart';

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
      return 'Your OTP expired. Please request a new one.';
    case 'requires-recent-login':
      return 'For security, please re-enter your password to continue.';
    case 'account-exists-with-different-credential':
      return 'An account already exists with this email using a different sign-in method.';
    default:
      return e.message ?? 'Something went wrong. Please try again.';
  }
}

String authExceptionMessage(AuthException e) => e.message;
