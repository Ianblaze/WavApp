// match_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/chat_page.dart';

// ---------------------------------------------------------
// 🎨 Y2K LIGHT THEME COLORS
// ---------------------------------------------------------
const bgTop = Color(0xFFFFE6FF);
const bgMid = Color(0xFFF3E5FF);
const bgBottom = Color(0xFFE1E9FF);

const y2kPink = Color(0xFFFF6FE8);
const y2kBlue = Color(0xFF7BA7FF);
const y2kPurple = Color(0xFFB69CFF);
const mutedText = Color(0xFF8A7EA5);
const textDark = Color(0xFF3A2A45);

class MatchPage extends StatefulWidget {
  final String uid;

  const MatchPage({super.key, required this.uid});

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> _matchesStream() {
    return _db
        .collection('users')
        .doc(widget.uid)
        .collection('matches')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bgTop, bgMid, bgBottom],
            ),
          ),
        ),

        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              "Your Matches",
              style: TextStyle(
                color: y2kPurple,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _matchesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: y2kPink),
                );
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Text("Error loading matches", style: TextStyle(color: textDark)),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    "No matches yet 👀\nSwipe more songs!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: mutedText, fontSize: 16),
                  ),
                );
              }

              final List<Map<String, dynamic>> allMatches =
                  docs.map((d) => {...d.data(), 'docId': d.id}).toList();

              final incoming =
                  allMatches.where((m) => m['status'] == 'incoming').toList();
              final outgoing =
                  allMatches.where((m) => m['status'] == 'pending' || m['status'] == 'outgoing').toList();
              final connected =
                  allMatches.where((m) => m['status'] == 'connected').toList();
              final abandoned =
                  allMatches.where((m) => m['status'] == 'abandoned').toList();

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: [
                  if (incoming.isNotEmpty) _sectionTitle("Incoming Requests"),
                  for (var m in incoming) MatchCard(matchData: m),

                  if (outgoing.isNotEmpty) _sectionTitle("Pending (Outgoing)"),
                  for (var m in outgoing) MatchCard(matchData: m),

                  if (connected.isNotEmpty) _sectionTitle("Recent Matches"),
                  for (var m in connected) MatchCard(matchData: m),

                  if (abandoned.isNotEmpty)
                    _sectionTitle("Abandoned", color: y2kPink),
                  for (var m in abandoned) MatchCard(matchData: m),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, {Color color = y2kPurple}) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 🔥 Match Card + Chat Button
// ---------------------------------------------------------
class MatchCard extends StatelessWidget {
  final Map<String, dynamic> matchData;

  MatchCard({super.key, required this.matchData});

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Ensures both users share the same chatId
  String _generateChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return "${sorted[0]}_${sorted[1]}";
  }

  Future<Map<String, String>> _resolveProfile(
      String userId, Map<String, dynamic> docFields) async {
    final usernameFromDoc =
        docFields['username'] ?? docFields['displayName'];
    final photoFromDoc =
        docFields['photoUrl'] ?? docFields['avatar'];

    if (usernameFromDoc != null || photoFromDoc != null) {
      return {
        'username': usernameFromDoc ?? 'Unknown',
        'photoUrl': photoFromDoc ?? '',
      };
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final data = snap.data() ?? {};
      return {
        'username': data['username'] ?? data['displayName'] ?? 'Unknown',
        'photoUrl': data['photoUrl'] ?? '',
      };
    } catch (_) {
      return {'username': 'Unknown', 'photoUrl': ''};
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherUserId = matchData['userId'];
    final status = matchData['status'];
    final assignedRole = matchData['assignedRole'] ?? '';

    return FutureBuilder<Map<String, String>>(
      future: _resolveProfile(otherUserId, matchData),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        final profile = snap.data!;
        final username = profile['username']!;
        final photoUrl = profile['photoUrl']!;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF0E7FF),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: y2kPurple.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // CARD CONTENT
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : const AssetImage("assets/images/default_pfp.png")
                            as ImageProvider,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            color: textDark,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (status == "connected")
                          const Text(
                            "Connected ✔",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // CHAT BUTTON
              Positioned(
                right: 6,
                bottom: 6,
                child: GestureDetector(
                  onTapDown: (_) {},
                  onTapUp: (_) {},
                  onTap: () async {
                    final currentUser = FirebaseAuth.instance.currentUser!;
                    final currentUserId = currentUser.uid;

                    // Generate chatId if missing
                    String chatId = matchData["chatId"] ?? "";

                    if (chatId.trim().isEmpty) {
                      chatId = _generateChatId(currentUserId, otherUserId);

                      // Save chatId to both users' match documents
                      await FirebaseFirestore.instance
                          .collection("users")
                          .doc(currentUserId)
                          .collection("matches")
                          .doc(matchData["docId"])
                          .update({"chatId": chatId});

                      await FirebaseFirestore.instance
                          .collection("users")
                          .doc(otherUserId)
                          .collection("matches")
                          .doc(currentUserId)
                          .update({"chatId": chatId});
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          chatId: chatId,
                          otherUserId: otherUserId,
                          otherUsername: username,
                          otherPhotoUrl: photoUrl,
                        ),
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Center(
                      child: Image.asset(
                        "assets/images/chat.png",
                        width: 80,
                        height: 80,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
