import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/setup_firestore.dart';
import 'profile_setup_dialog.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Center(
        child: Text("Not signed in", style: TextStyle(color: Colors.white)),
      );
    }

    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text("Error", style: TextStyle(color: Colors.white)),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data =
            snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final username = data['username'] as String? ?? 'No name';
        final photoUrl = data['photoUrl'] as String? ?? '';
        final liked =
            (data['likedSongs'] as List<dynamic>?)?.cast<String>() ?? [];
        final matches =
            (data['recentMatches'] as List<dynamic>?)?.cast<String>() ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------- HEADER ----------------
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF1F1F1F),
                    backgroundImage:
                        photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 36)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Recent matches: ${matches.length}",
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _openEditDialog(),
                    icon: const Icon(Icons.edit, color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ---------------- LIKED SONGS ----------------
              const Text("Liked history",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),

              if (liked.isEmpty)
                const Text("You haven't liked any songs yet.",
                    style: TextStyle(color: Colors.white70))
              else
                Column(
                    children: liked.map((s) => _songTile(s)).toList()),

              const SizedBox(height: 24),

              // ---------------- RECENT MATCHES ----------------
              const Text("Recent Matches",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),

              if (matches.isEmpty)
                const Text("No matches yet — start swiping!",
                    style: TextStyle(color: Colors.white70))
              else
                Column(
                    children: matches.map((m) => _matchTile(m)).toList()),

              const SizedBox(height: 40),

              // ---------------- DEBUG INITIALIZER BUTTON ----------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      "⚠ FIRESTORE INITIALIZATION",
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () async {
                        await FirestoreSetupService().initialize();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text("🔥 Firestore Initialized")),
                          );
                        }
                      },
                      child: const Text("Run Setup"),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Delete this button after running once.",
                      style:
                          TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),
            ],
          ),
        );
      },
    );
  }

  Widget _songTile(String title) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
              width: 48,
              height: 48,
              color: const Color(0xFF1E1E1E),
              child:
                  const Icon(Icons.music_note, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: const TextStyle(color: Colors.white))),
          IconButton(
              onPressed: () {},
              icon:
                  const Icon(Icons.more_vert, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _matchTile(String name) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
          backgroundColor: Color(0xFF1E1E1E),
          child: Icon(Icons.person, color: Colors.white)),
      title: Text(name, style: const TextStyle(color: Colors.white)),
      subtitle: const Text("Matched 2 days ago",
          style: TextStyle(color: Colors.white54)),
      trailing:
          IconButton(onPressed: () {}, icon: const Icon(Icons.chat, color: Colors.white)),
    );
  }

  Future<void> _openEditDialog() async {
    await showDialog(
        context: context,
        builder: (_) => const ProfileSetupDialog());
  }
}
