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
