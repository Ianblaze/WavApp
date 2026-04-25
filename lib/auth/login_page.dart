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
    
    // 5.5s total: 3.5s animation + 2s delay
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
      end: Offset.zero,
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
    
    // Tick match count every 3.8 seconds for social proof (per design)
    _matchTimer = Timer.periodic(const Duration(milliseconds: 3800), (_) {
      if (mounted) {
        setState(() {
          _matchCount = 35 + (DateTime.now().millisecondsSinceEpoch % 40).toInt();
        });
      }
    });
    
    // Session persistence is handled by Firebase Auth natively.
    // AuthWrapper observes idTokenChanges() and routes accordingly.

    // Automate entrance if showing cards immediately
    if (!showLanding) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _entranceController.forward();
      });
    }
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
    _authMethodsController.forward();
  }
  
  void _goBackToMainCards() {
    if (_authMethodsController.isAnimating) return;
    
    _authMethodsController.reverse().then((_) {
      if (mounted) {
        setState(() {
          showAuthMethods = false;
          _hoveredCardIndex = null;
          _activeCardIndex = null;
        });
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Minimal Pastel Background (Per Design) ──
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFDE8FF), // Soft pastel pale pink at top
                    Color(0xFFE5DEFF), // Very soft lavender in middle
                    Color(0xFFD6EBFF), // Soft icy blue at bottom
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // ── Main Content Area ──
          SafeArea(
            child: Column(
              children: [
                // Header (Back navigation or spacing)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: showAuthMethods ? 80 : 60,
                  child: showAuthMethods
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          child: Row(
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _goBackToMainCards,
                                  borderRadius: BorderRadius.circular(24),
                                  splashColor: Colors.white.withOpacity(0.3),
                                  highlightColor: Colors.white.withOpacity(0.1),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    child: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const Spacer(),
                              const SizedBox(width: 40),
                            ],
                          ),
                        )
                      : const SizedBox(height: 60),
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
                        SizedBox(height: h * 0.03),
                        _buildAnimatedWaveform(),
                      ],
                    );
                  }
                ),

                const Spacer(flex: 4), // Big gap down to social proof block

                // ── Social Proof Avatars ── 
                _buildSocialProofAvatars(),
                
                const Spacer(flex: 2),
                
                // Cards Stack Area
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.52, // Responsive height
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
                                child: _buildAuthMethodCards(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // ── Guest Mode Link ──
                GestureDetector(
                  onTap: isLoading
                      ? null
                      : () async {
                          setState(() => isLoading = true);
                          try {
                            await context.read<AuthProvider>().signInAsGuest();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Guest login failed: $e',
                                    style: const TextStyle(fontFamily: 'Circular', color: Colors.white)),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ));
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
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text(e.message,
                                            style: const TextStyle(fontFamily: 'Circular', color: Colors.white, fontWeight: FontWeight.w600)),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        margin: const EdgeInsets.all(16),
                                      ));
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                      content: Text('Sign-in failed', style: TextStyle(fontFamily: 'Circular', color: Colors.white)),
                                      backgroundColor: Colors.orange,
                                      behavior: SnackBarBehavior.floating,
                                    ));
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gradientColors[0].withOpacity(isHovered ? 0.85 : 0.7),
                  gradientColors[1].withOpacity(isHovered ? 0.65 : 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: isActive ? 35 : isHovered ? 28 : 22,
                  offset: Offset(0, isActive ? 20.0 : isHovered ? 16.0 : 12.0),
                  spreadRadius: -5,
                ),
                BoxShadow(
                  color: gradientColors[0].withOpacity(isActive ? 0.7 : isHovered ? 0.6 : 0.3),
                  blurRadius: isActive ? 30 : isHovered ? 24 : 18,
                  offset: Offset(0, isActive ? 10.0 : isHovered ? 8.0 : 5.0),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Stack(
                      children: [
                        // Large icon at the top
                        Positioned(
                          top: cardHeight * 0.12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: isHovered ? 1.0 : 0.5,
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
                                        )),
                            ),
                          ),
                        ),
                        
                        // Single-word label at bottom
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
                            ),
                            textAlign: TextAlign.center,
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
                          // The shimmer animates over 3.5s, then waits 2s (Total 5.5s)
                          final activeFraction = 3.5 / 5.5;
                          final progress = _shimmerController.value;
                          final animProgress = (progress / activeFraction).clamp(0.0, 1.0);
                          final curvedProgress = Curves.easeInOut.transform(animProgress);
                          
                          // Position the left edge sweeping smoothly across
                          // Starts heavily off-screen left, ends heavily off-screen right
                          final leftPosition = (-cardWidth * 0.5) + (curvedProgress * (cardWidth * 1.8));
                          
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: leftPosition,
                                top: -cardHeight, // Massive height to prevent clipped corners when rotated
                                bottom: -cardHeight,
                                width: cardWidth * 0.25, // Exactly 25% of card width for the precise beam
                                child: Transform.rotate(
                                  angle: 15 * math.pi / 180, // 15-degree tilt matching reference
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0x00FFFFFF), // Transparent white prevents black interpolation
                                          Color.fromRGBO(255, 255, 255, 0.25), // 25% brightness peak
                                          Color(0x00FFFFFF),
                                        ],
                                        // Soft wash sweeping across the 25% box
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
                  width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: isHovered ? Alignment.bottomCenter : Alignment.bottomRight,
                  colors: [
                    gradientColors[0].withOpacity(isHovered ? 0.95 : 0.85),
                    gradientColors[1].withOpacity(isHovered ? 0.8 : 0.7),
                    if (gradientColors.length > 2) gradientColors[2].withOpacity(isHovered ? 0.65 : 0.55),
                  ],
                  // Handle variable length gradient properly
                  stops: gradientColors.length == 3 ? const [0.0, 0.5, 1.0] : const [0.0, 1.0],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08), // Softer shadow for pastel theme
                  blurRadius: isActive ? 40 : isHovered ? 30 : 20,
                  offset: Offset(0, isActive ? 20.0 : isHovered ? 15.0 : 10.0),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: accentColor.withOpacity(isActive ? 0.4 : isHovered ? 0.3 : 0.15),
                  blurRadius: isActive ? 35 : isHovered ? 25 : 18,
                  offset: Offset(0, isActive ? 10.0 : isHovered ? 6.0 : 4.0),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.5), // Stronger white highlight top
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.0,
                              letterSpacing: -0.8,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontSize: subtitleFontSize,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.95), // Crisper contrast since cards are lighter
                              letterSpacing: 0.2,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // -- The Shimmer Overlay --
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          // The shimmer animates over 3.5s, then waits 2s (Total 5.5s)
                          final activeFraction = 3.5 / 5.5;
                          final progress = _shimmerController.value;
                          final animProgress = (progress / activeFraction).clamp(0.0, 1.0);
                          final curvedProgress = Curves.easeInOut.transform(animProgress);
                          
                          // Position the left edge sweeping smoothly across
                          // Starts heavily off-screen left, ends heavily off-screen right
                          final leftPosition = (-cardWidth * 0.5) + (curvedProgress * (cardWidth * 1.8));
                          
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: leftPosition,
                                top: -cardHeight, // Massive height to prevent clipped corners when rotated
                                bottom: -cardHeight,
                                width: cardWidth * 0.25, // Exactly 25% of card width for the precise beam
                                child: Transform.rotate(
                                  angle: 15 * math.pi / 180, // 15-degree tilt matching reference
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0x00FFFFFF), // Transparent white prevents black interpolation
                                          Color.fromRGBO(255, 255, 255, 0.25), // 25% brightness peak
                                          Color(0x00FFFFFF),
                                        ],
                                        // Soft wash sweeping across the 25% box
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

  Widget _buildAnimatedWaveform() {
    final baseHeights = [
      0.1, 0.2, 0.1, 0.4, 0.6, 0.4, 0.8, 1.0, 0.8, 0.3,
      0.5, 0.8, 0.4, 0.8, 0.6, 0.3, 0.5, 0.2, 0.1
    ];
    
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFFB3D9FF), // soft blue
          Color(0xFFFFB3E6), // soft pink
          Color(0xFFD9B3FF), // soft purple
        ],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: SizedBox(
        height: 24, // max height
        child: AnimatedBuilder(
          animation: _floatingController,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(baseHeights.length, (i) {
                // Wave harmonic calculations
                final base = baseHeights[i];
                final phase = i * 0.4;
                final wave = (math.sin((_floatingController.value * math.pi * 4) + phase) + 1) / 2.0;
                final dynamicHeight = base * (0.6 + (0.4 * wave)); // varies between 60%-100% of base height
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.0),
                  width: 4.5,
                  height: 24 * dynamicHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            );
          }
        ),
      ),
    );
  }

  Widget _buildSocialProofAvatars() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          width: 48 + (3 * 34), // Approx width considering overlap
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _buildAvatar(0, Colors.pinkAccent.withOpacity(0.5)),
              _buildAvatar(1, Colors.purpleAccent.withOpacity(0.5)),
              _buildAvatar(2, Colors.lightBlueAccent.withOpacity(0.5)),
              _buildAvatarPlaceholder(3),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "join 2,400+ music lovers",
          style: TextStyle(
            fontFamily: 'Circular',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8B84A6).withOpacity(0.9), // Muted lavender-grey
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(int index, Color fallbackColor) {
    return Positioned(
      left: index * 32.0,
      child: AnimatedBuilder(
        animation: _floatingController,
        builder: (context, child) {
          // Calculate an offset phase so each orb bounces slightly after the previous one
          final bounce = math.sin((_floatingController.value * math.pi * 2) + (index * 0.8)) * 3.5;
          return Transform.translate(
            offset: Offset(0, bounce),
            child: child,
          );
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
          color: fallbackColor,
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ]
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Switched to locally downloaded stock assets to bypass Chrome CORS network blocks
              Image.asset(
                'assets/images/avatar${index + 1}.jpg', // avatar1.jpg, avatar2.jpg, avatar3.jpg
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(),
              ),
              // Increased blur for more stylistic privacy/aesthetic as requested
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                child: Container(color: Colors.transparent),
              ),
            ],
          ),
        ),
      ),
        ),
    );
  }

  Widget _buildAvatarPlaceholder(int index) {
    return Positioned(
      left: index * 32.0,
      child: AnimatedBuilder(
        animation: _floatingController,
        builder: (context, child) {
          final bounce = math.sin((_floatingController.value * math.pi * 2) + (index * 0.8)) * 3.5;
          return Transform.translate(
            offset: Offset(0, bounce),
            child: child,
          );
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.25), // Frosted
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ]
        ),
        child: const Center(
          child: Icon(Icons.add, color: Colors.white, size: 20),
        ),
      ),
        ),
    );
  }
}