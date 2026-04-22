import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import 'login_page.dart';
import '../pages/home_page.dart';
import 'screens/reauth_password_screen.dart';
import '../onboarding/onboarding_flow.dart';
import 'dart:io';

// Y2K colors from login_page.dart
const cardHotPink = Color(0xFFFFB3D9);
const cardElectricBlue = Color(0xFFB3D9FF);
const cardNeonPurple = Color(0xFFD9B3FF);
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
            return const OnboardingFlow();
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✓ Email verified successfully!',
                  style: TextStyle(fontFamily: 'Circular', color: Colors.white, fontWeight: FontWeight.w600)),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Email not verified yet. Please check your inbox.',
                  style: TextStyle(fontFamily: 'Circular', color: Colors.white, fontWeight: FontWeight.w600)),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking verification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error checking verification status',
                style: TextStyle(fontFamily: 'Circular', color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Verification email sent! Check your inbox.',
                style: TextStyle(fontFamily: 'Circular', color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: accentGlow,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error resending verification email: $e');
      if (mounted) {
        String errorMessage = 'Failed to send email';
        if (e.toString().contains('too-many-requests')) {
          errorMessage = 'Too many requests. Please wait a few minutes.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage,
                style: const TextStyle(fontFamily: 'Circular', color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
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
      backgroundColor: const Color(0xFFFCF4F9),
      body: Stack(
        children: [
          // ── Subtle Background Orbs ──────────────────────────────────────────
          _SimpleFloatingOrbs(),
          
          SafeArea(
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
                          foregroundColor: Colors.black45,
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
                        
                        // ── Premium Illustration ──────────────────────────────────────
                        Center(
                          child: Container(
                            height: h * 0.22,
                            width: w * 0.7,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Image.file(
                              // Path to the generated illustration
                              File(r'C:\Users\ian\.gemini\antigravity\brain\b062f04f-0dc2-40e0-b676-6d3de0399b7c\email_verification_illustration_1776761403695.png'),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => 
                                Icon(Icons.mark_email_unread_rounded, size: 80, color: cardHotPink.withOpacity(0.5)),
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
                            color: Colors.black87,
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
                              color: Colors.black54,
                              height: 1.5,
                            ),
                            children: [
                              const TextSpan(text: "We sent a verification link to "),
                              TextSpan(
                                text: userEmail,
                                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
                              ),
                              const TextSpan(text: ". Please click the link to verify your account."),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: h * 0.05),

                        // ── Glassmorphism Info Card ──────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildStepRow(Icons.report_rounded, "Spam folder", "Check your spam if the email hasn't arrived."),
                              const Divider(height: 32, thickness: 1, color: Colors.black12),
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
                  child: Hero(
                    tag: 'verify_btn',
                    child: Container(
                      width: double.infinity,
                      height: btnHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(btnHeight / 2),
                        gradient: const LinearGradient(colors: [cardHotPink, cardNeonPurple]),
                        boxShadow: [
                          BoxShadow(
                            color: cardHotPink.withOpacity(0.35),
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
                ),
              ],
            ),
          ),
        ],
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
            color: cardNeonPurple.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: cardNeonPurple),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontFamily: 'Circular', fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontFamily: 'Circular', fontSize: 12, color: Colors.black54, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SimpleFloatingOrbs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        Positioned(
          top: -h * 0.1,
          left: -w * 0.2,
          child: _Orb(color: cardHotPink.withOpacity(0.08), size: w * 0.8),
        ),
        Positioned(
          bottom: -h * 0.15,
          right: -w * 0.25,
          child: _Orb(color: cardNeonPurple.withOpacity(0.08), size: w * 0.9),
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        // Using a blur to create a soft orb feel
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
          ),
        ),
      ),
    );
  }
}