import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:swipify/auth/login_page.dart';

/// Waveform CustomPainter - Draws the waveform logo with line-by-line reveal
/// The waveform is drawn from left to right using path animation
class WaveformPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 - controls how much is revealed
  final double pulseIntensity; // 0.0 to 1.0 - controls glow/pulse effect
  
  WaveformPainter({
    required this.progress,
    required this.pulseIntensity,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Gradient paint to match the actual logo (cyan to pink)
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Color(0xFF00D4FF), // Cyan
          Color(0xFF9D7FFF), // Purple
          Color(0xFFFF69E8), // Pink
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter
      ..strokeMiterLimit = 4;

    
    // Glow effect paint (subtle pulse)
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Color(0xFF00D4FF).withOpacity(pulseIntensity * 0.6),
          Color(0xFF9D7FFF).withOpacity(pulseIntensity * 0.6),
          Color(0xFFFF69E8).withOpacity(pulseIntensity * 0.6),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + (pulseIntensity * 4));
    
    // Create the ACTUAL waveform path - 9 PEAKS, TIGHT AND COMPRESSED
    final path = Path();
    
    // Your logo: 9 peaks in a compact/tight formation
    // Pattern: small, medium, large, TALLEST, valley, TALLEST, large, medium, small
    final wavePoints = [
  // LEFT FLAT (short)
  const Offset(0.00, 0.50),
  const Offset(0.08, 0.50),

  // small peak
  const Offset(0.11, 0.44),
  const Offset(0.14, 0.56),

  // medium peak
  const Offset(0.18, 0.36),
  const Offset(0.22, 0.64),

  // large peak
  const Offset(0.27, 0.26),
  const Offset(0.31, 0.74),

  // tallest spike (left)
  const Offset(0.36, 0.10),

  // deepest valley (center)
  const Offset(0.40, 0.92),

  // tallest spike (right)
  const Offset(0.44, 0.10),

  // large peak
  const Offset(0.49, 0.74),
  const Offset(0.53, 0.26),

  // medium peak
  const Offset(0.58, 0.64),
  const Offset(0.62, 0.36),

  // small peak
  const Offset(0.66, 0.56),
  const Offset(0.69, 0.44),

  // RIGHT FLAT (short)
  const Offset(0.74, 0.50),
  const Offset(1.00, 0.50),
];

    
    // Scale to actual size
    final scaledPoints = wavePoints.map((p) => Offset(
      p.dx * size.width,
      p.dy * size.height,
    )).toList();
    
    // Build the path
    path.moveTo(scaledPoints[0].dx, scaledPoints[0].dy);
    for (int i = 1; i < scaledPoints.length; i++) {
      path.lineTo(scaledPoints[i].dx, scaledPoints[i].dy);
    }
    
    // Extract the visible portion based on progress (left to right reveal)
    final pathMetrics = path.computeMetrics();
    final pathMetric = pathMetrics.first;
    final extractLength = pathMetric.length * progress;
    final extractedPath = pathMetric.extractPath(0.0, extractLength);
    
    // Draw glow first (if pulsing)
    if (pulseIntensity > 0.0) {
      canvas.drawPath(extractedPath, glowPaint);
    }
    
    // Draw main waveform with gradient
    canvas.drawPath(extractedPath, gradientPaint);
  }
  
  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.pulseIntensity != pulseIntensity;
  }
}

/// Splash Screen with animated waveform and text
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _waveformController;
  late Animation<double> _waveformProgress;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseIntensity;
  
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
    
    // Waveform drawing animation (2.2 seconds)
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );
    
    _waveformProgress = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveformController,
      curve: Curves.easeInOut,
    ));
    
    // Pulse animation (0.4 seconds) - triggers after waveform completes
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _pulseIntensity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Text animation (full word slides in)
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _textSlide = Tween<Offset>(
      begin: const Offset(1.5, 0), // Start off-screen right
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutCubic,
    ));
    
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));
    
    // Animation sequence
    _startAnimationSequence();
  }
  
  void _startAnimationSequence() async {
    // 1. Draw waveform (2.2s)
    await _waveformController.forward();
    
    // 2. Pulse effect (0.4s)
    if (mounted) {
      await _pulseController.forward();
      await _pulseController.reverse();
    }
    
    // 3. Slide in text (starts at 1.8s, runs parallel)
    if (mounted) {
      _textController.forward();
    }
    
    // 4. Navigate after total 3 seconds
    Future.delayed(const Duration(milliseconds: 3000), () {
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
    _waveformController.dispose();
    _pulseController.dispose();
    _textController.dispose();
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.of(context).size.width;
              final screenHeight = MediaQuery.of(context).size.height;
              final isLandscape = screenWidth > screenHeight;
              
              double logoSize;
              double wavFontSize;
              double spacing;
              
              if (isLandscape) {
                logoSize = screenHeight * 0.16;
                wavFontSize = screenHeight * 0.10;
                spacing = screenHeight * 0.008;
              } else {
                if (screenWidth < 360) {
                  logoSize = 70.0;
                  wavFontSize = 42.0;
                  spacing = 4.0;
                } else if (screenWidth < 400) {
                  logoSize = 85.0;
                  wavFontSize = 51.0;
                  spacing = 5.0;
                } else if (screenWidth < 600) {
                  logoSize = 100.0;
                  wavFontSize = 60.0;
                  spacing = 6.0;
                } else {
                  logoSize = 135.0;
                  wavFontSize = 81.0;
                  spacing = 8.0;
                }
              }
              
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated waveform
                  AnimatedBuilder(
                    animation: Listenable.merge([_waveformController, _pulseController]),
                    builder: (context, child) {
                      return SizedBox(
                        width: logoSize,
                        height: logoSize,
                        child: CustomPaint(
                          painter: WaveformPainter(
                            progress: _waveformProgress.value,
                            pulseIntensity: _pulseIntensity.value,
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
              );
            },
          ),
        ),
      ),
    );
  }
}