// home_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import 'wav_page.dart';
import 'home_tab.dart';
import 'profile_page.dart';
import 'profile_setup_dialog.dart';
import 'match_page.dart';

import '../providers/user_profile_provider.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/match_provider.dart';
import '../auth/widgets/auth_video_background.dart';

// ---------------------------------------------------------
// 🎨 LIGHT Y2K BUBBLEGUM POP PALETTE
// ---------------------------------------------------------
const bgTop = Colors.transparent;
const bgMid = Colors.transparent;
const bgBottom = Colors.transparent;

const y2kPink = Color(0xFFFF3399);      // Hot Pink
const y2kBlue = Color(0xFF7BA7FF);      // Candy Blue
const y2kPurple = Color(0xFF9D50BB);    // Neon Purple
const y2kGlowPink = Color(0xFFFF3399);  // Hot Pink
const y2kGlowBlue = Color(0xFFC4D8FF);  // Glow Blue

const textDark = Color(0xFF3A2A45);     // readable violet-brown
const mutedText = Color(0xFF8A7EA5);     // pastel lavender-grey


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedTab = 0;
  late final PageController _navPageController;

  final GlobalKey _profileKey = GlobalKey();
  // Mood tint driven by WavPage
  final ValueNotifier<Color> _moodTintNotifier =
      ValueNotifier<Color>(const Color(0xFF9D50BB));
  OverlayEntry? _tutorialOverlay;
  bool _tutorialShown = false;

  // ── Screensaver idle timer (60s of no interaction) ──────────
  Timer? _idleTimer;
  bool _isIdle = false;

  // ── Navbar idle timer (4s of no interaction) ──────────
  Timer? _navIdleTimer;
  bool _isNavVisible = false; // Start minimized initially

  // ── Global Swipe Progress ──────────
  final ValueNotifier<double> _globalLikeProgress = ValueNotifier(0.0);
  final ValueNotifier<double> _globalDislikeProgress = ValueNotifier(0.0);

  void _resetNavIdleTimer({Duration duration = const Duration(seconds: 4)}) {
    _navIdleTimer?.cancel();
    if (!_isNavVisible && mounted) setState(() => _isNavVisible = true);
    _navIdleTimer = Timer(duration, () {
      if (mounted && _isNavVisible) {
        setState(() => _isNavVisible = false);
      }
    });
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_isIdle && mounted) setState(() => _isIdle = false);
    _idleTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && selectedTab == 1) {
        setState(() => _isIdle = true);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _navPageController = PageController(
      viewportFraction: 0.22, // Balanced for peeking look
      initialPage: selectedTab,
    )..addListener(() {
      // Micro-haptics on minor ticks of rotation
      if (_navPageController.page != null) {
        final currentPos = _navPageController.page!;
        if ((currentPos - currentPos.round()).abs() < 0.05) {
          HapticFeedback.selectionClick();
        }
      }
    });
    _resetIdleTimer();
    // We don't call _resetNavIdleTimer() here because we want it to START minimized
    // But we might want it to show briefly? User said "already scaled down initially"
    // So we just leave it false.
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowProfileTutorial();
      
      // ✅ START LISTENING TO USER PROFILE
      final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
      if (uid.isNotEmpty) {
        context.read<UserProfileProvider>().startListening(uid);
      }
      
      // ✅ START NOTIFICATION LISTENER via provider
      final matchProvider = context.read<MatchProvider>();
      matchProvider.startMatchStream();
      matchProvider.startNotificationListener(context);
    });
  }

  @override
  void dispose() {
    _navPageController.dispose();
    _idleTimer?.cancel();
    _navIdleTimer?.cancel();
    _moodTintNotifier.dispose();
    _globalLikeProgress.dispose();
    _globalDislikeProgress.dispose();
    
    // ✅ Cleanup notification listener
    context.read<MatchProvider>().stopNotificationListener();
    
    _tutorialOverlay?.remove();
    super.dispose();
  }

  // ---------------------------------------------------------
  // 🧭 PROFILE TOOLTIP (unchanged)
  // ---------------------------------------------------------
  Future<void> _maybeShowProfileTutorial() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final username = doc.data()?['username'];
    if (!_tutorialShown && (username == null || username.isEmpty)) {
      _showTooltipBubble();
      _tutorialShown = true;
    }
  }

  void _showTooltipBubble() {
    final overlay = Overlay.of(context);

    final box = _profileKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    final left = (((pos.dx) - 140)
        .clamp(8, MediaQuery.of(context).size.width - 240))
      .toDouble();

    final top = pos.dy + size.height + 8;

    _tutorialOverlay = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: top,
        child: Material(
          color: Colors.transparent,
          child: TooltipBubble(
            onClose: _removeTooltip,
            onSetup: () {
              _removeTooltip();
              _openProfileSetupDialog();
            },
          ),
        ),
      ),
    );

    overlay.insert(_tutorialOverlay!);
  }

  void _removeTooltip() {
    _tutorialOverlay?.remove();
    _tutorialOverlay = null;
  }

  Future<void> _openProfileSetupDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ProfileSetupDialog(),
    );
  }

  // ---------------------------------------------------------
  // 🖥 UI
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: _moodTintNotifier,
      builder: (_, moodTint, __) => Stack(
        children: [
          _buildBackground(),   // 🎬 Cinematic Video Background
          // Full-screen mood tint — covers status bar, nav bar, everything
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  moodTint.withOpacity(0.35),
                  moodTint.withOpacity(0.12),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // ── GLOBAL SWIPE GLOWS (PASS/RED) ──
          Positioned.fill(
            child: ValueListenableBuilder<double>(
              valueListenable: _globalDislikeProgress,
              builder: (_, progress, __) => AnimatedOpacity(
                opacity: progress,
                duration: Duration(milliseconds: progress == 0.0 ? 350 : 0),
                curve: Curves.easeOut,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.2,
                      colors: [
                        const Color(0xFFFF2A2A).withOpacity(0.7),
                        Colors.transparent,
                      ],
                      stops: const [0.3, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── GLOBAL SWIPE GLOWS (LIKE/GREEN) ──
          Positioned.fill(
            child: ValueListenableBuilder<double>(
              valueListenable: _globalLikeProgress,
              builder: (_, progress, __) => AnimatedOpacity(
                opacity: progress,
                duration: Duration(milliseconds: progress == 0.0 ? 350 : 0),
                curve: Curves.easeOut,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.bottomCenter,
                      radius: 1.2,
                      colors: [
                        const Color(0xFF00FF66).withOpacity(0.7),
                        Colors.transparent,
                      ],
                      stops: const [0.3, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _resetIdleTimer(),
              onPointerMove: (_) => _resetIdleTimer(),
              child: Column(
                children: [
                  // 1. TOP BAR (Maintains space)
                  SafeArea(
                    bottom: false,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: selectedTab == 1 ? 0.0 : 1.0,
                      child: IgnorePointer(
                        ignoring: selectedTab == 1,
                        child: _buildTopBar(),
                      ),
                    ),
                  ),

                  // 2. MAIN PAGES (Stacked inside the Column's Expanded area)
                  Expanded(
                    child: Stack(
                      children: [
                        _buildPage(0, HomeTab(
                          onGoToWav:     () => _switchToTab(1),
                          onGoToMatches: () => _switchToTab(2),
                          moodTint: _moodTintNotifier.value,
                        )),
                        _buildPage(1, WavPage(
                          isActive: selectedTab == 1,
                          isIdle: _isIdle && selectedTab == 1,
                          onMoodChanged: (c) => _moodTintNotifier.value = c,
                          onLikeProgress: (p) => _globalLikeProgress.value = p,
                          onDislikeProgress: (p) => _globalDislikeProgress.value = p,
                        )),
                        _buildPage(2, MatchPage(
                          uid: FirebaseAuth.instance.currentUser?.uid ?? ""
                        )),
                        _buildPage(3, const ProfilePage()),
                      ],
                    ),
                  ),

                  // 3. BOTTOM NAV (Maintains space)
                  SafeArea(
                    top: false,
                    child: _buildBottomNav(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 🌈 BACKGROUND GRADIENT + MAX GLOW BLOBS
  // ---------------------------------------------------------
  Widget _buildBackground() {
    return const AuthVideoBackground(
      overlayOpacity: 0.5,
      child: SizedBox.expand(),
    );
  }

  // ---------------------------------------------------------
  // 🔝 TOP BAR
  // ---------------------------------------------------------
  Widget _buildTopBar() {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final btnDim = (sw * 0.1).clamp(34.0, 44.0);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: sw * 0.05,
        vertical: (sh * 0.018).clamp(10.0, 18.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // LOGOUT
          GestureDetector(
            onTap: () async {
              await context.read<AuthProvider>().signOut();
              // No manual navigation — AuthWrapper handles it
            },
            child: Container(
              width: btnDim,
              height: btnDim,
              decoration: BoxDecoration(
                color: y2kPink.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.logout, color: y2kPink, size: btnDim * 0.55),
            ),
          ),

          // PROFILE ICON
          GestureDetector(
            onTap: () => setState(() => selectedTab = 3),
            child: Container(
              key: _profileKey,
              width: btnDim,
              height: btnDim,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(btnDim / 2),
                border: Border.all(color: y2kBlue, width: 2),
                color: Colors.white.withOpacity(0.35),
              ),
              child: Icon(Icons.person_outline, color: y2kBlue, size: btnDim * 0.55),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 📑 TABS
  // ---------------------------------------------------------

  // ---------------------------------------------------------
  // ⬇️ BOTTOM NAVIGATION (Fanned Deck)
  // ---------------------------------------------------------
  Widget _buildBottomNav() {
    final tabs = [
      {'icon': 'assets/images/home.png', 'label': 'Home'},
      {'icon': 'assets/images/logo_final.png', 'label': 'Wav'},
      {'icon': 'assets/images/hh.png', 'label': 'Matches'},
      {'icon': 'assets/images/profile.png', 'label': 'Profile'},
    ];

    return GestureDetector(
      onPanDown: (_) => _resetNavIdleTimer(),
      onPanEnd: (_) => _resetNavIdleTimer(duration: const Duration(milliseconds: 50)),
      onPanCancel: () => _resetNavIdleTimer(duration: const Duration(milliseconds: 50)),
      onTapDown: (_) => _resetNavIdleTimer(),
      onTapUp: (_) => _resetNavIdleTimer(duration: const Duration(milliseconds: 50)),
      onTapCancel: () => _resetNavIdleTimer(duration: const Duration(milliseconds: 50)),
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        height: 85, // Slightly more room for the fanned base
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              _resetNavIdleTimer(); // Keep visible while rotating
            }
            if (notification is ScrollEndNotification) {
              // Quick fade when rotation finishes
              _resetNavIdleTimer(duration: const Duration(milliseconds: 50));
            }
            return false;
          },
          child: PageView.builder(
            physics: const BouncingScrollPhysics(), // Premium spring feel
            controller: _navPageController,
            onPageChanged: (idx) {
              if (selectedTab != idx) {
                _switchToTab(idx);
              }
            },
            itemCount: tabs.length,
            clipBehavior: Clip.none,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _navPageController,
                builder: (context, child) {
                  double value = 0.0;
                  if (_navPageController.position.haveDimensions) {
                    value = (_navPageController.page! - index);
                  } else {
                    value = (selectedTab - index).toDouble();
                  }
                  
                  // Floating Icon Logic (Advanced 3D Depth)
                  final tilt    = (value * -0.4).clamp(-0.8, 0.8);
                  final scale   = (1 - (value.abs() * 0.18)).clamp(0.8, 1.1) * (index == selectedTab ? 1.12 : 1.0);
                  final opacity = (1 - (value.abs() * 0.3)).clamp(0.5, 1.0);
                  final zDist   = (1 - value.abs().clamp(0, 1)) * 120.0; 
                  final transY  = (value.abs() * 40.0) - 10; // Pull HIGHER to fix cutoff
                  final transX  = (value * -12.0);
    
                  return Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002) 
                      ..translate(transX, transY, zDist)
                      ..rotateZ(tilt)
                      ..scale(scale),
                    alignment: Alignment.bottomCenter,
                    child: Opacity(
                      opacity: opacity,
                      child: OverflowBox(
                        maxWidth: 220,
                        maxHeight: 280,
                        child: _navCardItem(
                          tabs[index]['icon']!,
                          tabs[index]['label']!,
                          index == selectedTab,
                          index,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _navCardItem(String icon, String label, bool isActive, int index) {
    return GestureDetector(
      onTap: () {
        _navPageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
        );
      },
      child: Center(
        child: AnimatedOpacity(
          duration: Duration(milliseconds: _isNavVisible ? 100 : 800), // Instant in, smooth out
          curve: _isNavVisible ? Curves.easeOutCubic : Curves.easeInCubic,
          opacity: (isActive || _isNavVisible) ? 1.0 : 0.0,
          child: AnimatedScale(
            duration: Duration(milliseconds: _isNavVisible ? 150 : 800), // Pop in, glide out
            curve: _isNavVisible ? Curves.easeOutBack : Curves.easeInCubic,
            scale: _isNavVisible ? 1.0 : 0.65, 
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset(
                  icon,
                  width: icon.contains('logo_final') ? 85 : 65, // Normalized Wav icon size
                  height: icon.contains('logo_final') ? 85 : 65,
                ),
                // Notification Badge for Matches (tab index 2)
                if (index == 2)
                  Consumer<MatchProvider>(
                    builder: (context, mp, _) {
                      if (mp.pendingCount <= 0) return const SizedBox.shrink();
                      return Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: y2kPink,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '${mp.pendingCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 🔘 LEGACY NAV ITEM (for reference or cleanup)
  // ---------------------------------------------------------
  Widget _navItemPNG(String assetPath, String label, int index) {
    final isActive = selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = index),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(assetPath, width: 28, height: 28),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
    );
  }
  void _switchToTab(int index) {
    if (index == selectedTab) return;
    setState(() => selectedTab = index);
    _resetNavIdleTimer();
    HapticFeedback.lightImpact();
  }

  Widget _buildPage(int index, Widget child) {
    final bool isActive = selectedTab == index;
    return Offstage(
      offstage: !isActive && _moodTintNotifier.value.opacity == 1.0, // Only offstage if fully faded
      // Actually, for cross-fade we can't use Offstage until opacity is 0.
      // But we can use it to completely skip layout when not visible.
      child: IgnorePointer(
        ignoring: !isActive,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutQuart,
          scale: isActive ? 1.0 : 0.92,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            opacity: isActive ? 1.0 : 0.0,
            child: child,
          ),
        ),
      ),
    );
  }

}
// ---------------------------------------------------------
// 🗨 TOOLTIP BUBBLE
// ---------------------------------------------------------
class TooltipBubble extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onSetup;

  const TooltipBubble({
    required this.onClose,
    required this.onSetup,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 240,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: y2kPink.withOpacity(0.4), blurRadius: 20),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Set up your profile",
                style: TextStyle(
                    color: textDark, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                "Tap here to add a photo and username.",
                style: TextStyle(color: mutedText, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onClose,
                    child: const Text(
                      "Later",
                      style: TextStyle(color: mutedText),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: onSetup,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: y2kPink),
                    child: const Text(
                      "Set Up",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        CustomPaint(
          painter: _ArrowPainter(),
          child: const SizedBox(width: 20, height: 12),
        ),
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.75);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
