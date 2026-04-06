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
