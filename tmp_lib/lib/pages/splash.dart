import 'package:flutter/material.dart';
import 'package:swipify/auth/login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _revealController;
  late Animation<double> _revealProgress;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;
  
  late AnimationController _textController;
  late Animation<Offset> _textSlide;
  late Animation<double> _textOpacity;
  
  late AnimationController _gradientShiftController;
  late Animation<double> _gradientShift;

  @override
  void initState() {
    super.initState();
    
    // Gradient shift animation (background)
    _gradientShiftController = AnimationController(
      duration: const Duration(milliseconds: 25000),
      vsync: this,
    )..repeat();
    
    _gradientShift = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _gradientShiftController,
      curve: Curves.easeInOutSine,
    ));
    
    // Logo reveal animation (2.8 seconds) - slower reveal
    _revealController = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    );
    
    _revealProgress = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeInOut,
    ));
    
    // Pulse animation (0.4 seconds) - subtle scale + glow
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _pulseScale = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _pulseOpacity = Tween<double>(
      begin: 0.0,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Text animation (smoother, more polished slide)
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _textSlide = Tween<Offset>(
      begin: const Offset(0.8, 0), // Start closer (less distance to travel)
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutQuint, // Smoother, more elegant curve
    ));
    
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut), // Fades in faster
    ));
    
    // Start animation sequence
    _startAnimationSequence();
  }
  
  void _startAnimationSequence() async {
    // Start text animation at 1800ms (so it slides smoothly as logo finishes)
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _textController.forward();
      }
    });
    
    // 1. Reveal logo from left to right (2.8s)
    await _revealController.forward();
    
    // 2. Navigate after 3.5 seconds total
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
            transitionDuration: const Duration(milliseconds: 1000),
            reverseTransitionDuration: const Duration(milliseconds: 1000),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              var fadeAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutQuart,
              );
              
              var scaleAnimation = Tween<double>(
                begin: 0.92,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutQuart,
              ));
              
              return FadeTransition(
                opacity: fadeAnimation,
                child: ScaleTransition(
                  scale: scaleAnimation,
                  child: child,
                ),
              );
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _revealController.dispose();
    _pulseController.dispose();
    _textController.dispose();
    _gradientShiftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _gradientShiftController,
          builder: (context, child) {
            final shift = _gradientShift.value;
            
            // Y2K gradient colors
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
              bubblegumPink.withOpacity(0.65),
              digitalBlue.withOpacity(0.65),
              chromeSilver.withOpacity(0.75),
              limeFlashGreen.withOpacity(0.65),
            );
            
            final color2 = getColorForStage(
              digitalBlue.withOpacity(0.65),
              chromeSilver.withOpacity(0.75),
              limeFlashGreen.withOpacity(0.65),
              bubblegumPink.withOpacity(0.65),
            );
            
            final color3 = getColorForStage(
              chromeSilver.withOpacity(0.75),
              limeFlashGreen.withOpacity(0.65),
              bubblegumPink.withOpacity(0.65),
              digitalBlue.withOpacity(0.65),
            );
            
            final color4 = getColorForStage(
              limeFlashGreen.withOpacity(0.65),
              bubblegumPink.withOpacity(0.65),
              digitalBlue.withOpacity(0.65),
              chromeSilver.withOpacity(0.75),
            );
            
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color1, color2, color3],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.5,
                    colors: [color4.withOpacity(0.5), Colors.transparent],
                    stops: const [0.0, 0.7],
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.bottomLeft,
                      radius: 1.8,
                      colors: [color1.withOpacity(0.4), Colors.transparent],
                      stops: const [0.0, 0.8],
                    ),
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: Center(
            child: OrientationBuilder(
              builder: (context, orientation) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = constraints.maxWidth;
                    final screenHeight = constraints.maxHeight;
                    final isLandscape = orientation == Orientation.landscape;
                    
                    // Responsive sizing with better landscape handling
                    double logoSize;
                    double wavFontSize;
                    double spacing;
                    
                    if (isLandscape) {
                      // Landscape mode - scale based on height (limited vertical space)
                      final minDimension = screenHeight;
                      logoSize = (minDimension * 0.20).clamp(50.0, 100.0);
                      wavFontSize = (minDimension * 0.12).clamp(30.0, 60.0);
                      spacing = (minDimension * 0.015).clamp(6.0, 12.0);
                    } else {
                      // Portrait mode - scale based on width
                      if (screenWidth < 320) {
                        // Very small phones
                        logoSize = 60.0;
                        wavFontSize = 30.0;
                        spacing = 4.0;
                      } else if (screenWidth < 360) {
                        // Small phones
                        logoSize = 70.0;
                        wavFontSize = 35.0;
                        spacing = 5.0;
                      } else if (screenWidth < 400) {
                        // Medium phones
                        logoSize = 85.0;
                        wavFontSize = 42.0;
                        spacing = 6.0;
                      } else if (screenWidth < 450) {
                        // Large phones
                        logoSize = 100.0;
                        wavFontSize = 50.0;
                        spacing = 8.0;
                      } else if (screenWidth < 600) {
                        // Phablets
                        logoSize = 115.0;
                        wavFontSize = 58.0;
                        spacing = 10.0;
                      } else if (screenWidth < 800) {
                        // Small tablets
                        logoSize = 135.0;
                        wavFontSize = 67.0;
                        spacing = 12.0;
                      } else {
                        // Large tablets
                        logoSize = 160.0;
                        wavFontSize = 80.0;
                        spacing = 15.0;
                      }
                    }
                    
                    // Ensure content fits within available space
                    final totalWidth = logoSize + spacing + (wavFontSize * 2.5);
                    final availableWidth = screenWidth * 0.9; // 90% of screen width
                    
                    if (totalWidth > availableWidth) {
                      final scaleFactor = availableWidth / totalWidth;
                      logoSize *= scaleFactor;
                      wavFontSize *= scaleFactor;
                      spacing *= scaleFactor;
                    }
                    
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLandscape ? 40.0 : 20.0,
                        vertical: isLandscape ? 20.0 : 40.0,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown, // Scales down if content too large
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Animated logo - reveals from left to right
                            AnimatedBuilder(
                              animation: _revealController,
                              builder: (context, child) {
                                return ClipRect(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: _revealProgress.value, // Reveals left to right
                                    child: Image.asset(
                                      'assets/images/filogo.png',
                                      width: logoSize,
                                      height: logoSize,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            SizedBox(width: spacing),
                            
                            // Animated "Wav" text - full word slides in
                            AnimatedBuilder(
                              animation: _textController,
                              builder: (context, child) {
                                return SlideTransition(
                                  position: _textSlide,
                                  child: FadeTransition(
                                    opacity: _textOpacity,
                                    child: Transform.translate(
                                      offset: const Offset(-4, 0),
                                      child: ShaderMask(
                                        shaderCallback: (bounds) => const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFFFFB3E6), // soft pink
                                            Color(0xFFB3D9FF), // soft blue
                                            Color(0xFFD9B3FF), // soft purple
                                          ],
                                        ).createShader(bounds),
                                        child: Text(
                                          'Wav',
                                          style: TextStyle(
                                            fontFamily: 'Circular',
                                            fontSize: wavFontSize,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: -2,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}