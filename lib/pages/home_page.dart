import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'wav_page.dart';
import 'profile_page.dart';
import 'profile_setup_dialog.dart';
import 'match_page.dart';

// NEW: MatchDockPopup + MatchService
import '../pages/match_dock_popup.dart';
import '../pages/match_service.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowProfileTutorial();
    });

    _listenForNewMatches(); // realtime listener
  }

  // -----------------------------------------------------------
  // 🔥 REAL-TIME MATCH LISTENER — Uses MatchDockPopup
  // -----------------------------------------------------------
  void _listenForNewMatches() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('matches')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docChanges.isEmpty) return;

      final change = snapshot.docChanges.first;

      if (change.type == DocumentChangeType.added) {
        final matchedUserId = change.doc['userId'];

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(matchedUserId)
            .get();

        final username = userDoc['username'] ?? 'Unknown';
        final photoUrl = userDoc['photoUrl'] ?? '';

        _showMatchPopup(username, matchedUserId, photoUrl);
      }
    });
  }

  // -----------------------------------------------------------
  // ❤️ SHOW MATCH DOCK POPUP
  // -----------------------------------------------------------
  void _showMatchPopup(String username, String userId, String photoUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return MatchDockPopup(
          username: username,
          photoUrl: photoUrl,
          similarity: "85", // placeholder
          onConnect: () async {
            await MatchService().acceptMatch(userId);
            Navigator.of(context).pop();
          },
          onAbandon: () async {
            await MatchService().declineMatch(userId);
            Navigator.of(context).pop();
          },
          onDismiss: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  // -----------------------------------------------------------
  // PROFILE TOOLTIP LOGIC (unchanged)
  // -----------------------------------------------------------
  Future<void> _maybeShowProfileTutorial() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final username = doc.data()?['username'];
    if (!_tutorialShown && (username == null || (username as String).isEmpty)) {
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

    final left = (((pos.dx) - 140).clamp(
      8,
      MediaQuery.of(context).size.width - 240,
    )).toDouble();

    final top = (pos.dy + size.height + 8);

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

  @override
  void dispose() {
    _tutorialOverlay?.remove();
    super.dispose();
  }

  // -----------------------------------------------------------
  // UI LAYOUT
  // -----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildTabContent()),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.music_note, color: Colors.black),
          ),

          GestureDetector(
            onTap: () => setState(() => selectedTab = 3),
            child: Container(
              key: _profileKey,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF282828),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF535353), width: 2),
              ),
              child: const Icon(Icons.person_outline, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (selectedTab) {
      case 0:
        return _placeholder("Home", Icons.home_rounded);
      case 1:
        return const WavPage();
      case 2:
        final user = FirebaseAuth.instance.currentUser;
        return MatchPage(uid: user?.uid ?? "");
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
          Icon(icon, color: const Color(0xFF1DB954), size: 80),
          const SizedBox(height: 24),
          Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text('Coming soon...',
              style: TextStyle(color: Color(0xFF7F7F7F), fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF282828), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(Icons.home_rounded, 'Home', 0),
          _buildNavItem(Icons.graphic_eq_rounded, 'Wav', 1),
          _buildNavItem(Icons.favorite_rounded, 'Matches', 2),
          _buildNavItem(Icons.person_rounded, 'Profile', 3),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isActive = selectedTab == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color:
                    isActive ? const Color(0xFF1DB954) : const Color(0xFF7F7F7F),
                size: 28),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color:
                        isActive ? const Color(0xFF1DB954) : const Color(0xFF7F7F7F),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// TOOLTIP STUFF (unchanged)
class TooltipBubble extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onSetup;

  const TooltipBubble({required this.onClose, required this.onSetup, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 240,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Set up your profile",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text("Tap here to add a photo and username.",
                  style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: onClose,
                      child: const Text(
                        "Later",
                        style: TextStyle(color: Color(0xFFBBBBBB)),
                      )),
                  ElevatedButton(
                    onPressed: onSetup,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954)),
                    child: const Text("Set Up",
                        style: TextStyle(color: Colors.black)),
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
    final p = Paint()..color = const Color(0xFF1E1E1E);
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
