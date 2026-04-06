// lib/auth/screens/email_signup_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' show ImageFilter;

import '../../providers/auth_provider.dart';
import '../utils/auth_error_messages.dart';
import '../utils/auth_exception.dart';
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
      final auth = context.read<AuthProvider>();

      // EDGE CASE: Detect existing phone session on this device
      final existingUser = FirebaseAuth.instance.currentUser;
      final isPhoneUser = existingUser != null &&
          existingUser.providerData.any((p) => p.providerId == 'phone');

      if (isPhoneUser) {
        // Link email to existing phone account — don't create a new one
        await auth.linkEmailToCurrentUser(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          username: username,
        );
      } else {
        // Normal signup flow (atomic)
        await auth.signUpWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          name: username,
        );
      }

      // Send verification email
      await auth.sendVerificationEmail();
      
      // Auth stream fires → AuthWrapper routes to emailUnverified screen
      // Pop back so AuthWrapper takes over
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
