// lib/auth/screens/email_login_screen.dart
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' show ImageFilter;

import '../../providers/auth_provider.dart';
import '../utils/auth_error_messages.dart';
import '../utils/auth_exception.dart';
import '../widgets/auth_text_field.dart';

const _cardHotPink     = Color(0xFFFFB3D9);
const _accentGlow      = Color(0xFFFF99CC);
const _cardNeonPurple  = Color(0xFFD9B3FF);
const _cardLavenderPop = Color(0xFFE6CCFF);
const _cardElectricBlue = Color(0xFFB3D9FF);

class EmailLoginScreen extends StatefulWidget {
  final bool showLinkingBanner;
  const EmailLoginScreen({super.key, this.showLinkingBanner = false});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

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
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      // EDGE CASE: Link pending Google credential if present
      if (auth.hasPendingGoogleLink) {
        await auth.linkPendingGoogleCredential();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✓ Google account linked successfully!',
                style: TextStyle(fontFamily: 'Circular', color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ));
        }
      }

      // AuthWrapper listens to idTokenChanges() → routes to Home or emailUnverified automatically
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) _showSnack(e.message, Colors.red);
    } catch (e) {
      if (kDebugMode) debugPrint('Login error: $e');
      if (mounted) _showSnack('Something went wrong. Try again.', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Enter your email address first', Colors.orange);
      return;
    }
    try {
      await context.read<AuthProvider>().resetPassword(email);
      _showSnack('Reset link sent to $email', _accentGlow);
    } on AuthException catch (e) {
      _showSnack(e.message, Colors.red);
    } catch (e) {
      _showSnack('Could not send reset email', Colors.red);
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
                            const Text('Welcome back',
                                style: TextStyle(fontFamily: 'Circular', fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(height: 8),
                            Text('Sign in to your account',
                                style: TextStyle(fontFamily: 'Circular', fontSize: 15, color: Colors.white.withOpacity(0.8))),
                            const SizedBox(height: 28),

                            AuthTextField(
                              controller: _emailCtrl,
                              hint: 'email address',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 14),

                            AuthTextField(
                              controller: _passwordCtrl,
                              hint: 'password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscure,
                              suffixWidget: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: Colors.white60, size: 20),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 8),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _forgotPassword,
                                child: Text('Forgot password?',
                                    style: TextStyle(fontFamily: 'Circular', color: Colors.white.withOpacity(0.85),
                                        fontSize: 13, fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.white.withOpacity(0.85))),
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
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const SizedBox(width: 22, height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: _cardHotPink))
                                    : const Text('Sign in',
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
