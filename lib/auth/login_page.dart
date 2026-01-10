import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:swipify/pages/home_page.dart';
import '../auth/auth_service.dart';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/services.dart' show rootBundle;

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
  final AuthService authService = AuthService();
  final PhoneAuthService phoneAuthService = PhoneAuthService();
  bool isLoading = false;
  
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
  late AnimationController _backgroundAnimationController;
  late AnimationController _gradientShiftController;
  
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
    
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatingController.dispose();
    _authMethodsController.dispose();
    _backgroundAnimationController.dispose();
    _gradientShiftController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated mesh gradient background with color shifting
        AnimatedBuilder(
          animation: _gradientShiftController,
          builder: (context, child) {
            final shift = _gradientShift.value;
            
            const bubblegumPink = Color(0xFFFF69B4);
            const chromeSilver = Color(0xFFC8C8C8);
            const digitalBlue = Color(0xFF007AFF);
            const limeFlashGreen = Color(0xFF32CD32);
            
            Color getColorForStage(Color c1, Color c2, Color c3, Color c4) {
              if (shift < 0.25) {
                return Color.lerp(c1, c2, shift * 4)!;
              } else if (shift < 0.5) {
                return Color.lerp(c2, c3, (shift - 0.25) * 4)!;
              } else if (shift < 0.75) {
                return Color.lerp(c3, c4, (shift - 0.5) * 4)!;
              } else {
                return Color.lerp(c4, c1, (shift - 0.75) * 4)!;
              }
            }
            
            final color1 = getColorForStage(
              bubblegumPink.withOpacity(0.85),
              digitalBlue.withOpacity(0.85),
              chromeSilver.withOpacity(0.95),
              limeFlashGreen.withOpacity(0.85),
            );
            
            final color2 = getColorForStage(
              digitalBlue.withOpacity(0.85),
              chromeSilver.withOpacity(0.95),
              limeFlashGreen.withOpacity(0.85),
              bubblegumPink.withOpacity(0.85),
            );
            
            final color3 = getColorForStage(
              chromeSilver.withOpacity(0.95),
              limeFlashGreen.withOpacity(0.85),
              bubblegumPink.withOpacity(0.85),
              digitalBlue.withOpacity(0.85),
            );
            
            final color4 = getColorForStage(
              limeFlashGreen.withOpacity(0.85),
              bubblegumPink.withOpacity(0.85),
              digitalBlue.withOpacity(0.85),
              chromeSilver.withOpacity(0.95),
            );
            
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color1,
                    color2,
                    color3,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.5,
                    colors: [
                      color4.withOpacity(0.7),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.bottomLeft,
                      radius: 1.8,
                      colors: [
                        color1.withOpacity(0.6),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.8],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Animated Y2K pattern overlay
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
              child: AnimatedBuilder(
                animation: _backgroundAnimationController,
                builder: (context, child) {
                  final screenHeight = MediaQuery.of(context).size.height;
                  final screenWidth = MediaQuery.of(context).size.width;
                  
                  final offset = _backgroundOffset.value;
                  final columnWidth = screenWidth / 7;
                  
                  return Stack(
                    children: [
                      // Odd columns - scrolling DOWN
                      for (int col in [0, 2, 4, 6]) ...[
                        Positioned(
                          left: col * columnWidth,
                          top: (offset % screenHeight) - screenHeight,
                          child: ClipRect(
                            child: SizedBox(
                              height: screenHeight,
                              width: columnWidth,
                              child: Opacity(
                                opacity: 0.35,
                                child: Image.asset(
                                  'assets/images/y22k.png',
                                  repeat: ImageRepeat.repeat,
                                  fit: BoxFit.none,
                                  alignment: Alignment(-1 + (col * 2 / 6), 0),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: col * columnWidth,
                          top: offset % screenHeight,
                          child: ClipRect(
                            child: SizedBox(
                              height: screenHeight,
                              width: columnWidth,
                              child: Opacity(
                                opacity: 0.35,
                                child: Image.asset(
                                  'assets/images/y22k.png',
                                  repeat: ImageRepeat.repeat,
                                  fit: BoxFit.none,
                                  alignment: Alignment(-1 + (col * 2 / 6), 0),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      
                      // Even columns - scrolling UP
                      for (int col in [1, 3, 5]) ...[
                        Positioned(
                          left: col * columnWidth,
                          top: screenHeight - (offset % screenHeight),
                          child: ClipRect(
                            child: SizedBox(
                              height: screenHeight,
                              width: columnWidth,
                              child: Opacity(
                                opacity: 0.35,
                                child: Image.asset(
                                  'assets/images/y22k.png',
                                  repeat: ImageRepeat.repeat,
                                  fit: BoxFit.none,
                                  alignment: Alignment(-1 + (col * 2 / 6), 0),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: col * columnWidth,
                          top: -(offset % screenHeight),
                          child: ClipRect(
                            child: SizedBox(
                              height: screenHeight,
                              width: columnWidth,
                              child: Opacity(
                                opacity: 0.35,
                                child: Image.asset(
                                  'assets/images/y22k.png',
                                  repeat: ImageRepeat.repeat,
                                  fit: BoxFit.none,
                                  alignment: Alignment(-1 + (col * 2 / 6), 0),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        // Vignette effect overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.15),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: showAuthMethods ? 80 : 60,
                  child: showAuthMethods
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _goBackToMainCards,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [cardHotPink, cardCyberPink],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                        spreadRadius: -2,
                                      ),
                                      BoxShadow(
                                        color: cardHotPink.withOpacity(0.5),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                isSignUp ? "Sign up" : "Log in",
                                style: const TextStyle(
                                  fontFamily: 'Circular',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: textLight,
                                ),
                              ),
                              const Spacer(),
                              const SizedBox(width: 40),
                            ],
                          ),
                        )
                      : const SizedBox(height: 60),
                ),
                
                if (!showAuthMethods)
                  const SizedBox(height: 60)
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Text(
                      isSignUp ? "How would you like to start?" : "Welcome back",
                      style: TextStyle(
                        fontFamily: 'Circular',
                        fontSize: 16,
                        color: textLight.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                
                Expanded(
                  child: RepaintBoundary(
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          child: SlideTransition(
                            position: _mainCardsSlideOut,
                            child: FadeTransition(
                              opacity: _mainCardsOpacityOut,
                              child: _buildMainCards(),
                            ),
                          ),
                        ),
                        
                        RepaintBoundary(
                          child: SlideTransition(
                            position: _authMethodsSlide,
                            child: FadeTransition(
                              opacity: _authMethodsOpacity,
                              child: _buildAuthMethodCards(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainCards() {
    return Center(
      child: SizedBox(
        height: 360,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: Listenable.merge([_entranceController, _floatingController]),
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                SlideTransition(
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
                        horizontalOffset: -65,
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
                
                SlideTransition(
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
                        horizontalOffset: 65,
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
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAuthMethodCards() {
    return Center(
      child: SizedBox(
        height: 300,
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
                  offset: Offset(-95, 10 + _floatingAnimation.value),
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
  width: 100,
  height: 100,
),
                      title: "",
                      subtitle: "Classic & private",
                      gradientColors: const [Color(0xFFFFB3C1), Color(0xFFFFCCDA)],
                      onTap: () => isSignUp 
                          ? _showEmailSignUpDialog() 
                          : _showEmailLoginDialog(),
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
                      width: 90,
                      height: 90,
                    ),
                    title: "",
                    subtitle: "One-tap access",
                    gradientColors: const [Color(0xFFE8E8FF), Color(0xFFF0F0FF)],
                    onTap: isLoading ? null : _handleGoogleSignIn,
                    showLoading: isLoading,
                    isCenter: true,
                  ),
                ),
                
                // Phone card - right with right tilt
                Transform.translate(
                  offset: Offset(95, 10 + _floatingAnimation.value),
                  child: Transform.rotate(
                    angle: 16 * math.pi / 180,
                    child: _buildScrollingAuthCard(
                      cardIndex: 2,
                      icon: Icons.phone_android_rounded,
                      title: "",
                      subtitle: "Fast & secure",
                      gradientColors: const [Color(0xFFB3D9FF), Color(0xFFCCE6FF)],
                      onTap: () => _showPhoneSignInDialog(),
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
  }

  Widget _buildScrollingAuthCard({
    required int cardIndex,
    IconData? icon,
    Widget? iconWidget,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    VoidCallback? onTap,
    bool showLoading = false,
    bool isCenter = false,
  }) {
    bool isActive = showAuthMethods && _activeCardIndex == cardIndex;
    bool isHovered = showAuthMethods && _hoveredCardIndex == cardIndex;
    
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
        behavior: HitTestBehavior.opaque,
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
          child: Container(
            width: 145,
            height: isCenter ? 235 : 215,
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
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Stack(
                  children: [
                    // Large icon at the top
                    Positioned(
                      top: 25,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: isHovered ? 1.0 : 0.5,
                          duration: const Duration(milliseconds: 200),
                          child: showLoading
                              ? const SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                )
                              : (iconWidget != null
                                  ? SizedBox(
                                      width: 90,
                                      height: 90,
                                      child: iconWidget,
                                    )
                                  : Icon(
                                      icon,
                                      size: 90,
                                      color: Colors.white,
                                    )),
                        ),
                      ),
                    ),
                    
                    // Single-word label at bottom
                    Positioned(
                      bottom: 30,
                      left: 0,
                      right: 0,
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Circular',
                          fontSize: 24,
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
    required List<Color> gradientColors,
    required Color accentColor,
    required String decorationType,
    required VoidCallback onTap,
  }) {
    bool isActive = !showAuthMethods && _activeCardIndex == cardIndex;
    bool isHovered = !showAuthMethods && _hoveredCardIndex == cardIndex;
    
    return Transform.translate(
      offset: Offset(horizontalOffset, isActive ? -20.0 : 0.0),
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
              behavior: HitTestBehavior.opaque,
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
                child: Container(
                  width: 220,
                  height: 280,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: isHovered ? Alignment.bottomCenter : Alignment.bottomRight,
                      colors: [
                        gradientColors[0].withOpacity(isHovered ? 0.75 : 0.65),
                        gradientColors[1].withOpacity(isHovered ? 0.6 : 0.5),
                        gradientColors[2].withOpacity(isHovered ? 0.45 : 0.35),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: isActive ? 50 : isHovered ? 40 : 30,
                        offset: Offset(0, isActive ? 30.0 : isHovered ? 22.0 : 15.0),
                        spreadRadius: -5,
                      ),
                      BoxShadow(
                        color: accentColor.withOpacity(isActive ? 0.6 : isHovered ? 0.5 : 0.4),
                        blurRadius: isActive ? 45 : isHovered ? 35 : 28,
                        offset: Offset(0, isActive ? 15.0 : isHovered ? 10.0 : 6.0),
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
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontFamily: 'Circular',
                                fontSize: 36,
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
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.85),
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
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
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

  // Build password requirement indicator
  Widget _buildPasswordRequirement(String text, bool isMet) {
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
  
  // Build password requirements section
  Widget _buildPasswordRequirements() {
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
          _buildPasswordRequirement("At least 8 characters", _hasMinLength),
          _buildPasswordRequirement("One uppercase letter", _hasUppercase),
          _buildPasswordRequirement("One number", _hasNumber),
          _buildPasswordRequirement("One special character (!@#\$%^&*)", _hasSpecialChar),
        ],
      ),
    );
  }

  // Show email verification dialog
  void _showEmailVerificationDialog(String email,{String? password}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext dialogContext) => Dialog(
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
                    animation: _floatingController,
                    builder: (context, child) {
                      final offset = _floatingAnimation.value / 50;
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
                            // Continue button
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
                                  Navigator.pop(dialogContext);
                                  await FirebaseAuth.instance.signOut();
                                  _showSnackBar(
                                    "Please verify your email before logging in",
                                    accentGlow,
                                  );
                                },
                                child: const Text(
                                  "Got it!",
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
                                      "Verification email sent again!",
                                      accentGlow,
                                    );
                                  } else if (user?.emailVerified == true) {
                                    print('⚠️ Email already verified');
                                    _showSnackBar(
                                      "Email already verified! Try logging in.",
                                      Colors.green,
                                    );
                                  } else {
                                    print('❌ No user found');
                                    _showSnackBar(
                                      "Please sign up first.",
                                      Colors.orange,
                                    );
                                  }
                                } catch (e) {
                                  print('❌ Error resending email: $e');
                                  if (e.toString().contains('too-many-requests')) {
                                    _showSnackBar(
                                      "Too many requests. Please wait a few minutes.",
                                      Colors.orange,
                                    );
                                  } else {
                                    _showSnackBar(
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
      ),
    );
  }

  // Show email not verified dialog (for login attempts)
  void _showEmailNotVerifiedDialog(String email) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext dialogContext) => Dialog(
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
                    color: Colors.orange.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Animated color mesh gradient background
                  AnimatedBuilder(
                    animation: _floatingController,
                    builder: (context, child) {
                      final offset = _floatingAnimation.value / 50;
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: LinearGradient(
                            begin: Alignment(offset, -1.0 + offset),
                            end: Alignment(-offset, 1.0 - offset),
                            colors: [
                              Colors.orange.withOpacity(0.85),
                              Colors.deepOrange.withOpacity(0.75),
                              cardHotPink.withOpacity(0.7),
                              cardNeonPurple.withOpacity(0.65),
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
                          "Please verify your email address before logging in. Check your inbox for the verification link.",
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
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                color: Colors.white.withOpacity(0.9),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Already verified? Try logging in again after clicking the link",
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
                        ),
                        const SizedBox(height: 32),
                        
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
                                  foregroundColor: Colors.orange,
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
                                        "Verification email sent!",
                                        accentGlow,
                                      );
                                    }
                                  } catch (e) {
                                    print('❌ Error resending: $e');
                                    if (e.toString().contains('too-many-requests')) {
                                      _showSnackBar(
                                        "Too many requests. Wait a few minutes.",
                                        Colors.orange,
                                      );
                                    } else {
                                      _showSnackBar(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPhoneSignInDialog() {
    final phoneCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String verificationId = '';
    bool codeSent = false;
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: keyboardHeight > 0 ? 16 : 24,
            ),
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
                        animation: _floatingController,
                        builder: (context, child) {
                          final offset = _floatingAnimation.value / 50;
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
                              padding: const EdgeInsets.fromLTRB(32, 32, 24, 20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          codeSent ? "Verify your number" : "Phone Sign In",
                                          style: const TextStyle(
                                            fontFamily: 'Circular',
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => Navigator.pop(dialogContext),
                                    icon: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: Colors.white.withOpacity(0.9),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Content
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                32,
                                0,
                                32,
                                keyboardHeight > 0 ? 24 : 32,
                              ),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                                      accentGlow,
                                                    );
                                                  },
                                                  onError: (String error) {
                                                    setDialogState(() => isProcessing = false);
                                                    _showSnackBar(error, Colors.red);
                                                  },
                                                );
                                              } else {
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
                                                    accentGlow,
                                                  );
                                                  _navigateToHome();
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
      ),
    );
  }

  void _showEmailSignUpDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isProcessing = false;
    
    // Reset validation when dialog opens
    _resetValidation();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: keyboardHeight > 0 ? 16 : 24,
            ),
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
                        animation: _floatingController,
                        builder: (context, child) {
                          final offset = _floatingAnimation.value / 50;
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
                              padding: const EdgeInsets.fromLTRB(32, 32, 24, 20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          "Create Account",
                                          style: TextStyle(
                                            fontFamily: 'Circular',
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      _resetValidation();
                                      Navigator.pop(dialogContext);
                                    },
                                    icon: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: Colors.white.withOpacity(0.9),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Content
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                32,
                                0,
                                32,
                                keyboardHeight > 0 ? 24 : 32,
                              ),
                              child: Column(
                                children: [
                                  _buildModernTextField(
                                    nameCtrl,
                                    "Username",
                                    hint: "fiery phoenix",
                                    icon: Icons.person_outline,
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
                                        _validateEmail(value);
                                      });
                                    },
                                  ),
                                  // Email validation indicator
                                  if (emailCtrl.text.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _isValidEmail ? Icons.check_circle : Icons.cancel,
                                            size: 16,
                                            color: _isValidEmail ? Colors.green : Colors.red.shade300,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _isValidEmail ? "Valid email" : "Invalid email format",
                                            style: TextStyle(
                                              fontFamily: 'Circular',
                                              color: _isValidEmail ? Colors.green : Colors.red.shade300,
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
                                        _validatePassword(value);
                                      });
                                    },
                                  ),
                                  // Password requirements
                                  if (passCtrl.text.isNotEmpty)
                                    _buildPasswordRequirements(),
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
                                              // Validate before proceeding
                                              if (!_isValidEmail) {
                                                _showSnackBar("Please enter a valid email", Colors.orange);
                                                return;
                                              }
                                              
                                              if (!(_hasMinLength && _hasUppercase && _hasNumber && _hasSpecialChar)) {
                                                _showSnackBar("Password doesn't meet requirements", Colors.orange);
                                                return;
                                              }
                                              
                                              setDialogState(() => isProcessing = true);
                                              _resetValidation();
                                              Navigator.pop(dialogContext);
                                              await _handleEmailSignUp(
                                                nameCtrl.text.trim(),
                                                emailCtrl.text.trim(),
                                                passCtrl.text.trim(),
                                              );
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
      ),
    );
  }

  void _showEmailLoginDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isProcessing = false;
    
    // Reset validation when dialog opens
    _resetValidation();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: keyboardHeight > 0 ? 16 : 24,
            ),
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
                        animation: _floatingController,
                        builder: (context, child) {
                          final offset = _floatingAnimation.value / 50;
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
                              padding: const EdgeInsets.fromLTRB(32, 32, 24, 20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          "Welcome Back",
                                          style: TextStyle(
                                            fontFamily: 'Circular',
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      _resetValidation();
                                      Navigator.pop(dialogContext);
                                    },
                                    icon: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: Colors.white.withOpacity(0.9),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Content
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                32,
                                0,
                                32,
                                keyboardHeight > 0 ? 24 : 32,
                              ),
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
                                        _validateEmail(value);
                                      });
                                    },
                                  ),
                                  // Email validation indicator
                                  if (emailCtrl.text.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _isValidEmail ? Icons.check_circle : Icons.cancel,
                                            size: 16,
                                            color: _isValidEmail ? Colors.green : Colors.red.shade300,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _isValidEmail ? "Valid email" : "Invalid email format",
                                            style: TextStyle(
                                              fontFamily: 'Circular',
                                              color: _isValidEmail ? Colors.green : Colors.red.shade300,
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
                                              if (!_isValidEmail) {
                                                _showSnackBar("Please enter a valid email", Colors.orange);
                                                return;
                                              }
                                              
                                              setDialogState(() => isProcessing = true);
                                              _resetValidation();
                                              Navigator.pop(dialogContext);
                                              await _handleEmailLogin(
                                                emailCtrl.text.trim(),
                                                passCtrl.text.trim(),
                                              );
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
      ),
    );
  }

  Widget _buildModernTextField(
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
            color: Colors.white.withOpacity(0.95),
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
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              filled: false,
              hintText: hint,
              counterText: "",
              hintStyle: TextStyle(
                fontFamily: 'Circular',
                color: textDark.withOpacity(0.4),
                fontWeight: FontWeight.w400,
                fontSize: 15,
              ),
              prefixIcon: icon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 16, right: 12),
                      child: Icon(
                        icon,
                        color: textDark.withOpacity(0.5),
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

  Future<void> _handleGoogleSignIn() async {
    setState(() => isLoading = true);

    try {
      final user = await authService.signInWithGoogle();

      if (!mounted) return;

      if (user != null) {
        _showSnackBar("Welcome ${user.displayName ?? 'User'}!", accentGlow);
        _navigateToHome();
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

  Future<void> _handleEmailSignUp(
      String name, String email, String password) async {
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar("Please fill in all fields", Colors.orange);
      return;
    }

    if (password.length < 8) {
      _showSnackBar("Password must be at least 8 characters", Colors.orange);
      return;
    }
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      _showSnackBar("Password must contain at least one uppercase letter", Colors.orange);
      return;
    }
    
    if (!password.contains(RegExp(r'[0-9]'))) {
      _showSnackBar("Password must contain at least one number", Colors.orange);
      return;
    }
    
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      _showSnackBar("Password must contain at least one special character", Colors.orange);
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
        // Send verification email with better error handling
        try {
          await user.sendEmailVerification();
          print('✅ Verification email sent successfully to: $email');
          
          // Show verification dialog
          _showEmailVerificationDialog(email);
          
          setState(() => isLoading = false);
        } catch (emailError) {
          print('❌ Error sending verification email: $emailError');
          
          // Still show the dialog but with a warning
          setState(() => isLoading = false);
          
          _showSnackBar(
            "Account created! Please check if you received the verification email.",
            Colors.orange,
          );
          
          // Show the dialog anyway so user can resend
          _showEmailVerificationDialog(email);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      _showSnackBar(_getErrorMessage(e), Colors.red);
      setState(() => isLoading = false);
    } catch (e) {
      if (!mounted) return;
      print('❌ General Error: $e');
      _showSnackBar("An error occurred. Please try again.", Colors.red);
      setState(() => isLoading = false);
    }
  }

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
        // Check if email is verified
        await user.reload(); // Refresh user data
        final currentUser = FirebaseAuth.instance.currentUser;
        
        if (currentUser != null && !currentUser.emailVerified) {
          // Email not verified - show dialog
          setState(() => isLoading = false);
          _showEmailNotVerifiedDialog(email);
        } else {
          // Email verified - proceed to home
          _showSnackBar("Welcome back!", accentGlow);
          _navigateToHome();
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnackBar(_getErrorMessage(e), Colors.red);
      setState(() => isLoading = false);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("An error occurred. Please try again.", Colors.red);
      setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
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