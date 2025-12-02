// home_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'wav_page.dart';
import 'profile_page.dart';
import 'profile_setup_dialog.dart';
import 'match_page.dart';

import '../pages/match_dock_popup.dart';
import '../pages/match_service.dart';
import '../auth/login_page.dart';

// ---------------------------------------------------------
// 🎨 LIGHT Y2K BUBBLEGUM POP PALETTE
// ---------------------------------------------------------
const bgTop = Color(0xFFFFE6FF);        // pearl pink
const bgMid = Color(0xFFF3E5FF);        // lilac pink
const bgBottom = Color(0xFFE1E9FF);     // cotton blue

const y2kPink = Color(0xFFFF6FE8);      // bubblegum neon pink
const y2kBlue = Color(0xFF7BA7FF);      // candy blue
const y2kPurple = Color(0xFFB69CFF);    // lavender
const y2kGlowPink = Color(0xFFFFC0FA);  // bright glow pink
const y2kGlowBlue = Color(0xFFC4D8FF);  // glow blue

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
  OverlayEntry? _tutorialOverlay;
  bool _tutorialShown = false;

  StreamSubscription? _matchListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowProfileTutorial();
    });
    _startMatchListener();
  }

  @override
  void dispose() {
    _matchListener?.cancel();
    _tutorialOverlay?.remove();
    super.dispose();
  }

  // ---------------------------------------------------------
  // 🔥 MATCH LISTENER
  // ---------------------------------------------------------
  void _startMatchListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _matchListener = FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("matches")
        .where("status", isEqualTo: "incoming")
        .orderBy("timestamp", descending: true)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docChanges.isEmpty) return;

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final otherId = data["userId"];
          final score = data["compatibilityScore"] ?? 80;

          final userDoc = await FirebaseFirestore.instance
              .collection("users")
              .doc(otherId)
              .get();

          final username = userDoc["username"] ?? "Someone";
          final photoUrl = userDoc["photoUrl"] ?? "";

          _showMatchPopup(
            otherId,
            username,
            photoUrl,
            score.toString(),
          );
        }
      }
    });
  }

  // ---------------------------------------------------------
  // ❤️ MATCH POPUP
  // ---------------------------------------------------------
  void _showMatchPopup(
      String otherId, String username, String photoUrl, String similarity) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return MatchDockPopup(
          username: username,
          photoUrl: photoUrl,
          similarity: similarity,
          onConnect: () async {
            await MatchService().acceptIncomingRequest(otherId);
          },
          onAbandon: (reason) async {
            await MatchService()
                .declineIncomingRequest(otherId, reason ?? "No reason");
          },
          onDismiss: () => Navigator.of(context).pop(),
        );
      },
    );
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
    return Stack(
      children: [
        _buildBackground(),   // 🌈 Y2K GRADIENT + GLOW BLOBS
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildTabContent()),
                _buildBottomNav(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // 🌈 BACKGROUND GRADIENT + MAX GLOW BLOBS
  // ---------------------------------------------------------
  Widget _buildBackground() {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          bgTop,     // soft pearl pink
          bgMid,     // light lilac
          bgBottom,  // pastel baby blue
        ],
      ),
    ),
  );
}


  // ---------------------------------------------------------
  // 🔝 TOP BAR
  // ---------------------------------------------------------
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // LOGOUT
          GestureDetector(
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: y2kPink.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout, color: y2kPink),
            ),
          ),

          // PROFILE ICON
          GestureDetector(
            onTap: () => setState(() => selectedTab = 3),
            child: Container(
              key: _profileKey,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: y2kBlue, width: 2),
                color: Colors.white.withOpacity(0.35),
              ),
              child: const Icon(Icons.person_outline, color: y2kBlue),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 📑 TABS
  // ---------------------------------------------------------
  Widget _buildTabContent() {
    switch (selectedTab) {
      case 0:
        return _placeholder("Home", Icons.home_rounded);
      case 1:
        return const WavPage();
      case 2:
        final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
        return MatchPage(uid: uid);
      case 3:
        return const ProfilePage();
      default:
        return _placeholder("Home", Icons.home_rounded);
    }
  }

  Widget _placeholder(String name, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: y2kPink, size: 80),
          const SizedBox(height: 24),
          Text(
            name,
            style: const TextStyle(
              color: y2kPurple,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Coming soon...',
            style: TextStyle(color: mutedText, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // ⬇️ BOTTOM NAVIGATION (PNG ICONS PRESERVED)
  // ---------------------------------------------------------
  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
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
  // 🔘 Y2K NAV ITEM WITH BIG BUBBLEGUM RIPPLE
  // ---------------------------------------------------------
  Widget _navItemPNG(String assetPath, String label, int index) {
    final isActive = selectedTab == index;

    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: () => setState(() => selectedTab = index),
        radius: 150, // huge ripple
        splashColor: y2kPink.withOpacity(0.45),
        highlightColor: y2kBlue.withOpacity(0.4),
        containedInkWell: false,
        child: Padding(
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
                    width: 34,
                    height: 34,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? y2kPink : y2kPurple,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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
                  color: textDark,
                  fontWeight: FontWeight.w700),
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
