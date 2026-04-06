// lib/auth/screens/reauth_password_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' show ImageFilter;
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import '../../providers/auth_provider.dart';
import '../utils/auth_exception.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/password_requirements.dart';

const _cardHotPink     = Color(0xFFFFB3D9);
const _accentGlow      = Color(0xFFFF99CC);
const _cardNeonPurple  = Color(0xFFD9B3FF);
const _cardLavenderPop = Color(0xFFE6CCFF);
const _cardElectricBlue = Color(0xFFB3D9FF);

class ReauthPasswordScreen extends StatefulWidget {
  final User user;
  const ReauthPasswordScreen({super.key, required this.user});

  @override
  State<ReauthPasswordScreen> createState() => _ReauthPasswordScreenState();
}

class _ReauthPasswordScreenState extends State<ReauthPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl     = TextEditingController();

  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  String? _error;

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
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentPasswordCtrl.text;
    final newPwd  = _newPasswordCtrl.text;

    if (current.isEmpty || newPwd.isEmpty) {
      setState(() => _error = 'Please fill in both fields.');
      return;
    }
    if (newPwd.length < 8 ||
        !newPwd.contains(RegExp(r'[A-Z]')) ||
        !newPwd.contains(RegExp(r'[0-9]')) ||
        !newPwd.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      setState(() => _error = 'New password doesn\'t meet the requirements below.');
      return;
    }
    if (current == newPwd) {
      setState(() => _error = 'New password must be different from your current one.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final auth = context.read<AuthProvider>();
      // Step 1: re-authenticate with current password
      await auth.reauthenticateWithPassword(current);
      // Step 2: set new strong password (validated in AuthRepository)
      await auth.updatePassword(newPwd);
      // Step 3: mark as verified in Firestore → AuthWrapper routes to Home
      await auth.markPasswordStrengthVerified();
    } on AuthException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      if (kDebugMode) debugPrint('ReauthPasswordScreen error: $e');
      if (mounted) setState(() { _loading = false; _error = 'Something went wrong. Please try again.'; });
    }
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
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
            child: ClipRRect(
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
                      // Lock icon
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                        ),
                        child: const Icon(Icons.lock_reset_rounded, size: 32, color: Colors.white),
                      ),
                      const SizedBox(height: 24),

                      const Text('Set a strong password',
                          style: TextStyle(fontFamily: 'Circular', fontSize: 26,
                              fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 10),
                      Text(
                        'Your password was recently reset. Please confirm your current password and choose a stronger one to keep your account secure.',
                        style: TextStyle(fontFamily: 'Circular', fontSize: 14,
                            color: Colors.white.withOpacity(0.85), height: 1.5),
                      ),
                      const SizedBox(height: 28),

                      // Current password
                      AuthTextField(
                        controller: _currentPasswordCtrl,
                        hint: 'current password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscureCurrent,
                        suffixWidget: IconButton(
                          icon: Icon(_obscureCurrent
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                              color: Colors.white60, size: 20),
                          onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // New password
                      AuthTextField(
                        controller: _newPasswordCtrl,
                        hint: 'new password',
                        icon: Icons.lock_rounded,
                        obscureText: _obscureNew,
                        onChanged: (_) => setState(() {}),
                        suffixWidget: IconButton(
                          icon: Icon(_obscureNew
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                              color: Colors.white60, size: 20),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      const SizedBox(height: 12),

                      PasswordRequirements(password: _newPasswordCtrl.text),

                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.4)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!,
                                style: const TextStyle(fontFamily: 'Circular',
                                    color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500))),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity, height: 54,
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
                              : const Text('Update password',
                                  style: TextStyle(fontFamily: 'Circular',
                                      fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Center(
                        child: TextButton(
                          onPressed: _signOut,
                          child: Text('Sign out instead',
                              style: TextStyle(fontFamily: 'Circular',
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white.withOpacity(0.75))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
