// lib/auth/screens/phone_auth_screen.dart
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../utils/rate_limiter.dart';

const _cardHotPink     = Color(0xFFFFB3D9);
const _cardNeonPurple  = Color(0xFFD9B3FF);

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();

  String _countryCode = '+91';
  String? _verificationId;
  bool _loading = false;
  bool _otpSent = false;
  int _cooldownSeconds = 0;

  late final RateLimiter _rateLimiter;

  @override
  void initState() {
    super.initState();
    _rateLimiter = RateLimiter(
      cooldown: const Duration(seconds: 60),
      onTick: (s) { if (mounted) setState(() => _cooldownSeconds = s); },
      onReady: () { if (mounted) setState(() => _cooldownSeconds = 0); },
    );
  }

  @override
  void dispose() {
    _rateLimiter.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

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
      },
      onError: (err) {
        if (mounted) { setState(() => _loading = false); _showSnack(err, Colors.red); }
      },
    );
  }

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
          if (err.toLowerCase().contains('expired')) {
            setState(() { _otpSent = false; _verificationId = null; _otpCtrl.clear(); });
          }
        }
      },
    );
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

  Widget _buildMinimalField({
    required String label,
    required TextEditingController controller,
    required double scaledFont,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        fontFamily: 'Circular',
        fontSize: scaledFont,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
        letterSpacing: 2.0,
      ),
      cursorColor: _cardHotPink,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Circular', fontSize: scaledFont * 0.7,
          fontWeight: FontWeight.w400, color: Colors.black54, letterSpacing: 0,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: 'Circular', fontSize: scaledFont * 0.55,
          fontWeight: FontWeight.w700, color: _cardNeonPurple, letterSpacing: 0,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12, width: 2)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _cardHotPink, width: 3)),
        errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 2)),
        focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 3)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final hPad = w * 0.08;
    final headerFont = (w * 0.1).clamp(28.0, 44.0);
    final subFont = (w * 0.04).clamp(13.0, 16.0);
    final fieldFont = (w * 0.065).clamp(20.0, 28.0);
    final btnHeight = (h * 0.065).clamp(48.0, 56.0);
    final codePickerFont = (w * 0.055).clamp(18.0, 24.0);

    return Scaffold(
      backgroundColor: const Color(0xFFFCF4F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () {
            if (_otpSent) {
               setState(() { _otpSent = false; _verificationId = null; _otpCtrl.clear(); });
            } else {
               Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: h * 0.02),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _otpSent ? "My code is" : "What's your\nnumber?",
                      style: TextStyle(
                        fontFamily: 'Circular',
                        fontSize: headerFont,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        height: 1.1,
                        letterSpacing: -1.0,
                      ),
                    ),
                    SizedBox(height: h * 0.012),
                    Text(
                      _otpSent 
                        ? 'We sent a 6-digit code to $_countryCode${_phoneCtrl.text}' 
                        : 'We\'ll send a text with a code to verify your account.',
                      style: TextStyle(
                        fontFamily: 'Circular',
                        fontSize: subFont,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: h * 0.05),

                    if (!_otpSent) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.black12, width: 2)),
                            ),
                            child: CountryCodePicker(
                              onChanged: (c) => setState(() => _countryCode = c.dialCode ?? '+91'),
                              initialSelection: 'IN',
                              favorite: const ['IN', 'US', 'GB'],
                              showCountryOnly: false,
                              showOnlyCountryWhenClosed: false,
                              alignLeft: false,
                              padding: EdgeInsets.zero,
                              textStyle: TextStyle(color: Colors.black87, fontFamily: 'Circular', fontSize: codePickerFont, fontWeight: FontWeight.w600),
                              flagDecoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          SizedBox(width: w * 0.04),
                          Expanded(
                            child: _buildMinimalField(
                              label: 'Phone number',
                              controller: _phoneCtrl,
                              scaledFont: fieldFont,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (_otpSent) ...[
                      _buildMinimalField(
                        label: '6-digit OTP',
                        controller: _otpCtrl,
                        scaledFont: fieldFont,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: h * 0.025),
                      TextButton(
                        onPressed: _cooldownSeconds > 0 ? null : _sendOtp,
                        child: Text(
                          _cooldownSeconds > 0 ? 'Resend again in ${_cooldownSeconds}s' : 'Resend code',
                          style: TextStyle(
                            fontFamily: 'Circular', fontSize: subFont,
                            color: _cooldownSeconds > 0 ? Colors.black38 : _cardHotPink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                height: btnHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(btnHeight / 2),
                    gradient: const LinearGradient(colors: [_cardHotPink, _cardNeonPurple]),
                    boxShadow: [
                      BoxShadow(color: _cardHotPink.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(btnHeight / 2)),
                    ),
                    onPressed: _loading || (_cooldownSeconds > 0 && !_otpSent)
                        ? null
                        : (_otpSent ? _verifyOtp : _sendOtp),
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text(
                            _otpSent ? 'Continue' : 'Send Code',
                            style: TextStyle(fontFamily: 'Circular', fontSize: subFont + 2, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
