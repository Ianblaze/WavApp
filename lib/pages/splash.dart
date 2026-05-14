import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipify/auth/auth_wrapper.dart';
import 'package:swipify/providers/auth_provider.dart';
import 'package:swipify/pages/home_page.dart';
import 'package:swipify/auth/login_page.dart';
import 'package:swipify/auth/widgets/auth_video_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../intro/intro_flow.dart';
import 'package:video_player/video_player.dart';

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
  
  // Removed manual video player state

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

    // Removed manual video player init
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
    Future.delayed(const Duration(milliseconds: 700), () async {
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final introShown = prefs.getBool('intro_shown') ?? false;
        
        final auth = context.read<AuthProvider>();
        Widget destination;

        if (introShown) {
          if (auth.status == AuthStatus.authenticated) {
            destination = const HomePage();
          } else {
            destination = const AuthWrapper();
          }
        } else {
          destination = const IntroFlow();
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => destination,
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
    return AuthVideoBackground(
      overlayOpacity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
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
                      final minDimension = screenHeight;
                      logoSize = (minDimension * 0.3).clamp(100.0, 150.0);
                      wavFontSize = (minDimension * 0.25).clamp(80.0, 130.0);
                      spacing = (minDimension * 0.01).clamp(2.0, 6.0);
                    } else {
                      // Portrait - Ultra Large Sizing
                      logoSize = (screenWidth * 0.45).clamp(140.0, 200.0);
                      wavFontSize = (screenWidth * 0.4).clamp(120.0, 180.0);
                      spacing = (screenWidth * 0.01).clamp(4.0, 10.0);
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
                                    'assets/images/logo_final.png',
                                    width: logoSize,
                                    height: logoSize,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              );
                            },
                          ),
                          
                          SizedBox(width: spacing),
                          
                          // Animated "wav" image - slides in
                          AnimatedBuilder(
                            animation: _textController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: const Offset(-15, 0), // Pulled in closer to logo
                                child: SlideTransition(
                                  position: _textSlide,
                                  child: FadeTransition(
                                    opacity: _textOpacity,
                                    child: Image.asset(
                                      'assets/images/wav_final.png',
                                      height: wavFontSize * 1.5,
                                      fit: BoxFit.contain,
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
