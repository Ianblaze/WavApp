import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:swipify/pages/home_page.dart';
import '../auth/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService authService = AuthService();
  final PhoneAuthService phoneAuthService = PhoneAuthService();
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // Logo - SVG
                    SvgPicture.asset(
                      'assets/images/wav_logo.svg',
                      width: 60,
                      height: 60,
                    ),

                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      "Millions of songs.",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const Text(
                      "Free on Swipify.",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 48),

                    // Sign up free button
                    _buildMainButton(
                      text: "Sign up free",
                      backgroundColor: const Color(0xFF1DB954),
                      textColor: Colors.black,
                      onPressed: () => _showEmailSignUpDialog(),
                    ),

                    const SizedBox(height: 12),

                    // Continue with Phone button
                    _buildSocialButton(
                      text: "Continue with phone number",
                      icon: const Icon(
                        Icons.phone_android,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () => _showPhoneSignInDialog(),
                    ),

                    const SizedBox(height: 12),

                    // Continue with Google button
                    _buildSocialButton(
                      text: "Continue with Google",
                      icon: SvgPicture.string(
                        '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                          <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
                          <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
                          <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
                          <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
                        </svg>''',
                        width: 24,
                        height: 24,
                      ),
                      onPressed: isLoading ? null : _handleGoogleSignIn,
                    ),

                    const SizedBox(height: 32),

                    // Already have an account text
                    const Text(
                      "Already have an account?",
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFA7A7A7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Log in button
                    TextButton(
                      onPressed: () => _showEmailLoginDialog(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        "Log in",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                          decorationThickness: 2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Main green button (Sign up free)
  Widget _buildMainButton({
    required String text,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(500),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  // Social login buttons (outlined, dark)
  Widget _buildSocialButton({
    required String text,
    required Widget icon,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          side: const BorderSide(
            color: Color(0xFF727272),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(500),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32),
        ),
        onPressed: onPressed,
        child: isLoading && text.contains("Google")
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // Navigate to home page helper
  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  // FIXED: Show phone sign-in dialog using PhoneAuthService
  void _showPhoneSignInDialog() {
    final phoneCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String verificationId = '';
    bool codeSent = false;
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: const Color(0xFF121212),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        codeSent ? "Enter verification code" : "Phone sign in",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (!codeSent) ...[
                    _buildDialogTextField(
                      phoneCtrl,
                      "Phone number",
                      hint: "+919876543210",
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Include country code (e.g., +91 for India)",
                      style: TextStyle(
                        color: Color(0xFFA7A7A7),
                        fontSize: 12,
                      ),
                    ),
                  ] else ...[
                    _buildDialogTextField(
                      codeCtrl,
                      "Verification code",
                      hint: "123456",
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Enter the 6-digit code sent to your phone",
                      style: TextStyle(
                        color: Color(0xFFA7A7A7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(500),
                        ),
                      ),
                      onPressed: isProcessing
                          ? null
                          : () async {
                              if (!codeSent) {
                                // Send verification code
                                final phone = phoneCtrl.text.trim();
                                if (phone.isEmpty) {
                                  _showSnackBar(
                                      "Please enter phone number", Colors.orange);
                                  return;
                                }

                                if (!phone.startsWith('+')) {
                                  _showSnackBar(
                                      "Phone number must start with country code (e.g., +91)",
                                      Colors.orange);
                                  return;
                                }

                                setDialogState(() => isProcessing = true);

                                await phoneAuthService.sendOtp(
                                  phoneNumber: phone,
                                  onCodeSent: (String verId) {
                                    verificationId = verId;
                                    setDialogState(() {
                                      codeSent = true;
                                      isProcessing = false;
                                    });
                                    _showSnackBar(
                                      "Verification code sent!",
                                      const Color(0xFF1DB954),
                                    );
                                  },
                                  onError: (String error) {
                                    setDialogState(() => isProcessing = false);
                                    _showSnackBar(error, Colors.red);
                                  },
                                );
                              } else {
                                // Verify code
                                final code = codeCtrl.text.trim();
                                if (code.isEmpty) {
                                  _showSnackBar(
                                      "Please enter verification code",
                                      Colors.orange);
                                  return;
                                }

                                if (code.length != 6) {
                                  _showSnackBar(
                                      "Verification code must be 6 digits",
                                      Colors.orange);
                                  return;
                                }

                                setDialogState(() => isProcessing = true);

                                final user = await phoneAuthService.verifyOtp(
                                  otp: code,
                                  verificationId: verificationId,
                                  onError: (String error) {
                                    setDialogState(() => isProcessing = false);
                                    _showSnackBar(error, Colors.red);
                                  },
                                );

                                if (user != null && mounted) {
                                  Navigator.pop(dialogContext);
                                  _showSnackBar(
                                    "Signed in successfully!",
                                    const Color(0xFF1DB954),
                                  );
                                  _navigateToHome(); // Navigate to home
                                } else {
                                  setDialogState(() => isProcessing = false);
                                }
                              }
                            },
                      child: isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              codeSent ? "Verify" : "Send Code",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Show email signup dialog
  void _showEmailSignUpDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Sign up to start listening",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDialogTextField(nameCtrl, "Name"),
              const SizedBox(height: 16),
              _buildDialogTextField(emailCtrl, "Email address"),
              const SizedBox(height: 16),
              _buildDialogTextField(passCtrl, "Password", isPassword: true),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(500),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _handleEmailSignUp(
                      nameCtrl.text.trim(),
                      emailCtrl.text.trim(),
                      passCtrl.text.trim(),
                    );
                  },
                  child: const Text(
                    "Sign Up",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show email login dialog
  void _showEmailLoginDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Log in to Swipify",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDialogTextField(emailCtrl, "Email address"),
              const SizedBox(height: 16),
              _buildDialogTextField(passCtrl, "Password", isPassword: true),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(500),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _handleEmailLogin(
                      emailCtrl.text.trim(),
                      passCtrl.text.trim(),
                    );
                  },
                  child: const Text(
                    "Log In",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dialog text field
  Widget _buildDialogTextField(
    TextEditingController controller,
    String label, {
    bool isPassword = false,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF121212),
            hintText: hint ?? label,
            hintStyle: const TextStyle(
              color: Color(0xFF6A6A6A),
              fontWeight: FontWeight.w400,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(
                color: Color(0xFF727272),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(
                color: Color(0xFF727272),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(
                color: Colors.white,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- GOOGLE SIGN-IN HANDLER ---
  Future<void> _handleGoogleSignIn() async {
    setState(() => isLoading = true);

    try {
      final user = await authService.signInWithGoogle();

      if (!mounted) return;

      if (user != null) {
        _showSnackBar(
            "Welcome ${user.displayName ?? 'User'}!", const Color(0xFF1DB954));
        _navigateToHome(); // Navigate to home
      } else {
        _showSnackBar("Google sign-in cancelled", Colors.orange);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnackBar(_getErrorMessage(e), Colors.red);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("An error occurred. Please try again.", Colors.red);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // --- EMAIL SIGN UP HANDLER ---
  Future<void> _handleEmailSignUp(
      String name, String email, String password) async {
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar("Please fill in all fields", Colors.orange);
      return;
    }

    if (password.length < 6) {
      _showSnackBar("Password must be at least 6 characters", Colors.orange);
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = await authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );

      if (!mounted) return;

      if (user != null) {
        _showSnackBar(
            "Account created successfully!", const Color(0xFF1DB954));
        _navigateToHome(); // Navigate to home
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnackBar(_getErrorMessage(e), Colors.red);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("An error occurred. Please try again.", Colors.red);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // --- EMAIL LOGIN HANDLER ---
  Future<void> _handleEmailLogin(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("Please fill in all fields", Colors.orange);
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = await authService.signInWithEmail(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (user != null) {
        _showSnackBar("Welcome back!", const Color(0xFF1DB954));
        _navigateToHome(); // Navigate to home
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnackBar(_getErrorMessage(e), Colors.red);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("An error occurred. Please try again.", Colors.red);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // --- SHOW SNACKBAR ---
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- GET USER-FRIENDLY ERROR MESSAGES ---
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password is too weak.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}