import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'utils/auth_error_messages.dart';
import 'utils/auth_exception.dart';
import 'screens/email_signup_screen.dart';
import 'screens/email_login_screen.dart';
import 'screens/phone_auth_screen.dart';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'dart:async';
import 'widgets/animated_waveform.dart';
import 'widgets/auth_snackbar.dart';
import 'package:video_player/video_player.dart';

// ----------------------
// Y2K COLORS (STRONGER PASTELS)
// ----------------------
const bgTop = Color(0xFFFFD4FF);      // Stronger light pink
const bgMid = Color(0xFFEDD4FF);      // Stronger light lavender
const bgBottom = Color(0xFFD4E4FF);   // Stronger light blue

const y2kPink = Color(0xFFFF6FE8);
const y2kPurple = Color(0xFFB69CFF);
const mutedText = Color(0xFF8A7EA5);

// Card colors - Faded/washed Y2K gradients with glass effect
const cardHotPink = Color(0xFFFFB3D9);        // Washed out pink
const cardElectricBlue = Color(0xFFB3D9FF);   // Washed out blue
const cardNeonPurple = Color(0xFFD9B3FF);     // Washed out purple
const cardCyberPink = Color(0xFFFFCCE6);      // Very light pink
const cardDigitalBlue = Color(0xFFCCE6FF);    // Very light blue
const cardLavenderPop = Color(0xFFE6CCFF);    // Very light lavender
const accentGlow = Color(0xFFFF99CC);

const textCard = Color(0xFFFFFFFF); // White text for vibrant cards
const textDark = Color(0xFF1A0D26); // Very dark purple for contrast
const textLight = Color(0xFFFFFFFF); // White text

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late VideoPlayerController _mainController;
  late VideoPlayerController _authController;
  bool _isMainInitialized = false;
  bool _isAuthInitialized = false;
  bool isLoading = false;
  bool showLanding = false;
  
  int _matchCount = 47;
  Timer? _matchTimer;
  
  // Track which card is being hovered/pressed
  int? _activeCardIndex;
  int? _hoveredCardIndex;
  
  // View state management
  bool showAuthMethods = false;
  bool isSignUp = true;
  
  // Password validation state
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  
  // Email validation state
  bool _isValidEmail = false;
  
  // Animation controllers
  late AnimationController _entranceController;
  late AnimationController _floatingController;
  late AnimationController _authMethodsController;
  late AnimationController _backgroundAnimationController; // Kept for minimal gradient shifts if needed
  late AnimationController _gradientShiftController;
  late AnimationController _shimmerController;
  
  // Entrance animations
  late Animation<Offset> _slideAnimation1;
  late Animation<Offset> _slideAnimation2;
  late Animation<double> _entranceOpacity;
  
  // Floating animation
  late Animation<double> _floatingAnimation;
  
  // Auth methods slide animation
  late Animation<Offset> _authMethodsSlide;
  late Animation<double> _authMethodsOpacity;
  
  // Main cards slide out animation
  late Animation<Offset> _mainCardsSlideOut;
  late Animation<double> _mainCardsOpacityOut;
  
  // Background pattern animation
  late Animation<double> _backgroundOffset;
  
  // Gradient shift animation
  late Animation<double> _gradientShift;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    
    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    
    _authMethodsController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    
    _backgroundAnimationController = AnimationController(
      duration: const Duration(milliseconds: 120000),
      vsync: this,
    )..repeat();
    
    _gradientShiftController = AnimationController(
      duration: const Duration(milliseconds: 25000),
      vsync: this,
    )..repeat();
    
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 5500),
      vsync: this,
    )..repeat();
    
    _slideAnimation1 = Tween<Offset>(
      begin: const Offset(0, 1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutQuart),
    ));
    
    _slideAnimation2 = Tween<Offset>(
      begin: const Offset(0, 1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.1, 0.85, curve: Curves.easeOutQuart),
    ));
    
    _entranceOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));
    
    _floatingAnimation = Tween<double>(
      begin: -4.0,
      end: 4.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));
    
    _authMethodsSlide = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: const Offset(0, 0.02), // Moved higher (was 0.15)
    ).animate(CurvedAnimation(
      parent: _authMethodsController,
      curve: Curves.easeOutCubic,
    ));
    
    _authMethodsOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _authMethodsController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));
    
    _mainCardsSlideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.6),
    ).animate(CurvedAnimation(
      parent: _authMethodsController,
      curve: Curves.easeInCubic,
    ));
    
    _mainCardsOpacityOut = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _authMethodsController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));
    
    _backgroundOffset = Tween<double>(
      begin: 0.0,
      end: 1000.0,
    ).animate(CurvedAnimation(
      parent: _backgroundAnimationController,
      curve: Curves.linear,
    ));
    
    _gradientShift = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _gradientShiftController,
      curve: Curves.easeInOutSine,
    ));

    _matchTimer = Timer.periodic(const Duration(milliseconds: 3800), (_) {
      if (mounted) {
        setState(() {
          _matchCount = 35 + (DateTime.now().millisecondsSinceEpoch % 40).toInt();
        });
      }
    });

    _mainController = VideoPlayerController.asset('assets/images/finalbg.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isMainInitialized = true);
          _mainController.setLooping(true);
          _mainController.setVolume(0);
          _mainController.play();
          
          // COORDINATION: Start entrance animation only when video is ready
          if (!showLanding) {
            _entranceController.forward();
          }
        }
      });

    _authController = VideoPlayerController.asset('assets/images/finalfinalbg.mp4')
      ..initialize().then((_) {
        setState(() => _isAuthInitialized = true);
        _authController.setLooping(true);
        _authController.setVolume(0);
        _authController.pause(); // Start paused, play when switched
      });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatingController.dispose();
    _authMethodsController.dispose();
    _backgroundAnimationController.dispose();
    _gradientShiftController.dispose();
    _shimmerController.dispose();
    _matchTimer?.cancel();
    _mainController.dispose();
    _authController.dispose();
    super.dispose();
  }

  void _showAuthMethodsWithAnimation(bool isSignUpMode) {
    if (_authMethodsController.isAnimating) return;
    
    setState(() {
      isSignUp = isSignUpMode;
      showAuthMethods = true;
      _hoveredCardIndex = null;
      _activeCardIndex = null;
    });
    _authController.play();
    _authMethodsController.forward().then((_) {
      if (mounted) _mainController.pause();
    });
  }
  
  void _goBackToMainCards() {
    if (_authMethodsController.isAnimating) return;
    
    _mainController.play();
    setState(() {
      showAuthMethods = false;
      _hoveredCardIndex = null;
      _activeCardIndex = null;
    });
    
    _authMethodsController.reverse().then((_) {
      if (mounted) {
        _authController.pause();
      }
    });
  }



  // Password validation method
  void _validatePassword(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }
  
  // Email validation method
  void _validateEmail(String email) {
    setState(() {
      _isValidEmail = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
      ).hasMatch(email);
    });
  }
  
  // Reset validation states
  void _resetValidation() {
    setState(() {
      _hasMinLength = false;
      _hasUppercase = false;
      _hasNumber = false;
      _hasSpecialChar = false;
      _isValidEmail = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // LAYER 1: DUAL VIDEO BACKGROUND WITH CROSS-FADE
          Stack(
            fit: StackFit.expand,
            children: [
              // Main video (finalbg.mp4)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _isMainInitialized ? (showAuthMethods ? 0.0 : 1.0) : 0.0,
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.fill,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: _isMainInitialized ? _mainController.value.size.width : 1,
                        height: _isMainInitialized ? _mainController.value.size.height : 1,
                        child: VideoPlayer(_mainController),
                      ),
                    ),
                  ),
                ),
              ),
              // Auth video (finalfinalbg.mp4)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _isAuthInitialized ? (showAuthMethods ? 1.0 : 0.0) : 0.0,
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.fill,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: _isAuthInitialized ? _authController.value.size.width : 1,
                        height: _isAuthInitialized ? _authController.value.size.height : 1,
                        child: VideoPlayer(_authController),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // LAYER 2: DARK OVERLAY
          const SizedBox.expand(
            child: ColoredBox(color: Color(0x4D000000)),
          ),

          // ── Main Content Area ──
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header (Back navigation or spacing)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: showAuthMethods ? 80 : 40,
                  child: showAuthMethods
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _goBackToMainCards,
                                  borderRadius: BorderRadius.circular(30),
                                  splashColor: Colors.white.withOpacity(0.3),
                                  highlightColor: Colors.white.withOpacity(0.1),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const SizedBox(width: 40),
                            ],
                          ),
                        )
                      : const SizedBox(height: 40),
                ),
                
                // Spacing to push content down near center (like hinge/tinder layouts)
                const Spacer(flex: 2),

                // ── "wav" Wordmark & Tagline & Waveform ──
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = MediaQuery.of(context).size.width;
                    final h = MediaQuery.of(context).size.height;
                    final wavSize = (w * 0.2).clamp(48.0, 72.0);
                    final tagSize = (w * 0.045).clamp(14.0, 16.0);
                    
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFB3E6), // soft pink
                              Color(0xFFB3D9FF), // soft blue
                              Color(0xFFD9B3FF), // soft purple
                            ],
                          ).createShader(bounds),
                          blendMode: BlendMode.srcIn,
                          child: Text(
                            "wav",
                            style: TextStyle(
                              fontFamily: 'Circular', 
                              fontSize: wavSize,
                              fontWeight: FontWeight.w900,
                              color: Colors.white, 
                              letterSpacing: -1.5,
                              height: 1.0,
                            ),
                          ),
                        ),
                        SizedBox(height: h * 0.01),
                        Text(
                          "match through music",
                          style: TextStyle(
                            fontFamily: 'Circular',
                            fontSize: tagSize,
                            fontWeight: FontWeight.w600, // Medium/SemiBold
                            color: const Color(0xFF8B84A6).withOpacity(0.9), // Muted lavender-grey
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    );
                  }
                ),

                const Spacer(flex: 5), // Combined spacer to push cards down
                
                // Cards Stack Area
                SizedBox(
                  height: (h * 0.45).clamp(280.0, 380.0), // Squeezed to prevent overflow
                  child: RepaintBoundary(
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          child: SlideTransition(
                            position: _mainCardsSlideOut,
                            child: FadeTransition(
                              opacity: _mainCardsOpacityOut,
                              child: IgnorePointer(
                                ignoring: showAuthMethods,
                                child: _buildMainCards(),
                              ),
                            ),
                          ),
                        ),
                        RepaintBoundary(
                          child: SlideTransition(
                            position: _authMethodsSlide,
                            child: FadeTransition(
                              opacity: _authMethodsOpacity,
                              child: IgnorePointer(
                                ignoring: !showAuthMethods,
                                child: GestureDetector(
                                  onVerticalDragUpdate: (details) {
                                    if (details.delta.dy < -10) { // Swipe up
                                      _goBackToMainCards();
                                    }
                                  },
                                  child: _buildAuthMethodCards(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // ── Guest Mode Link ──
                // ── Guest Mode Link ──
                AnimatedOpacity(
                  opacity: showAuthMethods ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 400),
                  child: IgnorePointer(
                    ignoring: showAuthMethods,
                    child: GestureDetector(
                      onTap: isLoading
                          ? null
                          : () async {
                              setState(() => isLoading = true);
                              try {
                                await context.read<AuthProvider>().signInAsGuest();
                              } catch (e) {
                                if (mounted) {
                                  AuthSnackBar.show(context, 'Guest login failed: $e');
                                }
                              } finally {
                                if (mounted) setState(() => isLoading = false);
                              }
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Continue as Guest',
                          style: TextStyle(
                            fontFamily: 'Circular',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: mutedText.withOpacity(0.7),
                            decoration: TextDecoration.underline,
                            decorationColor: mutedText.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        
        // Calculate responsive values
        // Maintain minimum 24px edge padding on both sides
        const minEdgePadding = 24.0;
        const cardSpacing = 16.0; // Minimum space between cards
        
        // Calculate available width for both cards plus spacing
        final availableWidth = screenWidth - (minEdgePadding * 2);
        
        // Calculate optimal card width (max 220, scales down on smaller screens)
        final cardWidth = (availableWidth - cardSpacing) / 2;
        final responsiveCardWidth = cardWidth.clamp(120.0, 220.0); // Reduced min clamp for 320px screens
        
        // Calculate horizontal offset to maintain spacing
        final horizontalOffset = (responsiveCardWidth + cardSpacing) / 2;
        
        // Scale card height proportionally
        final cardHeight = (responsiveCardWidth * 1.27).clamp(160.0, 280.0); // Reduced min clamp
        
        return Center(
          child: SizedBox(
            height: cardHeight + 80, // Extra space for shadows and animations
            width: double.infinity,
            child: AnimatedBuilder(
              animation: Listenable.merge([_entranceController, _floatingController]),
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: (screenWidth / 2) - responsiveCardWidth - (cardSpacing / 2),
                      width: responsiveCardWidth,
                      height: cardHeight,
                      child: SlideTransition(
                        position: _slideAnimation1,
                        child: FadeTransition(
                          opacity: _entranceOpacity,
                          child: Transform.translate(
                            offset: Offset(0, _floatingAnimation.value),
                            child: _buildMainAuthCard(
                              cardIndex: 0,
                              title: "Sign up",
                              subtitle: "Make a new account in seconds",
                              rotation: -8,
                              horizontalOffset: -horizontalOffset, // Kept to determine perspective 3D tilt
                              cardWidth: responsiveCardWidth,
                              cardHeight: cardHeight,
                              gradientColors: const [
                                Color(0xFFFFB8E6),
                                Color(0xFFFFD8F0),
                                Color(0xFFFFE8F7),
                              ],
                              accentColor: const Color(0xFFFF88D4),
                              decorationType: 'blob',
                              onTap: () => _showAuthMethodsWithAnimation(true),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    Positioned(
                      left: (screenWidth / 2) + (cardSpacing / 2),
                      width: responsiveCardWidth,
                      height: cardHeight,
                      child: SlideTransition(
                        position: _slideAnimation2,
                        child: FadeTransition(
                          opacity: _entranceOpacity,
                          child: Transform.translate(
                            offset: Offset(0, -_floatingAnimation.value),
                            child: _buildMainAuthCard(
                              cardIndex: 1,
                              title: "Log in",
                              subtitle: "Pick up right where you left off",
                              rotation: 8,
                              horizontalOffset: horizontalOffset, // Kept to determine perspective 3D tilt
                              cardWidth: responsiveCardWidth,
                              cardHeight: cardHeight,
                              gradientColors: const [
                                Color(0xFFB8DCFF),
                                Color(0xFFD8EBFF),
                                Color(0xFFE8F4FF),
                              ],
                              accentColor: const Color(0xFF88C8FF),
                              decorationType: 'streak',
                              onTap: () => _showAuthMethodsWithAnimation(false),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuthMethodCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        
        // Calculate responsive values - TIGHTER spacing to prevent edge touching
        const minEdgePadding = 32.0; // Increased from 24 to move cards away from edges
        const cardSpacing = 8.0; // Increased from 5 to bring cards closer to each other
        
        // Calculate available width for 3 cards
        final availableWidth = screenWidth - (minEdgePadding * 2);
        
        // Calculate card width (3 cards + 2 gaps)
        final cardWidth = (availableWidth - (cardSpacing * 2)) / 3;
        final responsiveCardWidth = cardWidth.clamp(85.0, 140.0); // Reduced min clamp
        
        // Calculate horizontal offset
        final horizontalOffset = responsiveCardWidth + cardSpacing;
        
        // Scale card height proportionally
        final centerCardHeight = (responsiveCardWidth * 1.62).clamp(140.0, 235.0); // Reduced min clamp
        final sideCardHeight = (responsiveCardWidth * 1.48).clamp(125.0, 215.0); // Reduced min clamp
        
        return Center(
          child: SizedBox(
            height: centerCardHeight + 80, // Extra space for tilted cards
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Email card - left with left tilt
                    Transform.translate(
                      offset: Offset(-horizontalOffset, 10 + _floatingAnimation.value),
                      child: Transform.rotate(
                        angle: -16 * math.pi / 180,
                        child: _buildScrollingAuthCard(
                          cardIndex: 0,
                          iconWidget: SvgPicture.string(
  '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="100" height="100">
    <path fill="#4caf50" d="M45,16.2l-5,2.75l-5,4.75L35,40h7c1.657,0,3-1.343,3-3V16.2z"/>
    <path fill="#1e88e5" d="M3,16.2l3.614,1.71L13,23.7V40H6c-1.657,0-3-1.343-3-3V16.2z"/>
    <polygon fill="#e53935" points="35,11.2 24,19.45 13,11.2 12,17 13,23.7 24,31.95 35,23.7 36,17"/>
    <path fill="#c62828" d="M3,12.298V16.2l10,7.5V11.2L9.876,8.859C9.132,8.301,8.228,8,7.298,8h0C4.924,8,3,9.924,3,12.298z"/>
    <path fill="#fbc02d" d="M45,12.298V16.2l-10,7.5V11.2l3.124-2.341C38.868,8.301,39.772,8,40.702,8h0 C43.076,8,45,9.924,45,12.298z"/>
  </svg>''',
  width: responsiveCardWidth * 0.62,
  height: responsiveCardWidth * 0.62,
),
                          title: "",
                          subtitle: "Classic & private",
                          cardWidth: responsiveCardWidth,
                          cardHeight: sideCardHeight,
                          gradientColors: const [Color(0xFFFFB3C1), Color(0xFFFFCCDA)],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => isSignUp
                                  ? const EmailSignUpScreen()
                                  : const EmailLoginScreen(),
                            ),
                          ),
                          isCenter: false,
                        ),
                      ),
                    ),
                    
                    // Google card - center, no tilt
                    Transform.translate(
                      offset: Offset(0, -_floatingAnimation.value),
                      child: _buildScrollingAuthCard(
                        cardIndex: 1,
                        iconWidget: SvgPicture.string(
                          '''<svg width="90" height="90" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
                            <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
                            <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
                            <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
                          </svg>''',
                          width: responsiveCardWidth * 0.62,
                          height: responsiveCardWidth * 0.62,
                        ),
                        title: "",
                        subtitle: "One-tap access",
                        cardWidth: responsiveCardWidth,
                        cardHeight: sideCardHeight, // ✅ Same height as other cards
                        gradientColors: const [Color(0xFFE8E8FF), Color(0xFFF0F0FF)],
                        onTap: isLoading 
                            ? null 
                            : () async {
                                setState(() => isLoading = true);
                                try {
                                  await context.read<AuthProvider>().signInWithGoogle();
                                } on AuthException catch (e) {
                                  if (mounted) {
                                    if (e.code == AuthErrorCode.accountExistsWithDifferentCredential) {
                                      // COLLISION: Strategy 2 - Link via EmailLogin
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => const EmailLoginScreen(showLinkingBanner: true),
                                      ));
                                    } else {
                                      AuthSnackBar.show(context, e.message);
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    AuthSnackBar.show(context, 'Sign-in failed');
                                  }
                                } finally {
                                  if (mounted) setState(() => isLoading = false);
                                }
                              },
                        showLoading: isLoading,
                        isCenter: true,
                      ),
                    ),
                    
                    // Phone card - right with right tilt
                    Transform.translate(
                      offset: Offset(horizontalOffset, 10 + _floatingAnimation.value),
                      child: Transform.rotate(
                        angle: 16 * math.pi / 180,
                        child: _buildScrollingAuthCard(
                          cardIndex: 2,
                          icon: Icons.phone_android_rounded,
                          iconSize: responsiveCardWidth * 0.62,
                          title: "",
                          subtitle: "Fast & secure",
                          cardWidth: responsiveCardWidth,
                          cardHeight: sideCardHeight,
                          gradientColors: const [Color(0xFFB3D9FF), Color(0xFFCCE6FF)],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                          ),
                          isCenter: false,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildScrollingAuthCard({
    required int cardIndex,
    IconData? icon,
    double? iconSize,
    Widget? iconWidget,
    required String title,
    required String subtitle,
    required double cardWidth,
    required double cardHeight,
    required List<Color> gradientColors,
    VoidCallback? onTap,
    bool showLoading = false,
    bool isCenter = false,
  }) {
    bool isActive = showAuthMethods && _activeCardIndex == cardIndex;
    bool isHovered = showAuthMethods && _hoveredCardIndex == cardIndex;
    
    // Calculate responsive icon size
    final responsiveIconSize = iconSize ?? cardWidth * 0.62;
    
    return MouseRegion(
      onEnter: (_) {
        if (showAuthMethods && onTap != null) {
          setState(() => _hoveredCardIndex = cardIndex);
        }
      },
      onExit: (_) {
        if (showAuthMethods) {
          setState(() => _hoveredCardIndex = null);
        }
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (showAuthMethods) {
            setState(() => _activeCardIndex = cardIndex);
          }
        },
        onTapUp: (_) {
          if (showAuthMethods) {
            setState(() => _activeCardIndex = null);
            if (onTap != null) onTap();
          }
        },
        onTapCancel: () {
          if (showAuthMethods) {
            setState(() => _activeCardIndex = null);
          }
        },
        child: AnimatedScale(
          scale: isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: isActive ? 35 : 22,
                  offset: Offset(0, isActive ? 20.0 : 12.0),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/bgstatic.png',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    color: Colors.black.withOpacity(0.1),
                  ),
                  Stack(
                    children: [
                      Positioned(
                        top: cardHeight * 0.12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: isHovered ? 1.0 : 0.8,
                            duration: const Duration(milliseconds: 200),
                            child: showLoading
                                ? SizedBox(
                                    width: responsiveIconSize,
                                    height: responsiveIconSize,
                                    child: CircularProgressIndicator(
                                      strokeWidth: cardWidth * 0.02,
                                      color: Colors.white,
                                    ),
                                  )
                                : (iconWidget != null
                                    ? SizedBox(
                                        width: responsiveIconSize,
                                        height: responsiveIconSize,
                                        child: iconWidget,
                                      )
                                    : Icon(
                                        icon,
                                        size: responsiveIconSize,
                                        color: Colors.white,
                                        shadows: const [
                                          Shadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 4))
                                        ],
                                      )),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: cardHeight * 0.14,
                        left: 0,
                        right: 0,
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Circular',
                            fontSize: cardWidth * 0.165,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(color: Colors.black.withOpacity(0.6), blurRadius: 15, offset: const Offset(0, 2))
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          final activeFraction = 3.5 / 5.5;
                          final progress = _shimmerController.value;
                          final animProgress = (progress / activeFraction).clamp(0.0, 1.0);
                          final curvedProgress = Curves.easeInOut.transform(animProgress);
                          final leftPosition = (-cardWidth * 0.5) + (curvedProgress * (cardWidth * 1.8));
                          
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: leftPosition,
                                top: -cardHeight,
                                bottom: -cardHeight,
                                width: cardWidth * 0.25,
                                child: Transform.rotate(
                                  angle: 15 * math.pi / 180,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0x00FFFFFF),
                                          Color.fromRGBO(255, 255, 255, 0.25),
                                          Color(0x00FFFFFF),
                                        ],
                                        stops: [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainAuthCard({
    required int cardIndex,
    required String title,
    required String subtitle,
    required double rotation,
    required double horizontalOffset,
    required double cardWidth,
    required double cardHeight,
    required List<Color> gradientColors,
    required Color accentColor,
    required String decorationType,
    required VoidCallback onTap,
  }) {
    bool isActive = !showAuthMethods && _activeCardIndex == cardIndex;
    bool isHovered = !showAuthMethods && _hoveredCardIndex == cardIndex;
    
    // Calculate responsive font sizes
    final titleFontSize = (cardWidth * 0.164).clamp(24.0, 36.0);
    final subtitleFontSize = (cardWidth * 0.073).clamp(13.0, 16.0);
    final padding = (cardWidth * 0.127).clamp(20.0, 28.0);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0.0, isActive ? -20.0 : 0.0, 0.0),
      child: Transform.rotate(
        angle: rotation * math.pi / 180,
        child: Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateY(horizontalOffset > 0 ? -0.05 : 0.05)
            ..rotateX(0.02),
          alignment: Alignment.center,
          child: MouseRegion(
            onEnter: (_) {
              if (!showAuthMethods) {
                setState(() => _hoveredCardIndex = cardIndex);
              }
            },
            onExit: (_) {
              if (!showAuthMethods) {
                setState(() => _hoveredCardIndex = null);
              }
            },
            child: GestureDetector(
              onTapDown: (_) {
                if (!showAuthMethods) {
                  setState(() => _activeCardIndex = cardIndex);
                }
              },
              onTapUp: (_) {
                if (!showAuthMethods) {
                  setState(() => _activeCardIndex = null);
                  onTap();
                }
              },
              onTapCancel: () {
                if (!showAuthMethods) {
                  setState(() => _activeCardIndex = null);
                }
              },
              child: AnimatedScale(
                scale: isHovered ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  height: cardHeight,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: isActive ? 40 : 25,
                        offset: Offset(0, isActive ? 20 : 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // STATIC IMAGE BACKGROUND
                        Image.asset(
                          'assets/images/bgstatic.png',
                          fit: BoxFit.cover,
                        ),

                        // Very subtle dark tint
                        Container(
                          color: Colors.black.withOpacity(0.1),
                        ),

                        Padding(
                          padding: EdgeInsets.fromLTRB(padding, padding, padding, padding * 1.2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontFamily: 'Circular',
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                  height: 1.0,
                                  letterSpacing: -1.5,
                                ),
                              ),
                              Text(
                                subtitle,
                                softWrap: true,
                                style: TextStyle(
                                  fontFamily: 'Circular',
                                  fontSize: subtitleFontSize,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withOpacity(0.95),
                                  height: 1.2,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // -- The Shimmer Overlay --
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _shimmerController,
                              builder: (context, child) {
                                final activeFraction = 3.5 / 5.5;
                                final progress = _shimmerController.value;
                                final animProgress = (progress / activeFraction).clamp(0.0, 1.0);
                                final curvedProgress = Curves.easeInOut.transform(animProgress);
                                final leftPosition = (-cardWidth * 0.5) + (curvedProgress * (cardWidth * 1.8));
                                
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned(
                                      left: leftPosition,
                                      top: -cardHeight,
                                      bottom: -cardHeight,
                                      width: cardWidth * 0.25,
                                      child: Transform.rotate(
                                        angle: 15 * math.pi / 180,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: [
                                                Color(0x00FFFFFF),
                                                Color.fromRGBO(255, 255, 255, 0.25),
                                                Color(0x00FFFFFF),
                                              ],
                                              stops: [0.0, 0.5, 1.0],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
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
      ),
    );
  }

}