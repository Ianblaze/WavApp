import 'package:flutter/material.dart';
import 'package:swipify/auth/login_page.dart';

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
    
    // Gradient shift animation
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
          
          // Custom color palette
          const bubblegumPink = Color(0xFFFF69B4);
          const chromeSilver = Color(0xFFC8C8C8);
          const digitalBlue = Color(0xFF007AFF);
          const limeFlashGreen = Color(0xFF32CD32);
          
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
                    color4.withOpacity(0.5),
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
                      color1.withOpacity(0.4),
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
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Get screen dimensions
                final screenWidth = MediaQuery.of(context).size.width;
                final screenHeight = MediaQuery.of(context).size.height;
                final isLandscape = screenWidth > screenHeight;
                
                // Responsive sizing - optimized for mobile screens
                double logoSize;
                double wavFontSize;
                double spacing;
                
                if (isLandscape) {
                  // Landscape mode - scale down
                  logoSize = screenHeight * 0.16; // Reduced from 0.20
                  wavFontSize = screenHeight * 0.10; // Reduced from 0.12
                  spacing = screenHeight * 0.008;
                } else {
                  // Portrait mode - use width for sizing
                  if (screenWidth < 360) {
                    // Small phones
                    logoSize = 70.0; // Reduced from 80
                    wavFontSize = 42.0; // Reduced from 48
                    spacing = 4.0;
                  } else if (screenWidth < 400) {
                    // Medium phones
                    logoSize = 85.0; // Reduced from 100
                    wavFontSize = 51.0; // Reduced from 60
                    spacing = 5.0;
                  } else if (screenWidth < 600) {
                    // Large phones
                    logoSize = 100.0; // Reduced from 120
                    wavFontSize = 60.0; // Reduced from 72
                    spacing = 6.0;
                  } else {
                    // Tablets
                    logoSize = 135.0; // Reduced from 160
                    wavFontSize = 81.0; // Reduced from 96
                    spacing = 8.0;
                  }
                }
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Image.asset(
                      'assets/images/filogo.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: spacing),
                    // Wav text with gradient - shifted left
                    Transform.translate(
                      offset: const Offset(-4, 0), // Push text left
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
                  ]
                );
              },
          ),
        ),
      ),
    ));
  }
}