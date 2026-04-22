// lib/auth/screens/email_signup_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../utils/auth_exception.dart';
import '../widgets/password_requirements.dart';

const _cardHotPink = Color(0xFFFFB3D9);
const _cardNeonPurple = Color(0xFFD9B3FF);

class EmailSignUpScreen extends StatefulWidget {
  const EmailSignUpScreen({super.key});

  @override
  State<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends State<EmailSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _usernameError;
  bool _usernameChecking = false;
  bool _usernameAvailable = false;

  @override
  void dispose() {
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
      final auth = context.read<AuthProvider>();

      final existingUser = FirebaseAuth.instance.currentUser;
      final isPhoneUser = existingUser != null &&
          existingUser.providerData.any((p) => p.providerId == 'phone');

      if (isPhoneUser) {
        await auth.linkEmailToCurrentUser(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          username: username,
        );
      } else {
        await auth.signUpWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          name: username,
        );
      }

      await auth.sendVerificationEmail();
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) _showSnack(e.message, Colors.red);
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

  // ── Minimalist Hinge-Style Field Builder ──────────────────────────
  Widget _buildMinimalField({
    required String label,
    required TextEditingController controller,
    required double scaledFont,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(
        fontFamily: 'Circular',
        fontSize: scaledFont,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        letterSpacing: 0.5,
      ),
      cursorColor: _cardHotPink,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Circular',
          fontSize: scaledFont * 0.82,
          fontWeight: FontWeight.w400,
          color: Colors.black54,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: 'Circular',
          fontSize: scaledFont * 0.64,
          fontWeight: FontWeight.w700,
          color: _cardNeonPurple,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black12, width: 2),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _cardHotPink, width: 3),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent, width: 2),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent, width: 3),
        ),
        errorStyle: const TextStyle(
          fontFamily: 'Circular',
          color: Colors.redAccent,
          fontSize: 13,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final hPad = w * 0.08; // ~8% horizontal padding
    final headerFont = (w * 0.1).clamp(28.0, 44.0);
    final subFont = (w * 0.042).clamp(14.0, 18.0);
    final fieldFont = (w * 0.052).clamp(16.0, 22.0);
    final btnHeight = (h * 0.065).clamp(48.0, 56.0);

    return Scaffold(
      backgroundColor: const Color(0xFFFCF4F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: h * 0.02),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Create your\naccount.",
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
                        "Set up your profile to start matching.",
                        style: TextStyle(
                          fontFamily: 'Circular',
                          fontSize: subFont,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(height: h * 0.045),

                      _buildMinimalField(
                        label: 'Username',
                        controller: _usernameCtrl,
                        scaledFont: fieldFont,
                        onChanged: _checkUsername,
                      ),
                      if (_usernameChecking)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(children: const [
                            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54)),
                            SizedBox(width: 8),
                            Text('Checking...', style: TextStyle(color: Colors.black54, fontSize: 13, fontFamily: 'Circular')),
                          ]),
                        ),
                      if (_usernameError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_usernameError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontFamily: 'Circular')),
                        ),
                      if (_usernameAvailable && _usernameCtrl.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: const Text('✓ Available', style: TextStyle(color: Colors.green, fontSize: 13, fontFamily: 'Circular', fontWeight: FontWeight.w600)),
                        ),
                      SizedBox(height: h * 0.03),

                      _buildMinimalField(
                        label: 'Email address',
                        controller: _emailCtrl,
                        scaledFont: fieldFont,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Invalid email';
                          return null;
                        },
                      ),
                      SizedBox(height: h * 0.03),

                      _buildMinimalField(
                        label: 'Password',
                        controller: _passwordCtrl,
                        scaledFont: fieldFont,
                        obscureText: _obscure,
                        onChanged: (_) => setState(() {}),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.black45),
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
                      SizedBox(height: h * 0.015),
                      
                      PasswordRequirements(password: _passwordCtrl.text),
                      SizedBox(height: h * 0.04),
                    ],
                  ),
                ),
              ),
            ),
            
            // Fixed bottom submit button
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                height: btnHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(btnHeight / 2),
                    gradient: const LinearGradient(
                      colors: [_cardHotPink, _cardNeonPurple],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _cardHotPink.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(btnHeight / 2)),
                    ),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text('Continue', style: TextStyle(fontFamily: 'Circular', fontSize: subFont, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
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
