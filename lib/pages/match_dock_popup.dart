// match_dock_popup.dart
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

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
  // NEW: Shared signal data from matching engine
  final List<String> sharedGenres;
  final List<String> sharedArtists;
  final List<String> sharedSongs;

  const MatchDockPopup({
    super.key,
    required this.username,
    required this.photoUrl,
    required this.similarity,
    required this.onConnect,
    required this.onAbandon,
    required this.onDismiss,
    this.sharedGenres = const [],
    this.sharedArtists = const [],
    this.sharedSongs = const [],
  });

  @override
  State<MatchDockPopup> createState() => _MatchDockPopupState();
}

class _MatchDockPopupState extends State<MatchDockPopup>
    with TickerProviderStateMixin {
  late final AnimationController orbSlideCtrl;
  late final AnimationController orbBounceCtrl;
  late final AnimationController expandCtrl;

  final _player = AudioPlayer();
  bool _dingPlayed = false;

  int stage = 2; // 2 = orb bouncing, 3 = auto-expanded
  double dragDelta = 0;

  @override
  void initState() {
    super.initState();

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
    // Play notification sound
    _playDing();

    // Orb slides in from top
    await orbSlideCtrl.forward();

    // Bounce animation
    orbBounceCtrl.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 1500));
    orbBounceCtrl.stop();
    await orbBounceCtrl.animateTo(0);

    if (!mounted) return;
    // Auto-expand to show full card
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
          // Backdrop - clicking dismisses
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

          // Orb that expands into card
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
    final width = lerpDouble(90, 340, v)!;
    final height = lerpDouble(90, 220, v)!;

    // Parse similarity for quality tier
    final score = double.tryParse(widget.similarity) ?? 0;
    final tierEmoji = score >= 85 ? '🔥' : score >= 65 ? '⚡' : '💫';
    final tierLabel = score >= 85 ? 'Perfect Match' : score >= 65 ? 'Strong Match' : 'Potential Match';
    final tierColor = score >= 85
        ? const Color(0xFFFF6FE8)
        : score >= 65
            ? const Color(0xFFB69CFF)
            : const Color(0xFF7BA7FF);

    // Build shared signal chips
    final chips = <String>[];
    for (final g in widget.sharedGenres.take(2)) {
      chips.add('🎵 $g');
    }
    for (final a in widget.sharedArtists.take(2)) {
      chips.add('🎤 $a');
    }
    if (widget.sharedSongs.isNotEmpty) {
      chips.add('🎶 ${widget.sharedSongs.length} song${widget.sharedSongs.length == 1 ? '' : 's'} in common');
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(v < 0.5 ? 45 : 24),
        border: Border.all(
          color: tierColor.withOpacity(0.4),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: tierColor.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: v < 0.3
          // ── COLLAPSED: just the avatar orb ──────────────────
          ? _buildCollapsedOrb()
          // ── EXPANDED: full card with signals ────────────────
          : Opacity(
              opacity: ((v - 0.3) / 0.7).clamp(0.0, 1.0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top row: avatar + name + tier badge ────────
                    Row(
                      children: [
                        // Avatar
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: tierColor, width: 2.5),
                          ),
                          child: ClipOval(
                            child: (widget.photoUrl.isNotEmpty)
                                ? Image.network(widget.photoUrl, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFF2A2A2A),
                                      child: const Icon(Icons.person, size: 24, color: Colors.white54),
                                    ))
                                : Container(
                                    color: const Color(0xFF2A2A2A),
                                    child: const Icon(Icons.person, size: 24, color: Colors.white54),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Name + tier
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Circular',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              // Quality tier badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tierColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: tierColor.withOpacity(0.4), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(tierEmoji, style: const TextStyle(fontSize: 10)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.similarity}% · $tierLabel',
                                      style: TextStyle(
                                        color: tierColor,
                                        fontFamily: 'Circular',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ── Shared signals row ─────────────────────────
                    if (chips.isNotEmpty)
                      SizedBox(
                        height: 28,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: chips.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (_, i) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                            ),
                            child: Text(
                              chips[i],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontFamily: 'Circular',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // ── Shared song highlight ─────────────────────
                    if (widget.sharedSongs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [tierColor.withOpacity(0.12), tierColor.withOpacity(0.05)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Text('🎧', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'You both liked "${widget.sharedSongs.first}"',
                                style: TextStyle(
                                  color: tierColor,
                                  fontFamily: 'Circular',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Spacer(),

                    // ── Buttons: Connect / Abandon ─────────────────
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _handleAction(widget.onConnect),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [tierColor, tierColor.withOpacity(0.7)],
                                ),
                                borderRadius: BorderRadius.circular(19),
                                boxShadow: [
                                  BoxShadow(color: tierColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 3)),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.music_note_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text('Connect', style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Circular',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  )),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () async {
                            final reason = await _showAbandonReasonDialog();
                            if (reason == null) return;
                            await _handleAction(() => widget.onAbandon(reason));
                          },
                          child: Container(
                            height: 38,
                            width: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(19),
                              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
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

  /// Collapsed state — just the avatar circle
  Widget _buildCollapsedOrb() {
    return Center(
      child: SizedBox(
        width: 82,
        height: 82,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.pink, width: 3),
              ),
            ),
            Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2A2A2A),
              ),
              clipBehavior: Clip.antiAlias,
              child: (widget.photoUrl.isNotEmpty)
                  ? Image.network(widget.photoUrl, fit: BoxFit.cover)
                  : const Icon(Icons.person, size: 36, color: Colors.white54),
            ),
          ],
        ),
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
