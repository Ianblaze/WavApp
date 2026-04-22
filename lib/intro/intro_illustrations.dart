import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart';

// ── Illustration 1: Floating match cards ──────────────────────────────────────
/// Shows three stacked profile cards (left tilted, right tilted, centre front)
/// with a waveform beneath. Teases the card-swipe mechanic.
class MatchCardsIllustration extends StatefulWidget {
  final double parallaxOffset;
  const MatchCardsIllustration({super.key, this.parallaxOffset = 0.0});

  @override
  State<MatchCardsIllustration> createState() => _MatchCardsIllustrationState();
}

class _MatchCardsIllustrationState extends State<MatchCardsIllustration>
    with TickerProviderStateMixin {
  late AnimationController _bobCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _swipeCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _emojiCtrl;
  late AnimationController _shimmerCtrl;

  int _phase = 0;
  bool _isSwiping = false;

  static const _springCurve = Cubic(0.34, 1.26, 0.64, 1.0);

  @override
  void initState() {
    super.initState();
    _bobCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _swipeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _rotateCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _emojiCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat();

    _startLoop();
  }

  void _startLoop() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 2200));
      if (!mounted) break;

      _phase = 0;
      setState(() => _isSwiping = true);
      _emojiCtrl.forward(from: 0.0);
      await _swipeCtrl.forward(from: 0.0);
      if (!mounted) break;
      setState(() => _isSwiping = false);
      await _rotateCtrl.forward(from: 0.0);
      if (!mounted) break;
      _swipeCtrl.reset();
      _rotateCtrl.reset();
      _emojiCtrl.reset();

      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) break;

      _phase = 1;
      setState(() => _isSwiping = true);
      _emojiCtrl.forward(from: 0.0);
      await _swipeCtrl.forward(from: 0.0);
      if (!mounted) break;
      setState(() => _isSwiping = false);
      await _rotateCtrl.forward(from: 0.0);
      if (!mounted) break;
      _swipeCtrl.reset();
      _rotateCtrl.reset();
      _emojiCtrl.reset();
    }
  }

  @override
  void dispose() {
    _bobCtrl.dispose();
    _pulseCtrl.dispose();
    _swipeCtrl.dispose();
    _rotateCtrl.dispose();
    _emojiCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final spacing = w * 0.24;

        return SizedBox(
          width: w,
          height: h,
          child: Transform.translate(
            offset: Offset(widget.parallaxOffset * 80, 0), // Subtle parallax
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: w,
                  height: h * 0.63,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // ── #2: Enhanced Ambient glow (Multi-layered) ──
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (ctx, _) {
                          final pulse = _pulseCtrl.value;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Deep base glow
                              Transform.scale(
                                scale: 1.0 + pulse * 0.15,
                                child: Container(
                                  width: 280,
                                  height: 280,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(0xFFD9B3FF).withOpacity(0.12),
                                        const Color(0xFFD9B3FF).withOpacity(0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Vibrant center core
                              Transform.scale(
                                scale: 1.0 + pulse * 0.1,
                                child: Container(
                                  width: 180,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(0xFFFF99CC).withOpacity(0.22),
                                        const Color(0xFFFF99CC).withOpacity(0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      // ── #5: Music note particles ──
                      _MusicNoteParticles(controller: _bobCtrl),

                      // ── 3-Card Stack with Parallax & Float ──
                      AnimatedBuilder(
                        animation: Listenable.merge([_bobCtrl, _rotateCtrl, _swipeCtrl]),
                        builder: (ctx, _) {
                          final floatX = sin(_bobCtrl.value * pi * 2) * 8; // Gentle horizontal float
                          
                          return Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // ── Left Card (#3: Blurred & Faded) ──
                              _buildSideCard(-1, spacing, bobPhase: 0.0, bobSpeed: 1.0, floatX: floatX),
                              // ── Right Card (#3: Blurred & Faded) ──
                              _buildSideCard(1, spacing, bobPhase: 0.5, bobSpeed: 0.7, floatX: floatX),

                              // ── Front card with prominence & shimmer ──
                              AnimatedBuilder(
                                animation: Listenable.merge([_bobCtrl, _swipeCtrl, _shimmerCtrl]),
                                builder: (ctx, child) {
                                  final bobY = sin((_bobCtrl.value + 0.8) % 1.0 * pi * 2) * 12; // Increased bobbing intensity
                                  final t = Curves.easeInCubic.transform(_swipeCtrl.value);
                                  final swipeY = (_phase == 0) ? t * 320 : t * -320;
                                  final swipeAngle = _swipeCtrl.value * (_phase == 0 ? 0.28 : -0.28);
                                  final swipeOp = (1.0 - _swipeCtrl.value * 1.6).clamp(0.0, 1.0);

                                  return Transform.translate(
                                    offset: Offset(floatX, bobY + swipeY),
                                    child: Transform.rotate(
                                      angle: swipeAngle,
                                      child: Transform.scale(
                                        scale: 1.05, // Prominent scale
                                        child: Opacity(
                                          opacity: swipeOp,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(24),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFFF99CC).withOpacity(0.25),
                                                  blurRadius: 30,
                                                  offset: const Offset(0, 10),
                                                ),
                                              ],
                                            ),
                                            child: child,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    _GlassProfileCard(
                                      gradient: const [Color(0xFFFFB3D9), Color(0xFFFF99CC)],
                                      width: 154,
                                      height: 194,
                                    ),
                                    // Shimmer
                                    Positioned.fill(
                                      child: AnimatedBuilder(
                                        animation: _shimmerCtrl,
                                        builder: (ctx, _) {
                                          return ClipRRect(
                                            borderRadius: BorderRadius.circular(24),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Colors.white.withOpacity(0.0),
                                                    Colors.white.withOpacity(0.15),
                                                    Colors.white.withOpacity(0.0),
                                                  ],
                                                  stops: const [0.3, 0.5, 0.7],
                                                  transform: _SlideGradientTransform((_shimmerCtrl.value * 2 - 0.5)),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                      ),

                      // ── Emoji Feedback ──
                      AnimatedBuilder(
                        animation: _emojiCtrl,
                        builder: (ctx, _) {
                          final t = _emojiCtrl.value;
                          final scale = Curves.elasticOut.transform(t);
                          final opacity = (1.0 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);
                          return Transform.translate(
                            offset: Offset(0, -50 * t),
                            child: Opacity(
                              opacity: opacity,
                              child: Transform.scale(
                                scale: scale,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _phase == 0 ? const Color(0xFFFF6FE8) : const Color(0xFF8A7EA5),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 4),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 20,
                                          offset: const Offset(0, 6))
                                    ],
                                  ),
                                  child: Icon(
                                    _phase == 0
                                        ? Icons.favorite_rounded
                                        : Icons.close_rounded,
                                    color: Colors.white,
                                    size: 32,
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

                // #6: Waveform (Clean visualizer, no touch)
                const SizedBox(height: 42), // Lowered even more
                _ReactiveWaveform(swipeCtrl: _swipeCtrl),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Side cards with parallax bob + right card turns pink during rotation
  Widget _buildSideCard(int i, double spacing, {required double bobPhase, required double bobSpeed, required double floatX}) {
    const leftGrad = [Color(0xFFD9B3FF), Color(0xFFB3D9FF)];
    const rightGrad = [Color(0xFFB3D9FF), Color(0xFFD9B3FF)];
    const pinkGrad = [Color(0xFFFFB3D9), Color(0xFFFF99CC)];

    return AnimatedBuilder(
      animation: Listenable.merge([_rotateCtrl, _bobCtrl]),
      builder: (ctx, _) {
        final double raw = _isSwiping ? 0.0 : _rotateCtrl.value;
        final double progress = _springCurve.transform(raw);

        final double effective = i.toDouble() - progress;
        // Seamless scale transition: lerp from side scale (0.85) to front scale (1.05)
        final s = (1.05 - (effective.abs() * 0.2)).clamp(0.6, 1.1); 
        final hOffset = effective * spacing + floatX;
        final r = effective * 0.12;
        // Adjusted opacity to stay visible as per ref
        final op = (0.7 - (effective.abs() * 0.2)).clamp(0.4, 0.9);
        // Added +14 vertical offset to make side cards sit a little lower
        final bobY = (sin((_bobCtrl.value * bobSpeed + bobPhase) % 1.0 * pi * 2) * 4) + 14; 

        // Reduced blur from 7.0 to 2.5 as requested
        final blurSigma = (effective.abs() * 2.5).clamp(0.0, 2.5);

        // Right card (i=1) transitions to pink as it moves to center
        List<Color> grad;
        if (i == 1) {
          grad = [
            Color.lerp(rightGrad[0], pinkGrad[0], progress) ?? rightGrad[0],
            Color.lerp(rightGrad[1], pinkGrad[1], progress) ?? rightGrad[1],
          ];
        } else {
          grad = leftGrad;
        }

        return Transform.translate(
          offset: Offset(hOffset, bobY),
          child: Transform.rotate(
            angle: r,
            child: Transform.scale(
              scale: s,
              child: _ProfileCard(
                gradient: grad,
                opacity: op,
                width: 145,
                height: 185,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── #7: Shimmer gradient transform ──
class _SlideGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlideGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

// ── #1: Glassmorphism Profile Card ──
class _GlassProfileCard extends StatelessWidget {
  final List<Color> gradient;
  final double width;
  final double height;

  const _GlassProfileCard({
    required this.gradient,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(22),
        // Glassmorphism: frosted white border
        border: Border.all(
          color: Colors.white.withOpacity(0.55),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          // Surface gloss highlight
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: const Alignment(0.2, 0.2),
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: Container(
                  width: width * 0.38,
                  height: width * 0.38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.35),
                    border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: width * 0.55,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 7),
              Container(
                width: width * 0.35,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── #5: Music Note Particles ──
class _MusicNoteParticles extends StatelessWidget {
  final AnimationController controller;
  const _MusicNoteParticles({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (ctx, _) {
        return Stack(
          children: List.generate(10, (i) {
            final rng = Random(i * 13 + 7);
            final baseX = rng.nextDouble() * 240 - 120;
            final speed = 0.3 + rng.nextDouble() * 0.7;
            final phase = rng.nextDouble();
            final t = (controller.value * speed + phase) % 1.0;
            
            // Curved path
            final y = 100 - (t * 220);
            final x = baseX + sin(t * pi * 3) * 20;
            
            // Fading out at top and bottom
            final fade = sin(t * pi);
            final opacity = (fade * 0.5).clamp(0.0, 0.5);
            
            final noteChar = (i % 3 == 0) ? '♪' : (i % 3 == 1 ? '♫' : '♬');

            return Transform.translate(
              offset: Offset(x, y),
              child: Text(
                noteChar,
                style: TextStyle(
                  fontSize: 12 + rng.nextDouble() * 10,
                  fontWeight: FontWeight.bold,
                  color: [
                    const Color(0xFFFF99CC),
                    const Color(0xFFB69CFF),
                    const Color(0xFF7BA7FF),
                    Colors.white,
                  ][i % 4].withOpacity((0.8 * opacity).clamp(0.0, 1.0)),
                  shadows: [
                    Shadow(
                      color: Colors.white.withOpacity((0.3 * opacity).clamp(0.0, 1.0)),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Touch-Interactive Waveform ──
class _ReactiveWaveform extends StatefulWidget {
  final AnimationController swipeCtrl;
  const _ReactiveWaveform({required this.swipeCtrl});

  @override
  _ReactiveWaveformState createState() => _ReactiveWaveformState();
}

class _ReactiveWaveformState extends State<_ReactiveWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _idleCtrl;

  final int _barCount = 28;
  final List<double> _baseHeights = List.generate(28, (_) => 14.0 + Random().nextDouble() * 26.0);

  @override
  void initState() {
    super.initState();
    _idleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _idleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _idleCtrl,
      builder: (ctx, _) {
        return SizedBox(
          height: 60,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_barCount, (i) {
              final h = _getDancingHeight(i);
              
              // Intentional 'music spectrum' color mix
              final centerDist = (i - (_barCount / 2)).abs() / (_barCount / 2);
              final color = Color.lerp(
                const Color(0xFFFF7DB8), // Bright Pink center
                i % 2 == 0 ? const Color(0xFFB69CFF) : const Color(0xFF7BA7FF), // Lavender/Blue edges
                centerDist.clamp(0.0, 1.0),
              )!;
              
              return Container(
                width: 6,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 2.2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withOpacity(0.9),
                      color.withOpacity(0.35),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  double _getDancingHeight(int i) {
    final t = _idleCtrl.value * pi * 2;
    final variation = sin(t + (i * 0.45)) * 14.0;
    return (_baseHeights[i] + variation).clamp(10.0, 55.0);
  }
}

class _ProfileCard extends StatelessWidget {
  final List<Color> gradient;
  final double opacity;
  final double width;
  final double height;

  const _ProfileCard({
    required this.gradient,
    required this.opacity,
    this.width = 88,
    this.height = 108,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColors = gradient.map((c) => c.withOpacity((c.opacity * opacity).clamp(0.0, 1.0))).toList();
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: effectiveColors,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity((0.4 * opacity).clamp(0.0, 1.0)), width: 1),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity((0.2 * opacity).clamp(0.0, 1.0)),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: width * 0.4,
            height: width * 0.4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity((0.35 * opacity).clamp(0.0, 1.0)),
              border:
                  Border.all(color: Colors.white.withOpacity((0.5 * opacity).clamp(0.0, 1.0)), width: 1),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: width * 0.6,
            height: 3.5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity((0.4 * opacity).clamp(0.0, 1.0)),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: width * 0.4,
            height: 3.5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity((0.2 * opacity).clamp(0.0, 1.0)),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slide 2 illustration: solar system taste match ────────────────────────────

class SolarSystemIllustration extends StatefulWidget {
  final double parallaxOffset;
  const SolarSystemIllustration({super.key, this.parallaxOffset = 0.0});

  @override
  State<SolarSystemIllustration> createState() =>
      _SolarSystemIllustrationState();
}

class _SolarSystemIllustrationState extends State<SolarSystemIllustration>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _elapsed = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      _elapsed.value = d.inMicroseconds / 1e6;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      return Transform.translate(
        offset: Offset(widget.parallaxOffset * 100, 0),
        child: CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _SolarPainter(_elapsed),
        ),
      );
    });
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _Star {
  final Offset pos;
  final double size;
  final double phase;
  final double speed;
  const _Star(this.pos, this.size, this.phase, this.speed);
}

class _SolarPainter extends CustomPainter {
  final ValueNotifier<double> tNotifier;
  double get t => tNotifier.value;

  // Layout constants
  static const double _A    = 150;
  static const double _SY   = 0.72;
  static const double _SR   = 22;    // sun radius
  static const double _R1   = 48;    // inner solo orbit
  static const double _R2   = 76;    // outer solo orbit
  static const int    _N    = 1200;  // infinity path resolution

  static List<Offset>? _cachedPath;
  static List<_Star>? _cachedStars;

  _SolarPainter(this.tNotifier) : super(repaint: tNotifier);

  static List<Offset> _buildPath() {
    if (_cachedPath != null) return _cachedPath!;
    final pts = <Offset>[];
    for (int i = 0; i < _N; i++) {
      final u = (i / _N) * 2 * pi;
      pts.add(Offset(_A * cos(u), _A * sin(u) * cos(u) * _SY));
    }
    return _cachedPath = pts;
  }

  Offset _samplePath(double frac, Offset centre) {
    final path = _buildPath();
    final norm = ((frac % 1) + 1) % 1;
    final raw  = norm * _N;
    final i0   = raw.floor() % _N;
    final i1   = (i0 + 1)    % _N;
    final f    = raw - raw.floor();
    final p    = path[i0] * (1 - f) + path[i1] * f;
    return centre + p;
  }

  static const _soloYou = [
    _Genre('indie', Color(0xFFFFB3D9), Color(0xFF4B1528), _R1,  0.50,  0.0),
    _Genre('pop',   Color(0xFFFFE5B3), Color(0xFF412402), _R2, -0.34,  1.88),
  ];
  static const _soloThem = [
    _Genre('soul',    Color(0xFFB3FFD9), Color(0xFF04342C), _R1,  0.42,  3.14),
    _Genre('hip-hop', Color(0xFFB3D9FF), Color(0xFF042C53), _R2, -0.48, -2.51),
  ];
  static const _shared = [
    _Genre('r&b',  Color(0xFFD9B3FF), Color(0xFF26215C), 0, 0.10, 0.0),
    _Genre('k-pop',Color(0xFFFFBEE1), Color(0xFF4B1528), 0, 0.10, 0.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (_cachedStars == null) {
      final rng = Random(42);
      final ss = <_Star>[];
      for (int i = 0; i < 20; i++) {
        ss.add(_Star(
          Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
          0.8 + rng.nextDouble() * 1.5,
          rng.nextDouble() * pi * 2,
          0.5 + rng.nextDouble(),
        ));
      }
      _cachedStars = ss;
    }

    // 3. Stardust Parallax
    for (final s in _cachedStars!) {
      final op = (sin(t * s.speed + s.phase) + 1) / 2;
      canvas.drawCircle(s.pos, s.size, Paint()..color = Colors.white.withOpacity(op * 0.4));
    }

    final cx = size.width / 2;
    final cy = size.height / 2;
    final centre = Offset(cx, cy);
    final lx = cx - _A * 0.62;
    final rx = cx + _A * 0.62;
    final lSun = Offset(lx, cy);
    final rSun = Offset(rx, cy);

    void processSoloOrbits(List<_Genre> genres, Offset sunOffset) {
      // Sort so ones behind (sin < 0) are drawn first, ones in front drawn last
      final List<Map<String, dynamic>> sorted = [];
      for (final g in genres) {
        final a = t * g.speed + g.phase;
        
        // Dust/trail orbit line (shorter for solo genres)
        Offset prevP = sunOffset + Offset(cos(a) * g.r, sin(a) * g.r);
        for (int i = 1; i <= 8; i++) {
          final angleOffset = (i * 0.05) * g.speed.sign; 
          final pastA = a - angleOffset;
          final pastP = sunOffset + Offset(cos(pastA) * g.r, sin(pastA) * g.r);
          final trailOp = (1 - (i / 8)) * 0.95; 
          final trailScale = 1.0 + sin(pastA) * 0.15;
          final trailOpFade = 0.65 + (sin(pastA) * 0.35);
          
          canvas.drawLine(
            prevP, 
            pastP, 
            Paint()
              ..color = g.bg.withOpacity((trailOp * trailOpFade).clamp(0.0, 1.0))
              ..strokeWidth = 3.0 * trailScale
              ..strokeCap = StrokeCap.round
          );
          prevP = pastP;
        }

        sorted.add({'genre': g, 'angle': a});
      }
      sorted.sort((a, b) => sin(a['angle']).compareTo(sin(b['angle'])));

      for (final item in sorted) {
        final g = item['genre'] as _Genre;
        final a = item['angle'] as double;
        final pos = sunOffset + Offset(cos(a) * g.r, sin(a) * g.r);
        
        // 1. Z-axis Scaling
        final zScale = 1.0 + sin(a) * 0.15;
        final zOpacity = 0.65 + (sin(a) * 0.35);

        _drawChip(canvas, pos, g.label, g.bg, g.tc, 0.90 * zOpacity, zScale);
      }
    }

    processSoloOrbits(_soloYou, lSun);
    processSoloOrbits(_soloThem, rSun);

    // Shared — infinity path
    final List<Map<String, dynamic>> sharedSorted = [];

    for (final g in _shared) {
      final a = t * g.speed + g.phase;
      
      // Extended dust/trail to emphasize the infinity shape without being stubbornly permanent
      Offset prevP = _samplePath(a, centre);
      for (int i = 1; i <= 36; i++) {
        final fracOffset = (i * 0.01) * g.speed.sign;
        final pastA = a - fracOffset;
        final pastP = _samplePath(pastA, centre);
        final trailOp = (1 - (i / 36)) * 0.85;
        
        canvas.drawLine(
          prevP, 
          pastP, 
          Paint()
            ..color = g.bg.withOpacity(trailOp)
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round
        );
        prevP = pastP;
      }

      sharedSorted.add({'genre': g, 'angle': a});
    }

    for (final item in sharedSorted) {
      final g = item['genre'] as _Genre;
      final a = item['angle'] as double;
      final p = _samplePath(a, centre);
      final dL = (p - lSun).distance;
      final dR = (p - rSun).distance;
      final dC = (p - centre).distance;
      
      final proxSun = (1 - ((min(dL, dR) - 30) / 60)).clamp(0.0, 1.0);
      
      // Z-axis roughly by mapped Y pos
      final mappedY = (p.dy - cy) / (_A * 0.5 * _SY);
      final zScale = 1.0 + mappedY * 0.15;
      final zOpacity = 0.70 + mappedY * 0.30;

      // Glow ring near suns
      if (proxSun > 0.05) {
        canvas.drawCircle(
          p,
          18 * zScale,
          Paint()
            ..color = g.bg.withOpacity(proxSun * 0.22)
            ..style = PaintingStyle.fill,
        );
      }

      // 4. Central Sparkle Node
      if (dC < 40) {
        final crossProx = (1 - (dC / 40)).clamp(0.0, 1.0);
        final fp = Path();
        final fs = 6.0 + 8.0 * crossProx;
        fp.moveTo(centre.dx, centre.dy - fs);
        fp.quadraticBezierTo(centre.dx, centre.dy, centre.dx + fs, centre.dy);
        fp.quadraticBezierTo(centre.dx, centre.dy, centre.dx, centre.dy + fs);
        fp.quadraticBezierTo(centre.dx, centre.dy, centre.dx - fs, centre.dy);
        fp.close();
        canvas.drawPath(fp, Paint()..color = Colors.white.withOpacity(crossProx * 0.8));
      }

      _drawChip(canvas, p, g.label, g.bg, g.tc,
          (0.82 + proxSun * 0.18) * zOpacity, zScale);
    }

    // Suns on top
    _drawSun(canvas, lSun, 'you');
    _drawSun(canvas, rSun, 'them');
  }

  void _drawChip(Canvas canvas, Offset pos, String label,
      Color bg, Color tc, double alpha, double scale) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(scale, scale);

    final w = label.length * 6.2 + 16;
    const h = 18.0;
    const r = 9.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(r)),
      Paint()..color = bg.withOpacity(alpha.clamp(0.0, 1.0)),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Circular',
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: tc.withOpacity(alpha.clamp(0.0, 1.0)),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

    canvas.restore();
  }

  void _drawSun(Canvas canvas, Offset pos, String label) {
    // 2. Dynamic pulsating glow
    final pulseMod = sin(t * pi);
    final glowRadius = 34.0 + pulseMod * 4.0;
    
    // Ambient backglow
    final baseGlow = const Color(0xFFD9B3FF);
    canvas.drawCircle(
      pos, glowRadius,
      Paint()
        ..shader = RadialGradient(colors: [
          baseGlow.withOpacity((0.40 + pulseMod * 0.1).clamp(0.0, 1.0)),
          baseGlow.withOpacity(0.0),
        ]).createShader(Rect.fromCircle(center: pos, radius: glowRadius)),
    );

    canvas.drawCircle(
      pos, _SR,
      Paint()
        ..shader = LinearGradient(
          colors: const [Color(0xFFFFB3D9), Color(0xFFD9B3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: pos, radius: _SR)),
    );

    canvas.drawCircle(pos, _SR,
        Paint()
          ..color = Colors.white.withOpacity(0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    final bars = [4.0, 8.0, 5.0, 10.0, 6.0];
    for (int i = 0; i < bars.length; i++) {
      final bx = pos.dx - 9 + i * 4.5;
      final bh = bars[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, pos.dy - bh / 2, 3, bh),
          const Radius.circular(1.5),
        ),
        Paint()..color = Colors.white.withOpacity(0.9),
      );
    }

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontFamily: 'Circular',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0x6B1A0D26),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(pos.dx - tp.width / 2, pos.dy - _SR - tp.height - 6));
  }

  @override
  bool shouldRepaint(_SolarPainter old) => false;
}

// ── Genre data class ──────────────────────────────────────────────────────────
class _Genre {
  final String label;
  final Color bg;
  final Color tc;
  final double r;
  final double speed;
  final double phase;
  const _Genre(this.label, this.bg, this.tc, this.r, this.speed, this.phase);
}

// ── Illustration 3: Music conversation ───────────────────────────────────────
class MusicConversationIllustration extends StatefulWidget {
  final double parallaxOffset;
  const MusicConversationIllustration({super.key, this.parallaxOffset = 0.0});

  @override
  State<MusicConversationIllustration> createState() =>
      _MusicConversationIllustrationState();
}

class _MusicConversationIllustrationState
    extends State<MusicConversationIllustration>
    with TickerProviderStateMixin {
  late AnimationController _eqCtrl;

  // Animation controllers
  late AnimationController _msg1Ctrl;
  late AnimationController _msg2Ctrl;
  late AnimationController _msg3Ctrl;
  late AnimationController _orbCtrl; // For background orbs

  @override
  void initState() {
    super.initState();
    _eqCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _msg1Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _msg2Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _msg3Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _runMessageLoop();
  }

  Future<void> _runMessageLoop() async {
    while (mounted) {
      // Reset all
      _msg1Ctrl.reset();
      _msg2Ctrl.reset();
      _msg3Ctrl.reset();
      setState(() {});

      // Wait, then pop message 1
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) break;
      await _msg1Ctrl.forward();
      if (!mounted) break;

      // Pause, then message 2
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) break;
      await _msg2Ctrl.forward();
      if (!mounted) break;

      // Pause, then your reply
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) break;
      await _msg3Ctrl.forward();
      if (!mounted) break;

      // Hold the full conversation, then loop
      await Future.delayed(const Duration(milliseconds: 3000));
    }
  }

  @override
  void dispose() {
    _eqCtrl.dispose();
    _msg1Ctrl.dispose();
    _msg2Ctrl.dispose();
    _msg3Ctrl.dispose();
    _orbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: Offset(widget.parallaxOffset * 120, 0),
        child: SizedBox(
          width: 280,
          height: 350,
          child: Stack(
            children: [
              // ── Background Orbs ──
              _BackgroundOrbs(orbCtrl: _orbCtrl),

              // ── Main Content ──
              Column(
                children: [
                  // ── Now Playing bar (top) ──
                  _NowPlayingCard(eqCtrl: _eqCtrl),
                  const SizedBox(height: 4),

                  // ── Chat screen ──
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      clipBehavior: Clip.hardEdge,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Chat header: "you" and "them" ──
                          Row(
                            children: [
                              _ChatAvatar(
                                label: 'them',
                                gradient: const [Color(0xFFB3D9FF), Color(0xFF7BA7FF)],
                              ),
                              const Spacer(),
                              _ChatAvatar(
                                label: 'you',
                                gradient: const [Color(0xFFFFB3D9), Color(0xFFFF99CC)],
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // ── Messages area ──
                          Expanded(
                            child: AnimatedBuilder(
                              animation: Listenable.merge([_msg1Ctrl, _msg2Ctrl, _msg3Ctrl]),
                              builder: (ctx, _) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Message 1 — from match (left-aligned, blue)
                                    if (_msg1Ctrl.value > 0)
                                      _AnimatedMessage(
                                        controller: _msg1Ctrl,
                                        alignment: Alignment.centerLeft,
                                        child: _ChatBubble(
                                          text: 'i love the smiths.',
                                          timestamp: '6:42 pm',
                                          color: const Color(0xFFB3D9FF),
                                          textColor: const Color(0xFF042C53),
                                          isLeft: true,
                                        ),
                                      ),

                                    // Message 2 — from match (left-aligned, blue)
                                    if (_msg2Ctrl.value > 0) ...[
                                      const SizedBox(height: 2),
                                      _AnimatedMessage(
                                        controller: _msg2Ctrl,
                                        alignment: Alignment.centerLeft,
                                        child: _ChatBubble(
                                          text: 'you have good taste in music.',
                                          timestamp: '6:42 pm',
                                          color: const Color(0xFFB3D9FF),
                                          textColor: const Color(0xFF042C53),
                                          isLeft: true,
                                        ),
                                      ),
                                    ],

                                    // Message 3 — from you (right-aligned, pink)
                                    if (_msg3Ctrl.value > 0) ...[
                                      const SizedBox(height: 2),
                                      _AnimatedMessage(
                                        controller: _msg3Ctrl,
                                        alignment: Alignment.centerRight,
                                        child: _ChatBubble(
                                          text: 'did we just become soulmates? 😭',
                                          timestamp: '6:43 pm',
                                          color: const Color(0xFFFFB3D9),
                                          textColor: const Color(0xFF4B1528),
                                          isLeft: false,
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Background Orbs ───────────────────────────────────────────────────────────
class _BackgroundOrbs extends StatelessWidget {
  final AnimationController orbCtrl;
  const _BackgroundOrbs({required this.orbCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: orbCtrl,
      builder: (ctx, _) {
        final t = orbCtrl.value;
        return Stack(
          children: [
            // Left Orb (Them - Blue)
            Positioned(
              top: 40 + (t * 30),
              left: 10 + (t * 20),
              child: _GlowOrb(
                color: const Color(0xFFB3D9FF).withOpacity(0.6),
                size: 180 + (t * 30),
              ),
            ),
            // Right Orb (You - Pink)
            Positioned(
              bottom: 60 - (t * 30),
              right: 20 + (t * 20),
              child: _GlowOrb(
                color: const Color(0xFFFFB3D9).withOpacity(0.55),
                size: 200 + ((1 - t) * 30),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.4),
            color.withOpacity(0.0),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
    );
  }
}


// ── Animated message wrapper ──────────────────────────────────────────────────
class _AnimatedMessage extends StatelessWidget {
  final AnimationController controller;
  final Alignment alignment;
  final Widget child;

  const _AnimatedMessage({
    required this.controller,
    required this.alignment,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (ctx, _) {
        final t = Curves.easeOutCubic.transform(controller.value.clamp(0.0, 1.0));
        // iOS-style: subtle slide up + gentle scale + fade
        final slideY = (1.0 - t) * 12.0;
        final scale = 0.96 + t * 0.04;
        final opacity = t;
        return Align(
          alignment: alignment,
          child: Transform.translate(
            offset: Offset(0, slideY),
            child: Transform.scale(
              scale: scale,
              alignment: alignment == Alignment.centerLeft
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Opacity(
                opacity: opacity,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}


// ── Chat avatar with label ────────────────────────────────────────────────────
class _ChatAvatar extends StatelessWidget {
  final String label;
  final List<Color> gradient;

  const _ChatAvatar({required this.label, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: gradient),
            border: Border.all(
              color: Colors.white.withOpacity(0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label[0].toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Circular',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Circular',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A0D26).withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

// ── Now Playing card ──────────────────────────────────────────────────────────
class _NowPlayingCard extends StatelessWidget {
  final AnimationController eqCtrl;
  const _NowPlayingCard({required this.eqCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD9B3FF).withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Vinyl record icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFF3A3A3A),
                  Color(0xFF1A1A1A),
                  Color(0xFF2A2A2A),
                  Color(0xFF111111),
                ],
                stops: [0.0, 0.35, 0.65, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
                      width: 4,
                    ),
                  ),
                ),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF99CC).withOpacity(0.9),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NOW PLAYING',
                  style: TextStyle(
                    fontFamily: 'Circular',
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF7DB8),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 0),
                const Text(
                  'There Is a Light That Never...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Circular',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A0D26),
                    height: 1.2,
                  ),
                ),
                const Text(
                  'The Smiths',
                  style: TextStyle(
                    fontFamily: 'Circular',
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8A7EA5),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          // Mini equalizer
          SizedBox(
            width: 28,
            height: 22,
            child: AnimatedBuilder(
              animation: eqCtrl,
              builder: (ctx, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(5, (i) {
                    final t = eqCtrl.value * pi * 2;
                    final h = 6.0 +
                        sin(t + i * 1.3) * 5.0 +
                        cos(t * 1.5 + i * 0.8) * 3.0;
                    return Container(
                      width: 3,
                      height: h.clamp(4.0, 18.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1.5),
                        color: const Color(0xFFB69CFF).withOpacity(0.7),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final String text;
  final String timestamp;
  final Color color;
  final Color textColor;
  final bool isLeft;

  const _ChatBubble({
    required this.text,
    required this.timestamp,
    required this.color,
    required this.textColor,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 170),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.55),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isLeft ? 4 : 16),
              topRight: Radius.circular(isLeft ? 16 : 4),
              bottomLeft: const Radius.circular(16),
              bottomRight: const Radius.circular(16),
            ),
            border: Border.all(color: color.withOpacity(0.35), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Circular',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: EdgeInsets.only(
            left: isLeft ? 4 : 0,
            right: isLeft ? 0 : 4,
          ),
          child: Text(
            timestamp,
            style: TextStyle(
              fontFamily: 'Circular',
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8A7EA5).withOpacity(0.6),
            ),
          ),
        ),
      ],
    );
  }
}
