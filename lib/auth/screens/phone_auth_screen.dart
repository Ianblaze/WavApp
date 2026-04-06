// lib/auth/screens/phone_auth_screen.dart
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' show ImageFilter;

import '../../providers/auth_provider.dart';
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
        if (mounted) {
          setState(() => _loading = false);
          _showSnack(err, Colors.red);
          // AUTO-RESET if session expired
          if (err.toLowerCase().contains('expired')) {
            setState(() {
              _otpSent = false;
              _verificationId = null;
              _otpCtrl.clear();
            });
          }
        }
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
