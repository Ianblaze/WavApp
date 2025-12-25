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
      duration: const Duration(milliseconds: 1400), // Slower, more graceful
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
      duration: const Duration(milliseconds: 120000), // 120 seconds - slower and more subtle
      vsync: this,
    )..repeat(); // Continuous loop, no reverse
    
    _gradientShiftController = AnimationController(
      duration: const Duration(milliseconds: 25000), // 25 seconds - much slower and more ambient
      vsync: this,
    )..repeat(); // Continuous loop
    
    _slideAnimation1 = Tween<Offset>(
      begin: const Offset(0, 1.2), // Less dramatic
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutQuart), // Smoother curve
    ));
    
    _slideAnimation2 = Tween<Offset>(
      begin: const Offset(0, 1.2), // Less dramatic
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.1, 0.85, curve: Curves.easeOutQuart), // Smoother curve
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
      end: 1000.0, // Will use modulo with screen height in builder
    ).animate(CurvedAnimation(
      parent: _backgroundAnimationController,
      curve: Curves.linear, // Linear for smooth continuous scrolling
    ));
    
    _gradientShift = Tween<double>(
      begin: 0.0,
      end: 1.0, // Full cycle from 0 to 1
    ).animate(CurvedAnimation(
      parent: _gradientShiftController,
      curve: Curves.easeInOutSine, // More organic, wave-like motion
    ));
    
    // Start entrance animation immediately - it will sync perfectly with page transition
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
            
            // Custom color palette from user
            const bubblegumPink = Color(0xFFFF69B4); // RGB 255, 105, 180
            const chromeSilver = Color(0xFFC8C8C8);  // RGB 200, 200, 200
            const digitalBlue = Color(0xFF007AFF);   // RGB 0, 122, 255
            const limeFlashGreen = Color(0xFF32CD32); // RGB 50, 205, 50
            
            // Create a 4-stage color cycle for organic smooth transitions
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
            
            // Apply even higher opacity for maximum vibrancy
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
        height: 360, // Increased for larger cards
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
                        horizontalOffset: -85, // Increased separation
                        gradientColors: const [
                          Color(0xFFFFB8E6), // Warmer, more inviting pink
                          Color(0xFFFFD8F0), // Softer rose
                          Color(0xFFFFE8F7), // Lightest pink edge
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
                        horizontalOffset: 85, // Increased separation
                        gradientColors: const [
                          Color(0xFFB8DCFF), // Cooler, calmer blue
                          Color(0xFFD8EBFF), // Soft sky
                          Color(0xFFE8F4FF), // Lightest blue edge
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
        height: 280,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _floatingController,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Transform.translate(
                  offset: Offset(0, _floatingAnimation.value * 0.5),
                  child: _buildAuthCard(
                    cardIndex: 0,
                    icon: Icons.email_rounded,
                    title: "Email",
                    subtitle: "Classic & private",
                    rotation: -12,
                    horizontalOffset: -80,
                    verticalOffset: 25,
                    gradientColors: const [cardHotPink, cardCyberPink],
                    onTap: () => isSignUp 
                        ? _showEmailSignUpDialog() 
                        : _showEmailLoginDialog(),
                  ),
                ),
                
                Transform.translate(
                  offset: Offset(0, -_floatingAnimation.value * 0.3),
                  child: _buildAuthCard(
                    cardIndex: 1,
                    iconWidget: SvgPicture.string(
                      '''<svg width="26" height="26" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
                        <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
                        <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
                        <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
                      </svg>''',
                      width: 26,
                      height: 26,
                    ),
                    title: "Google",
                    subtitle: "One-tap access",
                    rotation: 0,
                    horizontalOffset: 0,
                    verticalOffset: 0,
                    gradientColors: const [cardNeonPurple, cardLavenderPop],
                    onTap: isLoading ? null : _handleGoogleSignIn,
                    showLoading: isLoading,
                    isCenter: true,
                  ),
                ),
                
                Transform.translate(
                  offset: Offset(0, _floatingAnimation.value * 0.5),
                  child: _buildAuthCard(
                    cardIndex: 2,
                    icon: Icons.phone_android_rounded,
                    title: "Phone",
                    subtitle: "Fast & secure",
                    rotation: 12,
                    horizontalOffset: 80,
                    verticalOffset: 25,
                    gradientColors: const [cardElectricBlue, cardDigitalBlue],
                    onTap: () => _showPhoneSignInDialog(),
                  ),
                ),
              ],
            );
          },
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
      offset: Offset(horizontalOffset, (-(isActive ? 20 : 0)) as double),
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
              onTap: () {
                if (!showAuthMethods) {
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      width: 220, // Wider for text
                      height: 280, // Taller for text wrapping
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
                        borderRadius: BorderRadius.circular(28), // More generous corners
                        boxShadow: [
                          // Main depth shadow
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: isActive ? 50 : isHovered ? 40 : 30,
                            offset: Offset(0, isActive ? 30 : isHovered ? 22 : 15),
                            spreadRadius: -5,
                          ),
                          // Colored glow shadow (using accent color)
                          BoxShadow(
                            color: accentColor.withOpacity(isActive ? 0.6 : isHovered ? 0.5 : 0.4),
                            blurRadius: isActive ? 45 : isHovered ? 35 : 28,
                            offset: Offset(0, isActive ? 15 : isHovered ? 10 : 6),
                          ),
                          // Inner highlight (3D effect)
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 2,
                            offset: const Offset(0, -1),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Stack(
                          children: [
                            if (isHovered)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withOpacity(0.2),
                                        Colors.white.withOpacity(0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            
                            // Dark gradient overlay for text contrast
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.35),
                                      Colors.black.withOpacity(0.15),
                                      Colors.black.withOpacity(0.4),
                                    ],
                                    stops: const [0.0, 0.4, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            
                            // Abstract Y2K decoration instead of literal icon
                            if (decorationType == 'blob') ...[
                              // Large outer blob
                              Positioned(
                                top: -30,
                                right: -30,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.2),
                                        Colors.white.withOpacity(0.08),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.6, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // Medium inner blob (offset for organic feel)
                              Positioned(
                                top: -10,
                                right: -15,
                                child: Container(
                                  width: 85,
                                  height: 85,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        accentColor.withOpacity(0.15),
                                        accentColor.withOpacity(0.05),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // Small bright highlight blob
                              Positioned(
                                top: 15,
                                right: 10,
                                child: Container(
                                  width: 35,
                                  height: 35,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.3),
                                        Colors.white.withOpacity(0.1),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.4, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            
                            if (decorationType == 'streak') ...[
                              // Top long streak (brightest)
                              Positioned(
                                top: 25,
                                right: -15,
                                child: Transform.rotate(
                                  angle: -0.35,
                                  child: Container(
                                    width: 95,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2.5),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.4),
                                          Colors.white.withOpacity(0.15),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.6, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Middle streak (accent colored)
                              Positioned(
                                top: 38,
                                right: -8,
                                child: Transform.rotate(
                                  angle: -0.35,
                                  child: Container(
                                    width: 70,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      gradient: LinearGradient(
                                        colors: [
                                          accentColor.withOpacity(0.3),
                                          accentColor.withOpacity(0.1),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Bottom short streak (subtle)
                              Positioned(
                                top: 48,
                                right: -3,
                                child: Transform.rotate(
                                  angle: -0.35,
                                  child: Container(
                                    width: 50,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(1.5),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.25),
                                          Colors.white.withOpacity(0.08),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.4, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Glass highlight dot (Y2K detail)
                              Positioned(
                                top: 60,
                                right: 8,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.35),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withOpacity(0.3),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                        
                        Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between top and bottom
                            children: [
                              // Title at top (Sign up / Log in)
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 36, // Large, prominent title
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.0,
                                  letterSpacing: -0.8,
                                  fontFamily: 'Circular',
                                ),
                              ),
                              // Subtitle at bottom (descriptive text)
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 16, // Smaller than title
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.85),
                                  letterSpacing: 0.2,
                                  height: 1.3,
                                  fontFamily: 'Circular',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.visible,
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
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildAuthCard({
    required int cardIndex,
    IconData? icon,
    Widget? iconWidget,
    required String title,
    required String subtitle,
    required double rotation,
    required double horizontalOffset,
    required double verticalOffset,
    required List<Color> gradientColors,
    VoidCallback? onTap,
    bool showLoading = false,
    bool isCenter = false,
  }) {
    bool isActive = showAuthMethods && _activeCardIndex == cardIndex;
    bool isHovered = showAuthMethods && _hoveredCardIndex == cardIndex;
    
    return Transform.translate(
      offset: Offset(horizontalOffset, verticalOffset - (isActive ? 20 : 0)),
      child: Transform.rotate(
        angle: rotation * math.pi / 180,
        child: Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateY(horizontalOffset > 0 ? -0.04 : horizontalOffset < 0 ? 0.04 : 0)
            ..rotateX(0.015),
          alignment: Alignment.center,
          child: MouseRegion(
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
              onTap: () {
                if (showAuthMethods && onTap != null) {
                  onTap();
                }
              },
              onTapCancel: () {
                if (showAuthMethods) {
                  setState(() => _activeCardIndex = null);
                }
              },
              child: AnimatedScale(
                scale: isHovered ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      width: isCenter ? 150 : 135,
                      height: isCenter ? 210 : 190,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            gradientColors[0].withOpacity(0.6),
                            gradientColors[1].withOpacity(0.4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          // Main depth shadow
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: isActive ? 50 : isHovered ? 40 : (isCenter ? 30 : 22),
                            offset: Offset(0, isActive ? 30 : isHovered ? 22 : (isCenter ? 15 : 10)),
                            spreadRadius: -5,
                          ),
                          // Colored glow shadow
                          BoxShadow(
                            color: gradientColors[0].withOpacity(isActive ? 0.5 : isHovered ? 0.4 : 0.3),
                            blurRadius: isActive ? 40 : isHovered ? 32 : (isCenter ? 25 : 18),
                            offset: Offset(0, isActive ? 15 : isHovered ? 10 : (isCenter ? 6 : 4)),
                          ),
                          // Inner highlight (3D effect)
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 2,
                            offset: const Offset(0, -1),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Stack(
                          children: [
                            if (isHovered)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withOpacity(0.3),
                                        Colors.white.withOpacity(0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            
                            Positioned(
                              top: -10,
                              right: -10,
                              child: Icon(
                                Icons.music_note_rounded,
                                size: 70,
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.2),
                                      blurRadius: 6,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: showLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : iconWidget ?? Icon(
                                        icon,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                    textAlign: TextAlign.center,
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
            ),
          ),
        ),
      ),
    ));
  }

  // ... (keeping all the remaining methods unchanged: _navigateToHome, _showPhoneSignInDialog, _showEmailSignUpDialog, etc.)
  // For brevity, I'll include a note that the dialog methods remain the same as the original

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
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
      barrierColor: Colors.black87,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cardHotPink.withOpacity(0.7),
                        cardCyberPink.withOpacity(0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      // Main depth shadow
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                        spreadRadius: -5,
                      ),
                      // Colored glow
                      BoxShadow(
                        color: cardHotPink.withOpacity(0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                      // Inner highlight
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 2,
                        offset: const Offset(0, -1),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        codeSent ? "Enter code" : "Phone ${isSignUp ? 'sign up' : 'log in'}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (!codeSent) ...[
                    _buildDialogTextField(
                      phoneCtrl,
                      "Phone number",
                      hint: "+919876543210",
                      icon: Icons.phone_rounded,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Include country code (e.g., +91 for India)",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                      ),
                    ),
                  ] else ...[
                    _buildDialogTextField(
                      codeCtrl,
                      "Verification code",
                      hint: "123456",
                      icon: Icons.lock_rounded,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Enter the 6-digit code sent to your phone",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: textDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
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
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: textDark,
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
            ),
          ),
        );
        },
    ));
  }

  void _showEmailSignUpDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cardHotPink.withOpacity(0.7),
                    cardCyberPink.withOpacity(0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  // Main depth shadow
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                    spreadRadius: -5,
                  ),
                  // Colored glow
                  BoxShadow(
                    color: cardHotPink.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                  // Inner highlight
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, -1),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Create account",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDialogTextField(nameCtrl, "Name", icon: Icons.person_rounded),
              const SizedBox(height: 16),
              _buildDialogTextField(emailCtrl, "Email", icon: Icons.email_rounded),
              const SizedBox(height: 16),
              _buildDialogTextField(passCtrl, "Password",
                  isPassword: true, icon: Icons.lock_rounded),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: textCard,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
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
    ),
  ));
}

void _showEmailLoginDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cardElectricBlue.withOpacity(0.7),
                    cardDigitalBlue.withOpacity(0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  // Main depth shadow
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                    spreadRadius: -5,
                  ),
                  // Colored glow
                  BoxShadow(
                    color: cardElectricBlue.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                  // Inner highlight
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, -1),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Welcome back",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDialogTextField(emailCtrl, "Email", icon: Icons.email_rounded),
              const SizedBox(height: 16),
              _buildDialogTextField(passCtrl, "Password",
                  isPassword: true, icon: Icons.lock_rounded),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: textCard,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
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
    ),
  ));
}

Widget _buildDialogTextField(
    TextEditingController controller,
    String label, {
    bool isPassword = false,
    String? hint,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white,
              width: 2,
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
            style: const TextStyle(
              color: textDark,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              filled: false,
              hintText: hint ?? label,
              hintStyle: TextStyle(
                color: textDark.withOpacity(0.4),
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: icon != null
                  ? Icon(icon, color: textDark.withOpacity(0.6), size: 20)
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
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
        _showSnackBar("Account created successfully!", accentGlow);
        _navigateToHome();
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
        _showSnackBar("Welcome back!", accentGlow);
        _navigateToHome();
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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
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