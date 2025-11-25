// match_dock_popup.dart
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 🔥 Animated flame is a simple GIF asset (flamegif.gif) shown with Image.asset.
/// Make sure pubspec.yaml lists: assets/images/flamegif.gif
class AnimatedFlameIcon extends StatelessWidget {
  const AnimatedFlameIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: Image.asset(
        "assets/images/flamegif.gif",
        fit: BoxFit.contain,
      ),
    );
  }
}

class MatchDockPopup extends StatefulWidget {
  final String username;
  final String photoUrl;
  final String similarity;
  final VoidCallback onConnect;
  final VoidCallback onAbandon;
  final VoidCallback onDismiss;

  const MatchDockPopup({
    super.key,
    required this.username,
    required this.photoUrl,
    required this.similarity,
    required this.onConnect,
    required this.onAbandon,
    required this.onDismiss,
  });

  @override
  State<MatchDockPopup> createState() => _MatchDockPopupState();
}

class _MatchDockPopupState extends State<MatchDockPopup>
    with TickerProviderStateMixin {
  late final AnimationController flameSlideCtrl;
  late final AnimationController orbSlideCtrl;
  late final AnimationController orbBounceCtrl;
  late final AnimationController expandCtrl;

  final _player = AudioPlayer();
  bool _dingPlayed = false;

  int stage = 1; // 1 = flame, 2 = orb bouncing, 3 = auto-expanded
  double dragDelta = 0;

  @override
  void initState() {
    super.initState();

    flameSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    orbSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    orbBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Play sound when flame starts appearing
    _playDing();
    
    // Stage 1: Flame entrance (slides down)
    await flameSlideCtrl.forward();

    // Hold flame
    await Future.delayed(const Duration(seconds: 2));

    // Flame retreats (slides up)
    await flameSlideCtrl.reverse();

    if (!mounted) return;
    // Stage 2: Orb appears and bounces
    setState(() => stage = 2);
    await orbSlideCtrl.forward();

    // Bounce animation
    orbBounceCtrl.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 1500));
    orbBounceCtrl.stop();
    await orbBounceCtrl.animateTo(0);

    if (!mounted) return;
    // Stage 3: Auto-expand to show buttons
    setState(() => stage = 3);
    await expandCtrl.forward();
  }

  Future<void> _playDing() async {
    if (_dingPlayed) return;
    _dingPlayed = true;
    try {
      await _player.setVolume(0.10);
      await _player.play(AssetSource("sounds/wav_notification.wav"));
    } catch (_) {
      // ignore audio failures
    }
  }

  void toggleExpand() {
    // User can collapse back to just profile
    if (stage == 3) {
      expandCtrl.reverse().then((_) {
        if (!mounted) return;
        setState(() => stage = 2);
        // Start bouncing again
        orbBounceCtrl.repeat(reverse: true);
      });
    }
  }

  void dragUpdate(DragUpdateDetails d) {
    // Swipe left to collapse
    if (stage == 3) {
      dragDelta += d.delta.dx;
      if (dragDelta < -30) {
        toggleExpand();
        dragDelta = 0;
      }
    }
  }

  void dragEnd(DragEndDetails d) => dragDelta = 0;

  Future<void> _dismiss() async {
    // Smooth collapse and exit
    if (stage == 3) {
      await expandCtrl.reverse();
      if (!mounted) return;
      setState(() => stage = 2);
    }
    orbBounceCtrl.stop();
    
    // Quick smooth slide up
    await orbSlideCtrl.reverse();
    
    if (!mounted) return;
    widget.onDismiss();
  }

  Future<void> _handleAction(VoidCallback action) async {
    // Quick collapse
    if (stage == 3) {
      await expandCtrl.reverse();
      if (!mounted) return;
      setState(() => stage = 2);
    }
    orbBounceCtrl.stop();
    
    // Quick smooth slide up
    await orbSlideCtrl.reverse();
    
    if (!mounted) return;
    action();
    widget.onDismiss();
  }

  @override
  void dispose() {
    flameSlideCtrl.dispose();
    orbSlideCtrl.dispose();
    orbBounceCtrl.dispose();
    expandCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Backdrop only while orb visible
          if (stage >= 2)
            AnimatedBuilder(
              animation: orbSlideCtrl,
              builder: (_, __) {
                final t = orbSlideCtrl.value.clamp(0.0, 1.0);
                return GestureDetector(
                  onTap: _dismiss,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 8 * t,
                      sigmaY: 8 * t,
                    ),
                    child: Container(
                      color: Colors.black.withOpacity(0.3 * t),
                    ),
                  ),
                );
              },
            ),

          // Stage 1: flame GIF slides down smoothly from top
          if (stage == 1)
            AnimatedBuilder(
              animation: flameSlideCtrl,
              builder: (_, __) {
                final progress = flameSlideCtrl.value.clamp(0.0, 1.0);
                final slide = Curves.easeOutCubic.transform(progress);
                return Positioned(
                  top: -100 + (slide * 110),
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: progress,
                    child: const Center(child: AnimatedFlameIcon()),
                  ),
                );
              },
            ),

          // Stage 2/3: orb that expands
          if (stage >= 2)
            AnimatedBuilder(
              animation: Listenable.merge([orbSlideCtrl, orbBounceCtrl, expandCtrl]),
              builder: (_, __) {
                final slide = Curves.easeOutCubic.transform(orbSlideCtrl.value.clamp(0.0, 1.0));
                final bounce = math.sin(orbBounceCtrl.value * math.pi) * 8;
                
                return Positioned(
                  top: -100 + slide * 106 + bounce,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: toggleExpand,
                      onHorizontalDragUpdate: dragUpdate,
                      onHorizontalDragEnd: dragEnd,
                      child: MatchOrb(
                        username: widget.username,
                        photoUrl: widget.photoUrl,
                        similarity: widget.similarity,
                        expandValue: expandCtrl.value.clamp(0.0, 1.0),
                        onConnect: () => _handleAction(widget.onConnect),
                        onAbandon: () => _handleAction(widget.onAbandon),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class MatchOrb extends StatelessWidget {
  final String username;
  final String photoUrl;
  final String similarity;
  final double expandValue;
  final VoidCallback onConnect;
  final VoidCallback onAbandon;

  const MatchOrb({
    super.key,
    required this.username,
    required this.photoUrl,
    required this.similarity,
    required this.expandValue,
    required this.onConnect,
    required this.onAbandon,
  });

  @override
  Widget build(BuildContext context) {
    final v = expandValue.clamp(0.0, 1.0);
    final width = lerpDouble(90, 520, v)!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(45),
        border: Border.all(
          color: Colors.pink.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Avatar - stays in place, perfectly centered
          Positioned(
            left: 5,
            top: 5,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.pink.withOpacity(0.5),
                    Colors.pinkAccent.withOpacity(0.3),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF2A2A2A),
                  ),
                  child: ClipOval(
                    child: (photoUrl.isNotEmpty)
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFF2A2A2A),
                                child: const Icon(
                                  Icons.person,
                                  size: 36,
                                  color: Colors.white54,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: const Color(0xFF2A2A2A),
                            child: const Icon(
                              Icons.person,
                              size: 36,
                              color: Colors.white54,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),

          // Username & similarity - slide in from right next to avatar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            left: v < 0.5 ? 520 : 95,
            top: 0,
            bottom: 0,
            child: Opacity(
              opacity: v < 0.3 ? 0.0 : (v < 0.7 ? (v - 0.3) * 2.5 : 1.0),
              child: SizedBox(
                width: 130,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.pink.withOpacity(0.3),
                            Colors.pinkAccent.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.pink.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "$similarity%",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.pink.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "match",
                            style: TextStyle(
                              color: Colors.pink.shade200,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
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

          // Buttons - soft pill shaped, evenly spaced
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            right: v < 0.5 ? -300 : 15,
            top: 0,
            bottom: 0,
            child: Opacity(
              opacity: v < 0.5 ? 0.0 : (v - 0.5) * 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _button3D(
                    icon: Icons.check,
                    label: "Connect",
                    primaryColor: const Color(0xFF4CAF50),
                    onTap: onConnect,
                  ),
                  const SizedBox(width: 15),
                  _button3D(
                    icon: Icons.close,
                    label: "Abandon",
                    primaryColor: const Color(0xFFE53935),
                    onTap: onAbandon,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button3D({
    required IconData icon,
    required String label,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return _Button3DState(
      icon: icon,
      label: label,
      primaryColor: primaryColor,
      onTap: onTap,
    );
  }
}

class _Button3DState extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color primaryColor;
  final VoidCallback onTap;

  const _Button3DState({
    required this.icon,
    required this.label,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  State<_Button3DState> createState() => _Button3DStateImpl();
}

class _Button3DStateImpl extends State<_Button3DState> {
  bool isHovered = false;
  bool isPressed = false;
  bool isFilling = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            isPressed = true;
            isFilling = true;
          });
        },
        onTapUp: (_) async {
          setState(() => isPressed = false);
          // Wait for fill animation
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) {
            widget.onTap();
            setState(() => isFilling = false);
          }
        },
        onTapCancel: () => setState(() {
          isPressed = false;
          isFilling = false;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..translate(0.0, isPressed ? 2.0 : 0.0, 0.0),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isHovered ? 17.0 : 16.0,
              vertical: isHovered ? 13.0 : 12.0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isPressed
                    ? [
                        widget.primaryColor.withOpacity(0.8),
                        widget.primaryColor.withOpacity(0.6),
                      ]
                    : [
                        widget.primaryColor,
                        widget.primaryColor.withOpacity(0.8),
                      ],
              ),
              boxShadow: isPressed
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: widget.primaryColor.withOpacity(0.5),
                        blurRadius: isHovered ? 14 : 12,
                        spreadRadius: isHovered ? 1.5 : 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
              border: Border.all(
                color: Colors.white.withOpacity(isHovered ? 0.35 : 0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated white circle that fills on click
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // White border circle (always visible)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                      // Fill animation on click
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        width: isFilling ? 24 : 0,
                        height: isFilling ? 24 : 0,
                        decoration: BoxDecoration(
                          color: widget.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Icon with scale animation on hover
                      AnimatedScale(
                        scale: (isFilling || isHovered) ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: (isFilling || isHovered) ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.icon,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.0,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
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
  }
}