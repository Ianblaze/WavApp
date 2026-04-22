// lib/auth/screens/email_login_screen.dart
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../utils/auth_exception.dart';

const _cardHotPink     = Color(0xFFFFB3D9);
const _cardNeonPurple  = Color(0xFFD9B3FF);

class EmailLoginScreen extends StatefulWidget {
  final bool showLinkingBanner;
  const EmailLoginScreen({super.key, this.showLinkingBanner = false});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
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
      _showSnack('Reset link sent to $email', _cardHotPink);
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

  Widget _buildMinimalField({
    required String label,
    required TextEditingController controller,
    required double scaledFont,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
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
        errorStyle: const TextStyle(fontFamily: 'Circular', color: Colors.redAccent, fontSize: 13),
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
                        "Welcome\nback.",
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
                        "Sign in to your account.",
                        style: TextStyle(
                          fontFamily: 'Circular',
                          fontSize: subFont,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(height: h * 0.045),

                      if (widget.showLinkingBanner) ...[
                        Container(
                          padding: EdgeInsets.all(w * 0.04),
                          margin: EdgeInsets.only(bottom: h * 0.03),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0FA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(children: [
                            const Icon(Icons.link_rounded, color: _cardNeonPurple, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Sign in with your password to link your Google account.',
                                style: TextStyle(fontFamily: 'Circular', fontSize: subFont * 0.78,
                                    color: Colors.black87, height: 1.4, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ]),
                        ),
                      ],

                      _buildMinimalField(
                        label: 'Email address',
                        controller: _emailCtrl,
                        scaledFont: fieldFont,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      SizedBox(height: h * 0.03),

                      _buildMinimalField(
                        label: 'Password',
                        controller: _passwordCtrl,
                        scaledFont: fieldFont,
                        obscureText: _obscure,
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.black45),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      SizedBox(height: h * 0.015),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: Text('Forgot password?',
                              style: TextStyle(fontFamily: 'Circular', color: _cardHotPink,
                                  fontSize: subFont * 0.78, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      SizedBox(height: h * 0.04),
                    ],
                  ),
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
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text('Sign in', style: TextStyle(fontFamily: 'Circular', fontSize: subFont, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
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
