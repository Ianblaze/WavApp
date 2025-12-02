// match_dock_popup.dart
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

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

/// MATCH DOCK POPUP
/// - Keeps `similarity` parameter (your HomePage still passes it)
/// - `onConnect` = VoidCallback
/// - `onAbandon` = ValueChanged<String?> -> receives the reason (or empty string)
/// - `onDismiss` = VoidCallback
class MatchDockPopup extends StatefulWidget {
  final String username;
  final String photoUrl;
  final String similarity; // kept to match callers
  final VoidCallback onConnect;
  final ValueChanged<String?> onAbandon; // receives reason
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
      duration: const Duration(milliseconds: 1400),
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
    // Stage 1: Flame entrance (slides down from top)
    // Play sound as flame starts sliding in
    _playDing();
    await flameSlideCtrl.forward();

    // Hold flame at position
    await Future.delayed(const Duration(seconds: 2));

    // Flame retreats (slides up smoothly)
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
      await _player.setVolume(1.0);
      await _player.play(AssetSource("sounds/wav_notification.wav"));
      // debug: print("🔊 Playing notification sound at max volume");
    } catch (e) {
      // debug: print("❌ Audio error: $e");
    }
  }

  void toggleExpand() {
    // User can toggle between expanded and collapsed
    if (stage == 3) {
      expandCtrl.reverse().then((_) {
        if (!mounted) return;
        setState(() => stage = 2);
        // Start bouncing again
        orbBounceCtrl.repeat(reverse: true);
      });
    } else if (stage == 2) {
      orbBounceCtrl.stop();
      orbBounceCtrl.animateTo(0).then((_) {
        if (!mounted) return;
        setState(() => stage = 3);
        expandCtrl.forward();
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

  Future<void> _dismissCompletely() async {
    // Collapse to orb first if expanded
    if (stage == 3) {
      await expandCtrl.reverse();
      if (!mounted) return;
      setState(() => stage = 2);
    }
    orbBounceCtrl.stop();

    // Quick smooth slide up and exit
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

  /// ---------------------------
  /// Abandon Reason Dialog (Option A: Simple input dialog in center)
  /// Returns submitted reason string or null if cancelled.
  /// ---------------------------
  Future<String?> _showAbandonReasonDialog() async {
    final TextEditingController controller = TextEditingController();
    String selected = 'Not interested';

    // We'll use StatefulBuilder inside dialog so radio selection updates
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Why are you abandoning?',
            style: TextStyle(color: Colors.white),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Not interested', style: TextStyle(color: Colors.white70)),
                    value: 'Not interested',
                    groupValue: selected,
                    onChanged: (v) => setState(() => selected = v ?? 'Not interested'),
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Found someone else', style: TextStyle(color: Colors.white70)),
                    value: 'Found someone else',
                    groupValue: selected,
                    onChanged: (v) => setState(() => selected = v ?? 'Found someone else'),
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Too far / local', style: TextStyle(color: Colors.white70)),
                    value: 'Too far / local',
                    groupValue: selected,
                    onChanged: (v) => setState(() => selected = v ?? 'Too far / local'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Custom reason (optional)',
                      hintStyle: TextStyle(color: Colors.white30),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954)),
              onPressed: () {
                final text = controller.text.trim();
                final reason = text.isNotEmpty ? text : selected;
                Navigator.of(context).pop(reason);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
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
          // Backdrop only while orb visible - clicking dismisses
          if (stage >= 2)
            AnimatedBuilder(
              animation: orbSlideCtrl,
              builder: (_, __) {
                final t = orbSlideCtrl.value.clamp(0.0, 1.0);
                return GestureDetector(
                  onTap: _dismissCompletely,
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

          // Stage 1: flame GIF slides down from ceiling with bounce on landing
          if (stage == 1)
            AnimatedBuilder(
              animation: flameSlideCtrl,
              builder: (_, __) {
                final progress = flameSlideCtrl.value.clamp(0.0, 1.0);

                // Different curves for entry vs exit
                final double slide;
                if (flameSlideCtrl.status == AnimationStatus.reverse) {
                  // Smooth exit - no bounce
                  slide = Curves.easeInCubic.transform(progress);
                } else {
                  // Ball drop with bounce effect
                  if (progress < 0.5) {
                    // Fast drop phase (like gravity)
                    slide = Curves.easeInQuad.transform(progress / 0.5);
                  } else {
                    // Bounce phase - multiple bounces with decay
                    final bounceProgress = (progress - 0.5) / 0.5;
                    // Creates 2-3 bounces that get smaller
                    final bounce = math.sin(bounceProgress * math.pi * 3) *
                        0.15 *
                        (1 - bounceProgress) *
                        (1 - bounceProgress); // Quadratic decay for realistic bounce
                    slide = 1.0 - bounce.abs();
                  }
                }

                // Start way above screen, slide down to visible position
                final topPosition = -150.0 + (slide * 160.0);

                return Positioned(
                  top: topPosition,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: progress.clamp(0.0, 1.0),
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
                      child: _buildDockCard(),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDockCard() {
    final v = expandCtrl.value.clamp(0.0, 1.0);
    final width = lerpDouble(90, 520, v)!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(45),
        border: Border.all(
          color: Colors.pink.withOpacity(0.4),
          width: 3,
        ),
      ),
      child: Stack(
        children: [
          // ------------------------------------------------------------------
          // PERFECT CIRCLE AVATAR + SHIFT LEFT FOR FIT
          // ------------------------------------------------------------------
          Positioned(
            left: -3, // shifted left so orb sits visually inside pill perfectly
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer pink border circle
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.pink,
                        width: 3,
                      ),
                    ),
                  ),

                  // Avatar perfectly inside with even micro-gap
                  Container(
                    width: 82,
                    height: 82,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2A2A2A),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (widget.photoUrl.isNotEmpty)
                        ? Image.network(
                            widget.photoUrl,
                            fit: BoxFit.cover,
                          )
                        : const Icon(
                            Icons.person,
                            size: 36,
                            color: Colors.white54,
                          ),
                  ),
                ],
              ),
            ),
          ),

          // ------------------------------------------------------------------
          // USERNAME & similarity badge
          // ------------------------------------------------------------------
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            left: v < 0.5 ? 520 : 112, // accommodates the left orb + gap
            top: 0,
            bottom: 0,
            child: Opacity(
              opacity: v < 0.3 ? 0.0 : (v < 0.7 ? (v - 0.3) * 2.5 : 1.0),
              child: SizedBox(
                width: 150,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // USERNAME — larger + nudged down slightly to center visually
                    Transform.translate(
                      offset: const Offset(0, 3),
                      child: Text(
                        widget.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 21,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // SIMILARITY — smaller, lower, tighter
                    Transform.translate(
                      offset: const Offset(0, 3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.pink.withOpacity(0.28),
                              Colors.pinkAccent.withOpacity(0.18),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: Colors.pink.withOpacity(0.45),
                            width: 1.1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${widget.similarity}%", // dynamic (HomePage still passes it)
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.pink.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "similarity",
                              style: TextStyle(
                                color: Colors.pink.shade200,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ------------------------------------------------------------------
          // BUTTONS - Connect / Abandon
          // ------------------------------------------------------------------
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            right: v < 0.5 ? -300 : 20,
            top: 0,
            bottom: 0,
            child: Opacity(
              opacity: v < 0.5 ? 0.0 : (v - 0.5) * 2,
              child: Row(
                children: [
                  _button3D(
                    icon: Icons.check,
                    label: "Connect",
                    primaryColor: const Color(0xFF4CAF50),
                    onTap: () => _handleAction(widget.onConnect),
                  ),
                  const SizedBox(width: 20),
                  _button3D(
                    icon: Icons.close,
                    label: "Abandon",
                    primaryColor: const Color(0xFFE53935),
                    onTap: () async {
                      // Show reason dialog first
                      final reason = await _showAbandonReasonDialog();
                      // If user cancelled (null) -> do nothing
                      if (reason == null) return;
                      // Collapse and call abandon with reason
                      await _handleAction(() => widget.onAbandon(reason));
                    },
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
                      // Icon with scale animation on hover/fill
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
