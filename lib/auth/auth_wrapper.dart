import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import 'login_page.dart';
import '../pages/home_page.dart';
import 'screens/reauth_password_screen.dart';
import '../onboarding/onboarding_flow.dart';
import 'widgets/auth_video_background.dart';

import 'widgets/auth_snackbar.dart';

// Y2K colors from login_page.dart
const cardHotPink = Color(0xFFFF3399);
const cardElectricBlue = Color(0xFFB3D9FF);
const cardNeonPurple = Color(0xFF9D50BB);
const cardCyberPink = Color(0xFFFFCCE6);
const cardDigitalBlue = Color(0xFFCCE6FF);
const cardLavenderPop = Color(0xFFE6CCFF);
const accentGlow = Color(0xFFFF99CC);

/// This widget wraps your app and checks authentication + email verification
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.loading:
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          case AuthStatus.unauthenticated:
            Future.microtask(() {
              context.read<UserProfileProvider>().stopListening();
            });
            return const LoginPage();
          case AuthStatus.emailUnverified:
            return EmailVerificationRequiredScreen(user: auth.currentUser!);
          case AuthStatus.onboarding:
            Future.microtask(() {
              context.read<UserProfileProvider>().startListening(auth.currentUid!);
            });
            return const AuthVideoBackground(
              overlayOpacity: 0.3,
              child: OnboardingFlow(),
            );
          case AuthStatus.passwordUpgradeRequired:
            return ReauthPasswordScreen(user: auth.currentUser!);
          case AuthStatus.authenticated:
            Future.microtask(() {
              context.read<UserProfileProvider>()
                  .startListening(auth.currentUid!);
            });
            return const HomePage();
        }
      },
    );
  }
}

/// Screen shown to users who haven't verified their email yet
class EmailVerificationRequiredScreen extends StatefulWidget {
  final dynamic user;

  const EmailVerificationRequiredScreen({
    super.key,
    required this.user,
  });

  @override
  State<EmailVerificationRequiredScreen> createState() =>
      _EmailVerificationRequiredScreenState();
}

class _EmailVerificationRequiredScreenState
    extends State<EmailVerificationRequiredScreen> {
  bool _isResending = false;
  bool _isChecking = false;

  Future<void> _checkEmailVerification() async {
    setState(() => _isChecking = true);

    try {
      await context.read<AuthProvider>().forceTokenRefresh();
      
      final auth = context.read<AuthProvider>();
      if (auth.status == AuthStatus.authenticated) {
        if (mounted) {
          AuthSnackBar.show(context, '✓ Email verified successfully!', isError: false);
        }
      } else {
        if (mounted) {
          AuthSnackBar.show(context, 'Email not verified yet. Please check your inbox.');
        }
      }
    } catch (e) {
      debugPrint('Error checking verification: $e');
      if (mounted) {
        AuthSnackBar.show(context, 'Error checking verification status');
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _isResending = true);

    try {
      await context.read<AuthProvider>().sendVerificationEmail();
      debugPrint('✅ Verification email resent');

      if (mounted) {
        AuthSnackBar.show(context, 'Verification email sent! Check your inbox.', isError: false);
      }
    } catch (e) {
      debugPrint('❌ Error resending verification email: $e');
      if (mounted) {
        String errorMessage = 'Failed to send email';
        if (e.toString().contains('too-many-requests')) {
          errorMessage = 'Too many requests. Please wait a few minutes.';
        }
        AuthSnackBar.show(context, errorMessage);
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final userEmail = auth.currentUser?.email ?? '';
    
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final hPad = w * 0.08;
    final headerFont = (w * 0.1).clamp(28.0, 42.0);
    final subFont = (w * 0.04).clamp(14.0, 17.0);
    final btnHeight = (h * 0.065).clamp(48.0, 56.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: AuthVideoBackground(
        overlayOpacity: 0.4,
        child: SafeArea(
          child: Column(
            children: [
              // ── Header Actions ──────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _signOut,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Sign out', 
                        style: TextStyle(fontFamily: 'Circular', fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
  
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: h * 0.02),
                      
                      // ── Premium Icon Illustration ─────────────────────────────────
                      Center(
                        child: Container(
                          height: h * 0.18,
                          width: h * 0.18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [cardHotPink.withOpacity(0.2), cardNeonPurple.withOpacity(0.2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_rounded, 
                            size: 64, 
                            color: Colors.white,
                          ),
                        ),
                      ),
                      
                      SizedBox(height: h * 0.04),
  
                      Text(
                        "Check your\ninbox.",
                        style: TextStyle(
                          fontFamily: 'Circular',
                          fontSize: headerFont,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.05,
                          letterSpacing: -1.2,
                        ),
                      ),
                      
                      SizedBox(height: h * 0.015),
                      
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Circular',
                            fontSize: subFont,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: "We sent a verification link to "),
                            TextSpan(
                              text: userEmail,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(text: ". Please click the link to verify your account."),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: h * 0.05),
  
                      // ── Info Card ──────────────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white10, width: 1.5),
                        ),
                        child: Column(
                          children: [
                            _buildStepRow(Icons.report_rounded, "Spam folder", "Check your spam if the email hasn't arrived."),
                            const Divider(height: 32, thickness: 1, color: Colors.white10),
                            _buildStepRow(Icons.timer_rounded, "Be patient", "It can take up to 2 minutes for the link to arrive."),
                          ],
                        ),
                      ),
  
                      SizedBox(height: h * 0.03),
  
                      Center(
                        child: TextButton(
                          onPressed: _isResending ? null : _resendVerificationEmail,
                          style: TextButton.styleFrom(
                            foregroundColor: cardHotPink,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: _isResending
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cardHotPink))
                              : const Text('Resend verification email', 
                                  style: TextStyle(fontFamily: 'Circular', fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // ── Primary Action Button ──────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, MediaQuery.of(context).padding.bottom + 16),
                child: Container(
                  width: double.infinity,
                  height: btnHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(btnHeight / 2),
                    gradient: const LinearGradient(colors: [cardHotPink, cardNeonPurple]),
                    boxShadow: [
                      BoxShadow(
                        color: cardHotPink.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(btnHeight / 2)),
                    ),
                    onPressed: _isChecking ? null : _checkEmailVerification,
                    child: _isChecking
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('I\'ve verified my email', 
                            style: TextStyle(fontFamily: 'Circular', fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: Colors.white70),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontFamily: 'Circular', fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontFamily: 'Circular', fontSize: 12, color: Colors.white60, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
