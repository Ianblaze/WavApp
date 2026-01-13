import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipify/pages/home_page.dart';
import '../auth/auth_service.dart';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'login_dialogs.dart'; // Import the dialogs helper

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
    
    // Check for auto-login (Remember Me)
    _checkAutoLogin();
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

  void _navigateToHome() {
    print('🏠 _navigateToHome called!');
    print('📍 Context: $context');
    print('🔄 Navigating to HomePage...');
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
    
    print('✅ Navigation initiated!');
  }

  // Auto-login check (Remember Me functionality)
  Future<void> _checkAutoLogin() async {
    print('🔄 Checking for auto-login...');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me') ?? false;
      
      if (!rememberMe) {
        print('❌ Remember me not enabled');
        return;
      }
      
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // User is already logged in
        await user.reload();
        final currentUser = FirebaseAuth.instance.currentUser;
        
        if (currentUser != null && currentUser.emailVerified) {
          // User is verified, auto-login!
          print('✅ Auto-login successful for: ${currentUser.email}');
          
          if (mounted) {
            _navigateToHome();
          }
        } else if (currentUser != null && !currentUser.emailVerified) {
          // User exists but not verified
          print('⚠️  User not verified, cannot auto-login');
        }
      } else {
        print('❌ No user logged in');
      }
    } catch (e) {
      print('❌ Auto-login check failed: $e');
    }
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
        final responsiveCardWidth = cardWidth.clamp(160.0, 220.0);
        
        // Calculate horizontal offset to maintain spacing
        final horizontalOffset = (responsiveCardWidth + cardSpacing) / 2;
        
        // Scale card height proportionally
        final cardHeight = (responsiveCardWidth * 1.27).clamp(200.0, 280.0);
        
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
                            horizontalOffset: -horizontalOffset,
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
                            horizontalOffset: horizontalOffset,
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
        
        // Calculate responsive values - MUCH TIGHTER spacing
        const minEdgePadding = 24.0; // Same as main cards
        const cardSpacing = 5.0; // Very tight spacing for compact look
        
        // Calculate available width for 3 cards
        final availableWidth = screenWidth - (minEdgePadding * 2);
        
        // Calculate card width (3 cards + 2 gaps)
        final cardWidth = (availableWidth - (cardSpacing * 2)) / 3;
        final responsiveCardWidth = cardWidth.clamp(118.0, 145.0);
        
        // Calculate horizontal offset
        final horizontalOffset = responsiveCardWidth + cardSpacing;
        
        // Scale card height proportionally
        final centerCardHeight = (responsiveCardWidth * 1.62).clamp(180.0, 235.0);
        final sideCardHeight = (responsiveCardWidth * 1.48).clamp(165.0, 215.0);
        
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
                          onTap: () => isSignUp 
                              ? LoginDialogsHelper.showEmailSignUpDialog(
                                  context: context,
                                  floatingController: _floatingController,
                                  floatingAnimation: _floatingAnimation,
                                  authService: authService,
                                  onLoadingChanged: (loading) => setState(() => isLoading = loading),
                                  onNavigateHome: _navigateToHome,
                                  hasMinLength: _hasMinLength,
                                  hasUppercase: _hasUppercase,
                                  hasNumber: _hasNumber,
                                  hasSpecialChar: _hasSpecialChar,
                                  isValidEmail: _isValidEmail,
                                  onValidatePassword: _validatePassword,
                                  onValidateEmail: _validateEmail,
                                  onResetValidation: _resetValidation,
                                )
                              : LoginDialogsHelper.showEmailLoginDialog(
                                  context: context,
                                  floatingController: _floatingController,
                                  floatingAnimation: _floatingAnimation,
                                  authService: authService,
                                  onLoadingChanged: (loading) => setState(() => isLoading = loading),
                                  onNavigateHome: _navigateToHome,
                                  isValidEmail: _isValidEmail,
                                  onValidateEmail: _validateEmail,
                                  onResetValidation: _resetValidation,
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
                        cardHeight: centerCardHeight,
                        gradientColors: const [Color(0xFFE8E8FF), Color(0xFFF0F0FF)],
                        onTap: isLoading 
                            ? null 
                            : () => LoginDialogsHelper.handleGoogleSignIn(
                                context: context,
                                authService: authService,
                                onLoadingChanged: (loading) => setState(() => isLoading = loading),
                                onNavigateHome: _navigateToHome,
                              ),
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
                          onTap: () => LoginDialogsHelper.showPhoneSignInDialog(
                            context: context,
                            floatingController: _floatingController,
                            floatingAnimation: _floatingAnimation,
                            phoneAuthService: phoneAuthService,
                            onNavigateHome: _navigateToHome,
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
              child: BackdropFilter(
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
                  width: cardWidth,
                  height: cardHeight,
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
}