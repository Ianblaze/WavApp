import 'package:flutter/material.dart';
import 'package:swipify/auth/login_page.dart';

// ---------------------------------------------------------
// 🎨 LIGHT Y2K BUBBLEGUM POP PALETTE (from home_page.dart)
// ---------------------------------------------------------
const bgTop = Color(0xFFFFE6FF);        // pearl pink
const bgMid = Color(0xFFF3E5FF);        // lilac pink
const bgBottom = Color(0xFFE1E9FF);     // cotton blue

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  late AnimationController _gradientShiftController;
  late Animation<double> _gradientShift;

  @override
  void initState() {
    super.initState();
    
    // Fade in animation for logo
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    // Gradient shift animation - same as login
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
    
    _fadeController.forward();
    
    // Navigate to login after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
            transitionDuration: const Duration(milliseconds: 1000), // Longer, smoother
            reverseTransitionDuration: const Duration(milliseconds: 1000),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // Professional cross-fade with subtle scale
              var fadeAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutQuart, // Smoother curve
              );
              
              var scaleAnimation = Tween<double>(
                begin: 0.92, // More subtle
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutQuart, // Smooth deceleration
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
    _fadeController.dispose();
    _gradientShiftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _gradientShiftController,
        builder: (context, child) {
          final shift = _gradientShift.value;
          
          // Custom color palette - exact same as login
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
          
          // Apply higher opacity for more vibrant, saturated colors (matching login)
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
                    color4.withOpacity(0.5), // More visible
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
                      color1.withOpacity(0.4), // More visible
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.8],
                  ),
                ),
                child: child,
              ),
            ),
          );
        },
        child: Stack(
          children: [
            // Center - Logo and Wav side by side (close like Tinder)
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: AnimatedBuilder(
                  animation: _gradientShiftController,
                  builder: (context, child) {
                    final shift = _gradientShift.value;
                    
                    // Same color calculation as background
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
                    
                    final textColor1 = getColorForStage(
                      bubblegumPink.withOpacity(0.65),
                      digitalBlue.withOpacity(0.65),
                      chromeSilver.withOpacity(0.75),
                      limeFlashGreen.withOpacity(0.65),
                    );
                    
                    final textColor2 = getColorForStage(
                      digitalBlue.withOpacity(0.65),
                      chromeSilver.withOpacity(0.75),
                      limeFlashGreen.withOpacity(0.65),
                      bubblegumPink.withOpacity(0.65),
                    );
                    
                    final textColor3 = getColorForStage(
                      chromeSilver.withOpacity(0.75),
                      limeFlashGreen.withOpacity(0.65),
                      bubblegumPink.withOpacity(0.65),
                      digitalBlue.withOpacity(0.65),
                    );
                    
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo + Wav + Caption stack
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo on the left
                            Image.asset(
                              'assets/images/filogo.png',
                              width: 180,
                              height: 180,
                              fit: BoxFit.contain,
                            ),
                            // Wav text + caption stacked on the right
                            Transform.translate(
                              offset: const Offset(-25, 0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Wav text - soft pastel gradient
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
                                    child: const Text(
                                      'Wav',
                                      style: TextStyle(
                                        fontFamily: 'Circular',
                                        fontSize: 72,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Unlimited potential at your fingertips',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Circular',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFE6CCFF), // light pastel purple
                                      letterSpacing: 2,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
    );
  }
}