import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_service.dart';
import 'dart:ui' show ImageFilter;
import 'dart:async';

// Import colors from login_page
const cardHotPink = Color(0xFFFFB3D9);
const cardElectricBlue = Color(0xFFB3D9FF);
const cardNeonPurple = Color(0xFFD9B3FF);
const cardCyberPink = Color(0xFFFFCCE6);
const cardDigitalBlue = Color(0xFFCCE6FF);
const cardLavenderPop = Color(0xFFE6CCFF);
const accentGlow = Color(0xFFFF99CC);
const textDark = Color(0xFF1A0D26);

class LoginDialogsHelper {
  // ============================================================================
  // USERNAME AVAILABILITY CHECKER
  // ============================================================================
  static Timer? _usernameDebounce;
  
  static Future<Map<String, dynamic>> checkUsernameAvailability(String username) async {
    // Validate username format
    if (username.isEmpty) {
      return {'available': false, 'error': 'Username cannot be empty'};
    }
    
    if (username.length < 3) {
      return {'available': false, 'error': 'Username must be at least 3 characters'};
    }
    
    if (username.length > 20) {
      return {'available': false, 'error': 'Username must be 20 characters or less'};
    }
    
    // Only allow lowercase letters, numbers, and underscores
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      return {'available': false, 'error': 'Only lowercase letters, numbers, and _ allowed'};
    }
    
    // Check if username exists in Firestore
    try {
      print('🔍 Checking username: $username');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(username) // Already lowercase from input
          .get();
      
      print('📊 Username exists: ${snapshot.exists}');
      
      if (snapshot.exists) {
        return {'available': false, 'error': 'Username already taken'};
      }
      
      return {'available': true, 'error': null};
    } on FirebaseException catch (e) {
      print('❌ Firestore Error: ${e.code} - ${e.message}');
      
      if (e.code == 'permission-denied') {
        return {
          'available': false, 
          'error': 'Setup required - Check Firebase rules'
        };
      }
      
      return {'available': false, 'error': 'Connection error'};
    } catch (e) {
      print('❌ Error checking username: $e');
      return {'available': false, 'error': 'Error checking availability'};
    }
  }

  // ============================================================================
  // GOOGLE SIGN IN HANDLER
  // ============================================================================
  static Future<void> handleGoogleSignIn({
    required BuildContext context,
    required AuthService authService,
    required Function(bool) onLoadingChanged,
    required VoidCallback onNavigateHome,
  }) async {
    onLoadingChanged(true);

    try {
      final user = await authService.signInWithGoogle();

      if (!context.mounted) return;

      if (user != null) {
        _showSnackBar(
          context,
          "Welcome ${user.displayName ?? 'User'}!",
          accentGlow,
        );
        onNavigateHome();
      } else {
        _showSnackBar(context, "Google sign-in cancelled", Colors.orange);
      }
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      _showSnackBar(context, _getErrorMessage(e), Colors.red);
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBar(context, "An error occurred. Please try again.", Colors.red);
    } finally {
      if (context.mounted) {
        onLoadingChanged(false);
      }
    }
  }

  // ============================================================================
  // EMAIL SIGN UP HANDLER
  // ============================================================================
  static Future<void> _handleEmailSignUp({
    required BuildContext context,
    required BuildContext dialogContext,
    required String name,
    required String email,
    required String password,
    required AuthService authService,
    required Function(bool) onLoadingChanged,
    required AnimationController floatingController,
    required Animation<double> floatingAnimation,
    required VoidCallback onNavigateHome,
  }) async {
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar(context, "Please fill in all fields", Colors.orange);
      return;
    }
    
    // Convert username to lowercase for checking
    final lowercaseUsername = name.toLowerCase();
    
    // Validate username before proceeding
    final usernameCheck = await checkUsernameAvailability(lowercaseUsername);
    if (!usernameCheck['available']) {
      _showSnackBar(context, usernameCheck['error'] ?? "Username not available", Colors.red);
      onLoadingChanged(false);
      return;
    }

    if (password.length < 8) {
      _showSnackBar(context, "Password must be at least 8 characters", Colors.orange);
      return;
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      _showSnackBar(
          context, "Password must contain at least one uppercase letter", Colors.orange);
      return;
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      _showSnackBar(context, "Password must contain at least one number", Colors.orange);
      return;
    }

    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      _showSnackBar(
          context, "Password must contain at least one special character", Colors.orange);
      return;
    }

    onLoadingChanged(true);

    try {
      final user = await authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
      
      // Store username in Firestore to reserve it
      if (user != null) {
        try {
          final lowercaseUsername = name.toLowerCase();
          
          await FirebaseFirestore.instance
              .collection('usernames')
              .doc(lowercaseUsername) // Store as lowercase
              .set({
            'uid': user.uid,
            'username': lowercaseUsername, // Store lowercase
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          // Also store in user profile
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'username': lowercaseUsername, // Store lowercase
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          print('✅ Username "$lowercaseUsername" reserved for user ${user.uid}');
        } catch (e) {
          print('❌ Error storing username: $e');
        }
      }

      if (!context.mounted) return;

      if (user != null) {
        // Send verification email with better error handling
        try {
          print('🔄 Starting email verification process...');
          print('📧 Email: $email');
          print('👤 User UID: ${user.uid}');
          print('✅ User email verified status: ${user.emailVerified}');
          
          await user.sendEmailVerification();
          
          print('✅ sendEmailVerification() completed successfully');
          print('📬 Verification email should be sent to: ${user.email}');
          print('⏰ Please check inbox and spam folder');

          onLoadingChanged(false);
          
          // Close signup dialog first
          if (dialogContext.mounted) {
            Navigator.pop(dialogContext);
          }
          
          // Then show verification dialog
          if (context.mounted) {
            showEmailVerificationDialog(
              context: context,
              email: email,
              floatingController: floatingController,
              floatingAnimation: floatingAnimation,
              onNavigateHome: onNavigateHome,
            );
          }
        } catch (emailError) {
          print('❌ ========================================');
          print('❌ FAILED TO SEND VERIFICATION EMAIL');
          print('❌ Error type: ${emailError.runtimeType}');
          print('❌ Error message: $emailError');
          print('❌ ========================================');

          // Still show the dialog but with a warning
          onLoadingChanged(false);

          _showSnackBar(
            context,
            "Account created! Please check if you received the verification email.",
            Colors.orange,
          );

          // Close signup dialog first
          if (dialogContext.mounted) {
            Navigator.pop(dialogContext);
          }

          // Show the dialog anyway so user can resend
          if (context.mounted) {
            showEmailVerificationDialog(
              context: context,
              email: email,
              floatingController: floatingController,
              floatingAnimation: floatingAnimation,
              onNavigateHome: onNavigateHome,
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      _showSnackBar(context, _getErrorMessage(e), Colors.red);
      onLoadingChanged(false);
    } catch (e) {
      if (!context.mounted) return;
      print('❌ General Error: $e');
      _showSnackBar(context, "An error occurred. Please try again.", Colors.red);
      onLoadingChanged(false);
    }
  }

  // ============================================================================
  // EMAIL LOGIN HANDLER
  // ============================================================================
  static Future<void> _handleEmailLogin({
    required BuildContext context,
    required BuildContext dialogContext,
    required String email,
    required String password,
    required AuthService authService,
    required Function(bool) onLoadingChanged,
    required VoidCallback onNavigateHome,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      _showSnackBar(context, "Please fill in all fields", Colors.orange);
      return;
    }

    onLoadingChanged(true);

    try {
      final user = await authService.signInWithEmail(
        email: email,
        password: password,
      );

      if (!context.mounted) return;

      if (user != null) {
        // Check if email is verified
        await user.reload(); // Refresh user data
        final currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser != null && !currentUser.emailVerified) {
          // Email not verified - close login dialog and show error
          onLoadingChanged(false);
          
          if (dialogContext.mounted) {
            Navigator.pop(dialogContext); // Close login dialog
          }
          
          // Wait a moment for dialog to close
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (context.mounted) {
            showEmailNotVerifiedDialog(context: context, email: email);
          }
        } else {
          // Email verified - proceed to home
          if (dialogContext.mounted) {
            Navigator.pop(dialogContext); // Close login dialog
          }
          
          if (context.mounted) {
            _showSnackBar(context, "Welcome back!", accentGlow);
          }
          onNavigateHome();
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      _showSnackBar(context, _getErrorMessage(e), Colors.red);
      onLoadingChanged(false);
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBar(context, "An error occurred. Please try again.", Colors.red);
      onLoadingChanged(false);
    }
  }

  // ============================================================================
  // EMAIL VERIFICATION CHECKER (10 second polling)
  // ============================================================================
  static Future<void> _checkEmailVerificationAndLogin({
    required BuildContext context,
    required BuildContext dialogContext,
    required VoidCallback onNavigateHome,
    required VoidCallback onResetToCards,
  }) async {
    // Show loading overlay in dialog
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (loadingContext) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(cardHotPink),
              ),
              const SizedBox(height: 16),
              const Text(
                "Checking verification...",
                style: TextStyle(
                  fontFamily: 'Circular',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Poll for verification status for 10 seconds
    final startTime = DateTime.now();
    bool isVerified = false;
    
    print('🔄 Starting verification check...');
    print('⏰ Will check for 10 seconds');
    
    while (DateTime.now().difference(startTime).inSeconds < 10) {
      try {
        final elapsed = DateTime.now().difference(startTime).inSeconds;
        print('⏱️  Checking... (${elapsed}s elapsed)');
        
        // Reload user to get latest verification status
        await FirebaseAuth.instance.currentUser?.reload();
        final user = FirebaseAuth.instance.currentUser;
        
        print('👤 User: ${user?.email}');
        print('✅ Email verified: ${user?.emailVerified}');
        
        if (user != null && user.emailVerified) {
          isVerified = true;
          print('🎉 VERIFICATION DETECTED! Breaking loop.');
          break;
        }
        
        // Wait 1 second before checking again
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        print('❌ Error checking verification: $e');
      }
    }
    
    print('⏹️  Verification check complete. Result: $isVerified');

    // Close loading dialog
    if (dialogContext.mounted) {
      print('🔄 Closing loading dialog...');
      Navigator.pop(dialogContext); // Close loading
    }

    if (isVerified) {
      // SUCCESS - Email verified!
      print('✅ SUCCESS PATH - Email is verified!');
      
      if (dialogContext.mounted) {
        print('🔄 Closing verification dialog...');
        Navigator.pop(dialogContext); // Close verification dialog
      }
      
      // Wait a moment for dialog to close
      await Future.delayed(const Duration(milliseconds: 100));
      
      print('📢 Showing success snackbar...');
      // Show snackbar if context is available
      if (context.mounted) {
        _showSnackBar(
          context,
          "✓ Verified successfully!",
          Colors.green,
        );
      }
      
      print('🏠 Calling onNavigateHome...');
      // Call navigation - the callback has its own context from LoginPage
      print('🏠 Calling onNavigateHome...');
      // Call navigation - the callback has its own context from LoginPage
      onNavigateHome();
      print('✅ onNavigateHome called!');
    } else {
      // FAILED - Not verified after 10 seconds
      print('❌ FAILURE PATH - Email not verified after 10s');
      
      // Show error dialog with Y2K theme
      print('📢 Showing verification failed dialog...');
      
      if (dialogContext.mounted) {
        showDialog(
          context: dialogContext,
          barrierDismissible: true,
          barrierColor: Colors.black.withOpacity(0.7),
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(maxWidth: 340),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cardHotPink.withOpacity(0.95),
                    cardNeonPurple.withOpacity(0.9),
                    cardLavenderPop.withOpacity(0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentGlow.withOpacity(0.4),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mail_outline_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    SizedBox(height: 20),
                    
                    // Title
                    Text(
                      'Not Verified Yet',
                      style: TextStyle(
                        fontFamily: 'Circular',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    
                    // Message
                    Text(
                      'Please check your inbox and spam folder, then click "I\'ve Verified" again.',
                      style: TextStyle(
                        fontFamily: 'Circular',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    
                    // Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: cardHotPink,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          'OK, I\'ll check',
                          style: TextStyle(
                            fontFamily: 'Circular',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
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
        print('✅ Error dialog shown');
      } else {
        print('❌ Context not mounted, cannot show dialog');
      }
      
      // User stays on verification dialog and can:
      // 1. Click "I've Verified" again
      // 2. Click "Resend email"
      // 3. Close the dialog manually if they want
      
      print('ℹ️  User can try again or close dialog manually');
    }
  }

  // ============================================================================
  // PHONE SIGN IN DIALOG
  // ============================================================================
  static void showPhoneSignInDialog({
    required BuildContext context,
    required AnimationController floatingController,
    required Animation<double> floatingAnimation,
    required PhoneAuthService phoneAuthService,
    required VoidCallback onNavigateHome,
  }) {
    final phoneCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String verificationId = '';
    bool codeSent = false;
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext dialogContext) => MediaQuery(
        data: MediaQuery.of(dialogContext).copyWith(
          viewInsets: EdgeInsets.zero,  // ✅ Ignore keyboard - overlay instead
        ),
        child: StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440, maxHeight: 500),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 60,
                        offset: const Offset(0, 20),
                        spreadRadius: -10,
                      ),
                      BoxShadow(
                        color: cardElectricBlue.withOpacity(0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Animated color mesh gradient background
                      AnimatedBuilder(
                        animation: floatingController,
                        builder: (context, child) {
                          final offset = floatingAnimation.value / 50;
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              gradient: LinearGradient(
                                begin: Alignment(offset, -1.0 + offset),
                                end: Alignment(-offset, 1.0 - offset),
                                colors: [
                                  cardDigitalBlue.withOpacity(0.85),
                                  cardElectricBlue.withOpacity(0.75),
                                  cardHotPink.withOpacity(0.6),
                                  cardNeonPurple.withOpacity(0.7),
                                  cardLavenderPop.withOpacity(0.65),
                                  accentGlow.withOpacity(0.6),
                                ],
                                stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                              ),
                            ),
                          );
                        },
                      ),
                      // Content with scroll
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                              child: Stack(
                                children: [
                                  // Centered title
                                  Center(
                                    child: Text(
                                      codeSent ? "Verify your number" : "Phone Sign In",
                                      style: const TextStyle(
                                        fontFamily: 'Circular',
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  // Close button positioned with proper spacing
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => Navigator.pop(dialogContext),
                                          borderRadius: BorderRadius.circular(10),
                                          child: Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Icon(
                                              Icons.close_rounded,
                                              color: Colors.white.withOpacity(0.9),
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Content
                            Padding(
                              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!codeSent) ...[
                                    _buildModernTextField(
                                      phoneCtrl,
                                      "Phone number",
                                      hint: "+91 98765 43210",
                                      icon: Icons.phone_outlined,
                                      keyboardType: TextInputType.phone,
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.info_outline,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              "Include country code (e.g., +91)",
                                              style: TextStyle(
                                                fontFamily: 'Circular',
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    _buildModernTextField(
                                      codeCtrl,
                                      "Verification code",
                                      hint: "000000",
                                      icon: Icons.lock_outline,
                                      keyboardType: TextInputType.number,
                                      maxLength: 6,
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.mark_email_read_outlined,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              "Check your messages for the 6-digit code",
                                              style: TextStyle(
                                                fontFamily: 'Circular',
                                                color: Colors.white.withOpacity(0.9),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),

                                  // Action button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: cardElectricBlue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 8,
                                        shadowColor: Colors.black.withOpacity(0.3),
                                      ),
                                      onPressed: isProcessing
                                          ? null
                                          : () async {
                                              if (!codeSent) {
                                                final phone = phoneCtrl.text.trim();
                                                if (phone.isEmpty) {
                                                  _showSnackBar(context, "Please enter phone number",
                                                      Colors.orange);
                                                  return;
                                                }

                                                if (!phone.startsWith('+')) {
                                                  _showSnackBar(
                                                      context,
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
                                                      context,
                                                      "Verification code sent!",
                                                      accentGlow,
                                                    );
                                                  },
                                                  onError: (String error) {
                                                    setDialogState(() => isProcessing = false);
                                                    _showSnackBar(context, error, Colors.red);
                                                  },
                                                );
                                              } else {
                                                final code = codeCtrl.text.trim();
                                                if (code.isEmpty) {
                                                  _showSnackBar(context,
                                                      "Please enter verification code", Colors.orange);
                                                  return;
                                                }

                                                if (code.length != 6) {
                                                  _showSnackBar(
                                                      context,
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
                                                    _showSnackBar(context, error, Colors.red);
                                                  },
                                                );

                                                if (user != null && context.mounted) {
                                                  Navigator.pop(dialogContext);
                                                  _showSnackBar(
                                                    context,
                                                    "Signed in successfully!",
                                                    accentGlow,
                                                  );
                                                  onNavigateHome();
                                                } else {
                                                  setDialogState(() => isProcessing = false);
                                                }
                                              }
                                            },
                                      child: isProcessing
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: cardElectricBlue,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  codeSent ? "Verify code" : "Send code",
                                                  style: const TextStyle(
                                                    fontFamily: 'Circular',
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),  // MediaQuery (keyboard overlay)
      ),
    );
  }

  // ============================================================================
  // EMAIL SIGN UP DIALOG
  // ============================================================================
  static void showEmailSignUpDialog({
    required BuildContext context,
    required AnimationController floatingController,
    required Animation<double> floatingAnimation,
    required AuthService authService,
    required Function(bool) onLoadingChanged,
    required VoidCallback onNavigateHome,
    required bool hasMinLength,
    required bool hasUppercase,
    required bool hasNumber,
    required bool hasSpecialChar,
    required bool isValidEmail,
    required Function(String) onValidatePassword,
    required Function(String) onValidateEmail,
    required VoidCallback onResetValidation,
  }) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isProcessing = false;

    // Local state for validation
    bool localHasMinLength = hasMinLength;
    bool localHasUppercase = hasUppercase;
    bool localHasNumber = hasNumber;
    bool localHasSpecialChar = hasSpecialChar;
    bool localIsValidEmail = isValidEmail;
    
    // Username availability state
    bool isCheckingUsername = false;
    bool? isUsernameAvailable; // null = not checked, true = available, false = taken
    String? usernameError;

    // Reset validation when dialog opens
    onResetValidation();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext dialogContext) => MediaQuery(
        data: MediaQuery.of(dialogContext).copyWith(
          viewInsets: EdgeInsets.zero,  // ✅ Ignore keyboard - overlay instead
        ),
        child: StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 60,
                        offset: const Offset(0, 20),
                        spreadRadius: -10,
                      ),
                      BoxShadow(
                        color: cardHotPink.withOpacity(0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Animated color mesh gradient background
                      AnimatedBuilder(
                        animation: floatingController,
                        builder: (context, child) {
                          final offset = floatingAnimation.value / 50;
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              gradient: LinearGradient(
                                begin: Alignment(offset, -1.0 + offset),
                                end: Alignment(-offset, 1.0 - offset),
                                colors: [
                                  cardHotPink.withOpacity(0.85),
                                  cardCyberPink.withOpacity(0.75),
                                  cardElectricBlue.withOpacity(0.6),
                                  cardDigitalBlue.withOpacity(0.65),
                                  cardLavenderPop.withOpacity(0.7),
                                  cardNeonPurple.withOpacity(0.6),
                                ],
                                stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                              ),
                            ),
                          );
                        },
                      ),
                      // Content with scroll
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                              child: Stack(
                                children: [
                                  // Centered title
                                  Center(
                                    child: Text(
                                      "Create Account",
                                      style: const TextStyle(
                                        fontFamily: 'Circular',
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  // Close button positioned with proper spacing
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            onResetValidation();
                                            Navigator.pop(dialogContext);
                                          },
                                          borderRadius: BorderRadius.circular(10),
                                          child: Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Icon(
                                              Icons.close_rounded,
                                              color: Colors.white.withOpacity(0.9),
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Content
                            Padding(
                              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                              child: Column(
                                children: [
                                  // Username field with availability check
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Username",
                                        style: TextStyle(
                                          fontFamily: 'Circular',
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.95), // ✅ Solid white like others
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: TextField(
                                          controller: nameCtrl,
                                          style: const TextStyle(
                                            fontFamily: 'Circular',
                                            color: textDark, // ✅ Dark text like others
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textCapitalization: TextCapitalization.none,
                                          decoration: InputDecoration(
                                            hintText: "fiery_phoenix",
                                            hintStyle: TextStyle(
                                              fontFamily: 'Circular',
                                              color: textDark.withOpacity(0.4), // ✅ Dark hint
                                              fontSize: 15,
                                              fontWeight: FontWeight.w400,
                                            ),
                                            filled: false,
                                            prefixIcon: Padding(
                                              padding: const EdgeInsets.only(left: 16, right: 12),
                                              child: Icon(
                                                Icons.person_outline,
                                                color: textDark.withOpacity(0.5), // ✅ Dark icon
                                                size: 22,
                                              ),
                                            ),
                                            suffixIcon: isCheckingUsername
                                                ? Padding(
                                                    padding: const EdgeInsets.all(12),
                                                    child: SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: accentGlow,
                                                      ),
                                                    ),
                                                  )
                                                : isUsernameAvailable == null
                                                    ? null
                                                    : Icon(
                                                        isUsernameAvailable!
                                                            ? Icons.check_circle
                                                            : Icons.cancel,
                                                        color: isUsernameAvailable!
                                                            ? Colors.green
                                                            : Colors.red,
                                                        size: 22,
                                                      ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide.none,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide.none,
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide(
                                                color: accentGlow,
                                                width: 2,
                                              ),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                        ),
                                        onChanged: (value) {
                                          // Convert to lowercase immediately
                                          final lowercaseValue = value.toLowerCase();
                                          if (value != lowercaseValue) {
                                            nameCtrl.value = nameCtrl.value.copyWith(
                                              text: lowercaseValue,
                                              selection: TextSelection.collapsed(offset: lowercaseValue.length),
                                            );
                                          }
                                          
                                          // Debounce username check
                                          _usernameDebounce?.cancel();
                                          _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
                                            if (lowercaseValue.isEmpty) {
                                              setDialogState(() {
                                                isCheckingUsername = false;
                                                isUsernameAvailable = null;
                                                usernameError = null;
                                              });
                                              return;
                                            }

                                            setDialogState(() {
                                              isCheckingUsername = true;
                                              usernameError = null;
                                            });

                                            final result = await checkUsernameAvailability(lowercaseValue);

                                            setDialogState(() {
                                              isCheckingUsername = false;
                                              isUsernameAvailable = result['available'];
                                              usernameError = result['error'];
                                            });
                                          });
                                        },
                                      ),
                                    ),  // Container
                                      if (usernameError != null && isUsernameAvailable == false)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8, left: 4),
                                          child: Text(
                                            usernameError!,
                                            style: TextStyle(
                                              fontFamily: 'Circular',
                                              color: Colors.red.shade300,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      if (isUsernameAvailable == true)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8, left: 4),
                                          child: Text(
                                            "✓ Username available",
                                            style: TextStyle(
                                              fontFamily: 'Circular',
                                              color: Colors.green,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildModernTextField(
                                    emailCtrl,
                                    "Email address",
                                    hint: "name@domain.com",
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        localIsValidEmail = RegExp(
                                                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                                            .hasMatch(value);
                                      });
                                      onValidateEmail(value);
                                    },
                                  ),
                                  // Email validation indicator
                                  if (emailCtrl.text.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            localIsValidEmail ? Icons.check_circle : Icons.cancel,
                                            size: 16,
                                            color: localIsValidEmail
                                                ? Colors.green
                                                : Colors.red.shade300,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            localIsValidEmail
                                                ? "Valid email"
                                                : "Invalid email format",
                                            style: TextStyle(
                                              fontFamily: 'Circular',
                                              color: localIsValidEmail
                                                  ? Colors.green
                                                  : Colors.red.shade300,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  _buildModernTextField(
                                    passCtrl,
                                    "Password",
                                    hint: "Min. 8 characters",
                                    icon: Icons.lock_outline,
                                    isPassword: true,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        localHasMinLength = value.length >= 8;
                                        localHasUppercase = value.contains(RegExp(r'[A-Z]'));
                                        localHasNumber = value.contains(RegExp(r'[0-9]'));
                                        localHasSpecialChar =
                                            value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
                                      });
                                      onValidatePassword(value);
                                    },
                                  ),
                                  // Password requirements
                                  if (passCtrl.text.isNotEmpty)
                                    _buildPasswordRequirements(
                                      localHasMinLength,
                                      localHasUppercase,
                                      localHasNumber,
                                      localHasSpecialChar,
                                    ),
                                  const SizedBox(height: 24),

                                  // Action button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: cardHotPink,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 8,
                                        shadowColor: Colors.black.withOpacity(0.3),
                                      ),
                                      onPressed: isProcessing
                                          ? null
                                          : () async {
                                              // Validate username first
                                              if (nameCtrl.text.trim().isEmpty) {
                                                _showSnackBar(context, "Please enter a username", Colors.orange);
                                                return;
                                              }
                                              
                                              if (isUsernameAvailable != true) {
                                                _showSnackBar(
                                                    context, 
                                                    usernameError ?? "Username not available", 
                                                    Colors.orange
                                                );
                                                return;
                                              }
                                              
                                              // Validate before proceeding
                                              if (!localIsValidEmail) {
                                                _showSnackBar(
                                                    context, "Please enter a valid email", Colors.orange);
                                                return;
                                              }

                                              if (!(localHasMinLength &&
                                                  localHasUppercase &&
                                                  localHasNumber &&
                                                  localHasSpecialChar)) {
                                                _showSnackBar(context,
                                                    "Password doesn't meet requirements", Colors.orange);
                                                return;
                                              }

                                              setDialogState(() => isProcessing = true);
                                              onResetValidation();
                                              
                                              // Call the handler (which will close dialog after completion)
                                              await _handleEmailSignUp(
                                                context: context,
                                                dialogContext: dialogContext,
                                                name: nameCtrl.text.trim(),
                                                email: emailCtrl.text.trim(),
                                                password: passCtrl.text.trim(),
                                                authService: authService,
                                                onLoadingChanged: onLoadingChanged,
                                                floatingController: floatingController,
                                                floatingAnimation: floatingAnimation,
                                                onNavigateHome: onNavigateHome,
                                              );
                                              
                                              setDialogState(() => isProcessing = false);
                                            },
                                      child: isProcessing
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: cardHotPink,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: const [
                                                Text(
                                                  "Create account",
                                                  style: TextStyle(
                                                    fontFamily: 'Circular',
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),  // MediaQuery (keyboard overlay)
      ),
    );
  }

  // ============================================================================
  // EMAIL LOGIN DIALOG
  // ============================================================================
  static void showEmailLoginDialog({
    required BuildContext context,
    required AnimationController floatingController,
    required Animation<double> floatingAnimation,
    required AuthService authService,
    required Function(bool) onLoadingChanged,
    required VoidCallback onNavigateHome,
    required bool isValidEmail,
    required Function(String) onValidateEmail,
    required VoidCallback onResetValidation,
  }) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isProcessing = false;

    // Local validation state
    bool localIsValidEmail = isValidEmail;

    // Reset validation when dialog opens
    onResetValidation();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext dialogContext) => MediaQuery(
        data: MediaQuery.of(dialogContext).copyWith(
          viewInsets: EdgeInsets.zero,  // ✅ Ignore keyboard - overlay instead
        ),
        child: StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440, maxHeight: 500),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 60,
                        offset: const Offset(0, 20),
                        spreadRadius: -10,
                      ),
                      BoxShadow(
                        color: cardElectricBlue.withOpacity(0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Animated color mesh gradient background
                      AnimatedBuilder(
                        animation: floatingController,
                        builder: (context, child) {
                          final offset = floatingAnimation.value / 50;
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              gradient: LinearGradient(
                                begin: Alignment(offset, -1.0 + offset),
                                end: Alignment(-offset, 1.0 - offset),
                                colors: [
                                  cardElectricBlue.withOpacity(0.85),
                                  cardDigitalBlue.withOpacity(0.75),
                                  cardHotPink.withOpacity(0.6),
                                  cardNeonPurple.withOpacity(0.7),
                                  cardLavenderPop.withOpacity(0.65),
                                  accentGlow.withOpacity(0.6),
                                ],
                                stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                              ),
                            ),
                          );
                        },
                      ),
                      // Content with scroll
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                              child: Stack(
                                children: [
                                  // Centered title
                                  Center(
                                    child: Text(
                                      "Welcome Back",
                                      style: const TextStyle(
                                        fontFamily: 'Circular',
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  // Close button positioned with proper spacing
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            onResetValidation();
                                            Navigator.pop(dialogContext);
                                          },
                                          borderRadius: BorderRadius.circular(10),
                                          child: Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Icon(
                                              Icons.close_rounded,
                                              color: Colors.white.withOpacity(0.9),
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Content
                            Padding(
                              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                              child: Column(
                                children: [
                                  _buildModernTextField(
                                    emailCtrl,
                                    "Email address",
                                    hint: "name@domain.com",
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        localIsValidEmail = RegExp(
                                                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                                            .hasMatch(value);
                                      });
                                      onValidateEmail(value);
                                    },
                                  ),
                                  // Email validation indicator
                                  if (emailCtrl.text.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            localIsValidEmail ? Icons.check_circle : Icons.cancel,
                                            size: 16,
                                            color: localIsValidEmail
                                                ? Colors.green
                                                : Colors.red.shade300,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            localIsValidEmail
                                                ? "Valid email"
                                                : "Invalid email format",
                                            style: TextStyle(
                                              fontFamily: 'Circular',
                                              color: localIsValidEmail
                                                  ? Colors.green
                                                  : Colors.red.shade300,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  _buildModernTextField(
                                    passCtrl,
                                    "Password",
                                    hint: "Enter password",
                                    icon: Icons.lock_outline,
                                    isPassword: true,
                                  ),
                                  const SizedBox(height: 20),

                                  // Remember Me & Forgot Password row
                                  // Forgot Password link aligned to the right
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.pop(dialogContext);
                                        showForgotPasswordDialog(
                                          context: context,
                                          floatingController: floatingController,
                                          floatingAnimation: floatingAnimation,
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size(0, 0),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        "Forgot Password?",
                                        style: TextStyle(
                                          fontFamily: 'Circular',
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Action button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: cardElectricBlue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 8,
                                        shadowColor: Colors.black.withOpacity(0.3),
                                      ),
                                      onPressed: isProcessing
                                          ? null
                                          : () async {
                                              // Validate email before proceeding
                                              if (!localIsValidEmail) {
                                                _showSnackBar(
                                                    context, "Please enter a valid email", Colors.orange);
                                                return;
                                              }

                                              setDialogState(() => isProcessing = true);
                                              onResetValidation();
                                              
                                              // Keep dialog open, handler will close it if needed
                                              await _handleEmailLogin(
                                                context: context,
                                                dialogContext: dialogContext,
                                                email: emailCtrl.text.trim(),
                                                password: passCtrl.text.trim(),
                                                authService: authService,
                                                onLoadingChanged: onLoadingChanged,
                                                onNavigateHome: onNavigateHome,
                                              );
                                              
                                              if (context.mounted) {
                                                setDialogState(() => isProcessing = false);
                                              }
                                            },
                                      child: isProcessing
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: cardElectricBlue,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: const [
                                                Text(
                                                  "Log in",
                                                  style: TextStyle(
                                                    fontFamily: 'Circular',
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),  // MediaQuery (keyboard overlay)
      ),
    );
  }

  // ============================================================================
  // EMAIL VERIFICATION DIALOG
  // ============================================================================
  static void showEmailVerificationDialog({
    required BuildContext context,
    required String email,
    required AnimationController floatingController,
    required Animation<double> floatingAnimation,
    required VoidCallback onNavigateHome,
  }) {
    // Store the parent context before entering dialog builder
    final parentContext = context;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext dialogContext) => MediaQuery(
        data: MediaQuery.of(dialogContext).copyWith(
          viewInsets: EdgeInsets.zero,  // ✅ Ignore keyboard - overlay instead
        ),
        child: StatefulBuilder(
        builder: (context, setState) {
          bool isChecking = false; // Track if we're currently checking
          
          return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 60,
                    offset: const Offset(0, 20),
                    spreadRadius: -10,
                  ),
                  BoxShadow(
                    color: accentGlow.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Animated color mesh gradient background
                  AnimatedBuilder(
                    animation: floatingController,
                    builder: (context, child) {
                      final offset = floatingAnimation.value / 50;
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: LinearGradient(
                            begin: Alignment(offset, -1.0 + offset),
                            end: Alignment(-offset, 1.0 - offset),
                            colors: [
                              accentGlow.withOpacity(0.85),
                              cardHotPink.withOpacity(0.75),
                              cardNeonPurple.withOpacity(0.7),
                              cardLavenderPop.withOpacity(0.65),
                              cardElectricBlue.withOpacity(0.6),
                              cardDigitalBlue.withOpacity(0.7),
                            ],
                            stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                          ),
                        ),
                      );
                    },
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Success icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.mark_email_read_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title
                        const Text(
                          "Verify Your Email",
                          style: TextStyle(
                            fontFamily: 'Circular',
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Description
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: 'Circular',
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                            children: [
                              const TextSpan(
                                text: "We've sent a verification link to\n",
                              ),
                              TextSpan(
                                text: email,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Info box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Click the link in the email to verify your account",
                                      style: TextStyle(
                                        fontFamily: 'Circular',
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Check your spam folder if you don't see it",
                                      style: TextStyle(
                                        fontFamily: 'Circular',
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Buttons
                        Column(
                          children: [
                            // I've Verified button (checks verification status)
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isChecking ? Colors.grey : Colors.white,
                                  foregroundColor: cardHotPink,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 8,
                                  shadowColor: Colors.black.withOpacity(0.3),
                                ),
                                onPressed: isChecking ? null : () async {
                                  // Prevent double-clicking
                                  setState(() => isChecking = true);
                                  
                                  // Start checking verification status
                                  await _checkEmailVerificationAndLogin(
                                    context: parentContext, // Use parent context, not dialog context!
                                    dialogContext: dialogContext,
                                    onNavigateHome: onNavigateHome,
                                    onResetToCards: () {
                                      // This is no longer used since we don't reset
                                    },
                                  );
                                  
                                  // Re-enable button after check completes
                                  if (context.mounted) {
                                    setState(() => isChecking = false);
                                  }
                                },
                                child: isChecking
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: cardHotPink,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          "Checking...",
                                          style: TextStyle(
                                            fontFamily: 'Circular',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      "I've Verified",
                                      style: TextStyle(
                                        fontFamily: 'Circular',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Resend email button
                            TextButton(
                              onPressed: () async {
                                try {
                                  final user = FirebaseAuth.instance.currentUser;
                                  print('🔄 Attempting to resend verification email...');
                                  print('User: ${user?.email}');
                                  print('Email verified: ${user?.emailVerified}');

                                  if (user != null && !user.emailVerified) {
                                    await user.sendEmailVerification();
                                    print('✅ Verification email resent successfully!');
                                    _showSnackBar(
                                      parentContext,
                                      "Verification email sent again!",
                                      accentGlow,
                                    );
                                  } else if (user?.emailVerified == true) {
                                    print('⚠️ Email already verified');
                                    _showSnackBar(
                                      parentContext,
                                      "Email already verified! Try logging in.",
                                      Colors.green,
                                    );
                                  } else {
                                    print('❌ No user found');
                                    _showSnackBar(
                                      parentContext,
                                      "Please sign up first.",
                                      Colors.orange,
                                    );
                                  }
                                } catch (e) {
                                  print('❌ Error resending email: $e');
                                  if (e.toString().contains('too-many-requests')) {
                                    _showSnackBar(
                                      parentContext,
                                      "Too many requests. Please wait a few minutes.",
                                      Colors.orange,
                                    );
                                  } else {
                                    _showSnackBar(
                                      parentContext,
                                      "Failed to resend email. Please try again later.",
                                      Colors.red,
                                    );
                                  }
                                }
                              },
                              child: Text(
                                "Resend verification email",
                                style: TextStyle(
                                  fontFamily: 'Circular',
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
        },
      ),  // MediaQuery (keyboard overlay)
      ),
    );
  }

  // ============================================================================
  // EMAIL NOT VERIFIED DIALOG (for login attempts)
  // ============================================================================
  static void showEmailNotVerifiedDialog({
    required BuildContext context,
    required String email,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext dialogContext) => MediaQuery(
        data: MediaQuery.of(dialogContext).copyWith(
          viewInsets: EdgeInsets.zero,  // ✅ Ignore keyboard - overlay instead
        ),
        child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 60,
                    offset: const Offset(0, 20),
                    spreadRadius: -10,
                  ),
                  BoxShadow(
                    color: accentGlow.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentGlow.withOpacity(0.85),
                      cardHotPink.withOpacity(0.75),
                      cardNeonPurple.withOpacity(0.7),
                      cardLavenderPop.withOpacity(0.65),
                      cardElectricBlue.withOpacity(0.6),
                      cardDigitalBlue.withOpacity(0.7),
                    ],
                    stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                  ),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Warning icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.email_outlined,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),

                      // Title
                      const Text(
                        "Email Not Verified",
                        style: TextStyle(
                          fontFamily: 'Circular',
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Text(
                        "Your account exists but isn't verified yet. Please check your email for the verification link, or sign up again to get a new one.",
                        style: TextStyle(
                          fontFamily: 'Circular',
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Buttons
                      Column(
                        children: [
                          // Resend email button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: cardHotPink,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 8,
                                shadowColor: Colors.black.withOpacity(0.3),
                              ),
                              onPressed: () async {
                                try {
                                  final user = FirebaseAuth.instance.currentUser;
                                  print('🔄 Resending verification email from login dialog...');
                                  print('User: ${user?.email}');

                                  if (user != null && !user.emailVerified) {
                                    await user.sendEmailVerification();
                                    print('✅ Verification email resent!');
                                    _showSnackBar(
                                      context,
                                      "Verification email sent!",
                                      accentGlow,
                                    );
                                  }
                                } catch (e) {
                                  print('❌ Error resending: $e');
                                  if (e.toString().contains('too-many-requests')) {
                                    _showSnackBar(
                                      context,
                                      "Too many requests. Wait a few minutes.",
                                      Colors.orange,
                                    );
                                  } else {
                                    _showSnackBar(
                                      context,
                                      "Failed to resend email. Please try again later.",
                                      Colors.red,
                                    );
                                  }
                                }
                              },
                              child: const Text(
                                "Resend verification email",
                                style: TextStyle(
                                  fontFamily: 'Circular',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Close button
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(dialogContext);
                              await FirebaseAuth.instance.signOut();
                            },
                            child: Text(
                              "Close",
                              style: TextStyle(
                                fontFamily: 'Circular',
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // X Close button in top right corner
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          await FirebaseAuth.instance.signOut();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.close,
                            color: Colors.white.withOpacity(0.9),
                            size: 20,
                          ),
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
        ),
      ),  // MediaQuery (keyboard overlay)
      ),
    );
  }

  // ============================================================================
  // HELPER: MODERN TEXT FIELD
  // ============================================================================
  static Widget _buildModernTextField(
    TextEditingController controller,
    String label, {
    String? hint,
    IconData? icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    int? maxLength,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Circular',
            color: Colors.white.withOpacity(0.9),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95), // ✅ Solid white
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            maxLength: maxLength,
            onChanged: onChanged,
            style: const TextStyle(
              fontFamily: 'Circular',
              color: textDark, // ✅ Dark text
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              filled: false,
              hintText: hint,
              counterText: "",
              hintStyle: TextStyle(
                fontFamily: 'Circular',
                color: textDark.withOpacity(0.4), // ✅ Dark hint
                fontWeight: FontWeight.w400,
                fontSize: 15,
              ),
              prefixIcon: icon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 16, right: 12),
                      child: Icon(
                        icon,
                        color: textDark.withOpacity(0.5), // ✅ Dark icon
                        size: 22,
                      ),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: accentGlow,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // HELPER: PASSWORD REQUIREMENT INDICATOR
  // ============================================================================
  static Widget _buildPasswordRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: isMet ? Colors.green : Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
              border: Border.all(
                color: isMet ? Colors.green : Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: isMet
                ? const Icon(
                    Icons.check,
                    size: 12,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Circular',
              color: isMet ? Colors.green : Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: isMet ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPER: PASSWORD REQUIREMENTS SECTION
  // ============================================================================
  static Widget _buildPasswordRequirements(
    bool hasMinLength,
    bool hasUppercase,
    bool hasNumber,
    bool hasSpecialChar,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Password must contain:",
            style: TextStyle(
              fontFamily: 'Circular',
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildPasswordRequirement("At least 8 characters", hasMinLength),
          _buildPasswordRequirement("One uppercase letter", hasUppercase),
          _buildPasswordRequirement("One number", hasNumber),
          _buildPasswordRequirement("One special character (!@#\$%^&*)", hasSpecialChar),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPER: SNACKBAR
  // ============================================================================
  static void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Circular',
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================================
  // FORGOT PASSWORD DIALOG
  // ============================================================================
  static void showForgotPasswordDialog({
    required BuildContext context,
    required AnimationController floatingController,
    required Animation<double> floatingAnimation,
  }) {
    final emailCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext dialogContext) => MediaQuery(
        data: MediaQuery.of(dialogContext).copyWith(
          viewInsets: EdgeInsets.zero,  // ✅ Ignore keyboard - overlay instead
        ),
        child: StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 60,
                        offset: const Offset(0, 20),
                        spreadRadius: -10,
                      ),
                      BoxShadow(
                        color: accentGlow.withOpacity(0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Animated gradient background
                      AnimatedBuilder(
                        animation: floatingController,
                        builder: (context, child) {
                          final offset = floatingAnimation.value / 50;
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              gradient: LinearGradient(
                                begin: Alignment(offset, -1.0 + offset),
                                end: Alignment(-offset, 1.0 - offset),
                                colors: [
                                  accentGlow.withOpacity(0.85),
                                  cardHotPink.withOpacity(0.75),
                                  cardNeonPurple.withOpacity(0.7),
                                  cardLavenderPop.withOpacity(0.65),
                                  cardElectricBlue.withOpacity(0.6),
                                  cardDigitalBlue.withOpacity(0.7),
                                ],
                                stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                              ),
                            ),
                          );
                        },
                      ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Close button
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                margin: const EdgeInsets.only(right: 4, bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => Navigator.pop(dialogContext),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white.withOpacity(0.9),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Icon
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.lock_reset_rounded,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Title
                            const Text(
                              "Forgot Password?",
                              style: TextStyle(
                                fontFamily: 'Circular',
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),

                            // Description
                            Text(
                              "Enter your email and we'll send you a link to reset your password.",
                              style: TextStyle(
                                fontFamily: 'Circular',
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // Email input
                            TextField(
                              controller: emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                fontFamily: 'Circular',
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Email address',
                                hintStyle: TextStyle(
                                  fontFamily: 'Circular',
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.15),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 18,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Send Reset Link button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: cardHotPink,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 8,
                                  shadowColor: Colors.black.withOpacity(0.3),
                                ),
                                onPressed: isLoading ? null : () async {
                                  final email = emailCtrl.text.trim();
                                  
                                  if (email.isEmpty) {
                                    _showSnackBar(
                                      context,
                                      "Please enter your email",
                                      Colors.orange,
                                    );
                                    return;
                                  }

                                  if (!email.contains('@') || !email.contains('.')) {
                                    _showSnackBar(
                                      context,
                                      "Please enter a valid email",
                                      Colors.orange,
                                    );
                                    return;
                                  }

                                  setState(() => isLoading = true);

                                  try {
                                    await FirebaseAuth.instance.sendPasswordResetEmail(
                                      email: email,
                                    );
                                    
                                    if (!context.mounted) return;

                                    Navigator.pop(dialogContext);
                                    
                                    _showSnackBar(
                                      context,
                                      "Password reset link sent! Check your email.",
                                      Colors.green,
                                    );
                                  } on FirebaseAuthException catch (e) {
                                    setState(() => isLoading = false);
                                    
                                    if (!context.mounted) return;
                                    
                                    String message = "Failed to send reset email";
                                    if (e.code == 'user-not-found') {
                                      message = "No account found with this email";
                                    } else if (e.code == 'invalid-email') {
                                      message = "Invalid email address";
                                    } else if (e.code == 'too-many-requests') {
                                      message = "Too many attempts. Try again later.";
                                    }
                                    
                                    _showSnackBar(context, message, Colors.red);
                                  } catch (e) {
                                    setState(() => isLoading = false);
                                    if (!context.mounted) return;
                                    _showSnackBar(
                                      context,
                                      "An error occurred. Please try again.",
                                      Colors.red,
                                    );
                                  }
                                },
                                child: isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: cardHotPink,
                                      ),
                                    )
                                  : const Text(
                                      "Send Reset Link",
                                      style: TextStyle(
                                        fontFamily: 'Circular',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),  // MediaQuery (keyboard overlay)
      ),
    );
  }

  // ============================================================================
  // HELPER: ERROR MESSAGES
  // ============================================================================
  static String _getErrorMessage(FirebaseAuthException e) {
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