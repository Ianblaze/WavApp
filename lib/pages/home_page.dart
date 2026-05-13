// home_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';

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
  final GlobalKey _profileKey = GlobalKey();
  // Mood tint driven by WavPage
  final ValueNotifier<Color> _moodTintNotifier =
      ValueNotifier<Color>(const Color(0xFF9D50BB));
  OverlayEntry? _tutorialOverlay;
  bool _tutorialShown = false;

  // ── Screensaver idle timer (60s of no interaction) ──────────
  Timer? _idleTimer;
  bool _isIdle = false;

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_isIdle && mounted) setState(() => _isIdle = false);
    _idleTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && selectedTab == 1) {
        setState(() => _isIdle = true);
      }
    });
  }

  // ❌ REMOVE THIS OLD LISTENER - we're using the service now
  // StreamSubscription? _matchListener;

  @override
  void initState() {
    super.initState();
    _resetIdleTimer();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowProfileTutorial();
      
      // ✅ START LISTENING TO USER PROFILE
      final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
      if (uid.isNotEmpty) {
        context.read<UserProfileProvider>().startListening(uid);
      }
      
      // ✅ START NOTIFICATION LISTENER via provider
      context.read<MatchProvider>().startNotificationListener(context);
    });
    
    // ❌ REMOVE THIS OLD LISTENER CALL
    // _startMatchListener();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _moodTintNotifier.dispose();
    
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
    if (overlay == null) return;

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
          Scaffold(
            backgroundColor: Colors.transparent,
            body: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _resetIdleTimer(),
              onPointerMove: (_) => _resetIdleTimer(),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: IndexedStack(
                        index: selectedTab,
                        children: [
                          HomeTab(
                            key: const ValueKey(0),
                            onGoToWav:     () => setState(() => selectedTab = 1),
                            onGoToMatches: () => setState(() => selectedTab = 2),
                            moodTint: _moodTintNotifier.value,
                          ),
                          WavPage(
                            key: const ValueKey(1),
                            isActive: selectedTab == 1,
                            isIdle: _isIdle && selectedTab == 1,
                            onMoodChanged: (c) => _moodTintNotifier.value = c,
                          ),
                          MatchPage(
                            key: const ValueKey(2), 
                            uid: FirebaseAuth.instance.currentUser?.uid ?? ""
                          ),
                          const ProfilePage(key: ValueKey(3)),
                        ],
                      ),
                    ),
                    _buildBottomNav(),
                  ],
                ),
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
  // ⬇️ BOTTOM NAVIGATION (PNG ICONS)
  // ---------------------------------------------------------
  Widget _buildBottomNav() {
    final sh = MediaQuery.of(context).size.height;
    return Container(
      padding: EdgeInsets.symmetric(vertical: (sh * 0.016).clamp(8.0, 18.0)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItemPNG('assets/images/home.png', 'Home', 0),
          _navItemPNG('assets/images/wav.png', 'Wav', 1),
          _navItemPNG('assets/images/hh.png', 'Matches', 2),
          _navItemPNG('assets/images/profile.png', 'Profile', 3),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 🔘 Y2K NAV ITEM
  // ---------------------------------------------------------
  Widget _navItemPNG(String assetPath, String label, int index) {
    final isActive = selectedTab == index;
    final sw = MediaQuery.of(context).size.width;
    final iconDim = (sw * 0.08).clamp(26.0, 36.0);
    final labelFont = (sw * 0.032).clamp(10.0, 14.0);

    return GestureDetector(
      onTap: () => setState(() => selectedTab = index),
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(12),
        child: AnimatedScale(
          scale: isActive ? 1.0 : 0.90,
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: isActive ? 1.0 : 0.55,
                child: Image.asset(
                  assetPath,
                  width: iconDim,
                  height: iconDim,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? y2kPink : y2kPurple,
                  fontSize: labelFont,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
