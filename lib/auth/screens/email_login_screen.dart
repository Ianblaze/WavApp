// lib/auth/screens/email_login_screen.dart
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../utils/auth_exception.dart';
import '../widgets/auth_video_background.dart';

import '../widgets/auth_snackbar.dart';

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
          AuthSnackBar.show(context, '✓ Google account linked successfully!', isError: false);
        }
      }

      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) AuthSnackBar.show(context, e.message);
    } catch (e) {
      if (kDebugMode) debugPrint('Login error: $e');
      if (mounted) AuthSnackBar.show(context, 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      AuthSnackBar.show(context, 'Enter your email address first');
      return;
    }
    try {
      await context.read<AuthProvider>().resetPassword(email);
      AuthSnackBar.show(context, 'Reset link sent to $email', isError: false);
    } on AuthException catch (e) {
      AuthSnackBar.show(context, e.message);
    } catch (e) {
      AuthSnackBar.show(context, 'Could not send reset email');
    }
  }

  Widget _buildMinimalField({
    required String label,
    required TextEditingController controller,
    required double scaledFont,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? textInputAction,
    VoidCallback? onSubmitted,
    bool autofocus = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: (_) => onSubmitted?.call(),
      autofocus: autofocus,
      validator: validator,
      style: TextStyle(
        fontFamily: 'Circular',
        fontSize: scaledFont,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      cursorColor: _cardHotPink,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Circular', fontSize: scaledFont * 0.85,
          fontWeight: FontWeight.w400, color: Colors.white70,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: 'Circular', fontSize: scaledFont * 0.7,
          fontWeight: FontWeight.w700, color: _cardHotPink,
        ),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24, width: 1.5)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _cardHotPink, width: 2.5)),
        errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 1.5)),
        focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 2.5)),
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

    return AuthVideoBackground(
      overlayOpacity: 0.4,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
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
                              color: Colors.white,
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
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(height: h * 0.045),
  
                          if (widget.showLinkingBanner) ...[
                            Container(
                              padding: EdgeInsets.all(w * 0.04),
                              margin: EdgeInsets.only(bottom: h * 0.03),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(children: [
                                const Icon(Icons.link_rounded, color: _cardHotPink, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Sign in with your password to link your Google account.',
                                    style: TextStyle(fontFamily: 'Circular', fontSize: subFont * 0.78,
                                        color: Colors.white, height: 1.4, fontWeight: FontWeight.w500),
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
                            textInputAction: TextInputAction.next,
                            autofocus: true,
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                          SizedBox(height: h * 0.03),
  
                          _buildMinimalField(
                            label: 'Password',
                            controller: _passwordCtrl,
                            scaledFont: fieldFont,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: _submit,
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white70),
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
                  padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 16),
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
        ),
      ),
    );
  }
}
