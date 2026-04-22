// lib/auth/screens/reauth_password_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import '../../providers/auth_provider.dart';
import '../utils/auth_exception.dart';
import '../widgets/password_requirements.dart';

const _cardHotPink     = Color(0xFFFFB3D9);
const _cardNeonPurple  = Color(0xFFD9B3FF);

class ReauthPasswordScreen extends StatefulWidget {
  final User user;
  const ReauthPasswordScreen({super.key, required this.user});

  @override
  State<ReauthPasswordScreen> createState() => _ReauthPasswordScreenState();
}

class _ReauthPasswordScreenState extends State<ReauthPasswordScreen> {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl     = TextEditingController();

  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  String? _error;

  @override
  void dispose() {
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
      setState(() => _error = 'New password doesn\'t meet the requirements.');
      return;
    }
    if (current == newPwd) {
      setState(() => _error = 'New password must be different from current.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final auth = context.read<AuthProvider>();
      await auth.reauthenticateWithPassword(current);
      await auth.updatePassword(newPwd);
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

  Widget _buildMinimalField({
    required String label,
    required TextEditingController controller,
    required double scaledFont,
    bool obscureText = false,
    Widget? suffixIcon,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      style: TextStyle(
        fontFamily: 'Circular', fontSize: scaledFont,
        fontWeight: FontWeight.w600, color: Colors.black87, letterSpacing: 0.5,
      ),
      cursorColor: _cardHotPink,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: 'Circular', fontSize: scaledFont * 0.82, fontWeight: FontWeight.w400, color: Colors.black54),
        floatingLabelStyle: TextStyle(fontFamily: 'Circular', fontSize: scaledFont * 0.64, fontWeight: FontWeight.w700, color: _cardNeonPurple),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12, width: 2)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _cardHotPink, width: 3)),
        errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 2)),
        focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 3)),
        suffixIcon: suffixIcon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final hPad = w * 0.08;
    final headerFont = (w * 0.1).clamp(28.0, 44.0);
    final subFont = (w * 0.042).clamp(14.0, 18.0);
    final fieldFont = (w * 0.052).clamp(16.0, 22.0);
    final btnHeight = (h * 0.065).clamp(48.0, 56.0);

    return Scaffold(
      backgroundColor: const Color(0xFFFCF4F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const SizedBox.shrink(),
        actions: [
          TextButton(
            onPressed: _signOut,
            child: const Text('Sign out', style: TextStyle(fontFamily: 'Circular', fontWeight: FontWeight.w600, color: Colors.black54)),
          ),
          SizedBox(width: w * 0.04),
        ],
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
                      "Update your\npassword.",
                      style: TextStyle(
                        fontFamily: 'Circular', fontSize: headerFont,
                        fontWeight: FontWeight.w900, color: Colors.black87,
                        height: 1.1, letterSpacing: -1.0,
                      ),
                    ),
                    SizedBox(height: h * 0.012),
                    Text(
                      "Please confirm your current password and choose a stronger one.",
                      style: TextStyle(fontFamily: 'Circular', fontSize: subFont, fontWeight: FontWeight.w500, color: Colors.black54),
                    ),
                    SizedBox(height: h * 0.045),

                    _buildMinimalField(
                      label: 'Current password',
                      controller: _currentPasswordCtrl,
                      scaledFont: fieldFont,
                      obscureText: _obscureCurrent,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.black45),
                        onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                    ),
                    SizedBox(height: h * 0.03),

                    _buildMinimalField(
                      label: 'New password',
                      controller: _newPasswordCtrl,
                      scaledFont: fieldFont,
                      obscureText: _obscureNew,
                      onChanged: (_) => setState(() {}),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.black45),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    SizedBox(height: h * 0.015),
                    
                    PasswordRequirements(password: _newPasswordCtrl.text),
                    
                    if (_error != null) ...[
                      SizedBox(height: h * 0.025),
                      Container(
                        padding: EdgeInsets.all(w * 0.03),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_error!, style: TextStyle(fontFamily: 'Circular', color: Colors.redAccent, fontSize: subFont * 0.78, fontWeight: FontWeight.w500))),
                        ]),
                      ),
                    ],
                    SizedBox(height: h * 0.04),
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
                      backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(btnHeight / 2)),
                    ),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text('Update Password', style: TextStyle(fontFamily: 'Circular', fontSize: subFont, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
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
