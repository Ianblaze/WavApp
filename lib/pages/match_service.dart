import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MatchService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------
  // 🔥 Save mutual match for both users
  // ---------------------------------------------------------
  Future<void> _saveMutualMatch(String userA, String userB) async {
    // Create match doc under A
    await _db
        .collection('users')
        .doc(userA)
        .collection('matches')
        .doc(userB)
        .set({
      'userId': userB,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Create match doc under B
    await _db
        .collection('users')
        .doc(userB)
        .collection('matches')
        .doc(userA)
        .set({
      'userId': userA,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------
  // 🔥 Check if a mutual match occurred
  // Returns: { uid, username, photoUrl }
  // ---------------------------------------------------------
  Future<Map<String, dynamic>?> checkForMatch(String songId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final currentUserId = user.uid;

    // Get all users (we filter in Dart to avoid permission issues)
    final allUsers = await _db.collection('users').get();

    for (var doc in allUsers.docs) {
      final otherUserId = doc.id;
      if (otherUserId == currentUserId) continue;

      // Check if OTHER liked this song
      final otherLiked = await _db
          .collection('users')
          .doc(otherUserId)
          .collection('likes')
          .doc(songId)
          .get();

      if (!otherLiked.exists) continue;

      // Check if ME liked song
      final meLiked = await _db
          .collection('users')
          .doc(currentUserId)
          .collection('likes')
          .doc(songId)
          .get();

      if (!meLiked.exists) continue;

      // At this point → mutual match
      await _saveMutualMatch(currentUserId, otherUserId);

      // Fetch user's data for popup
      final otherDoc =
          await _db.collection('users').doc(otherUserId).get();

      return {
        'uid': otherUserId,
        'username': otherDoc['username'] ?? 'Unknown',
        'photoUrl': otherDoc['photoUrl'] ?? '',
      };
    }

    return null;
  }

  // ---------------------------------------------------------
  // 🔥 Accept (Connect)
  // ---------------------------------------------------------
  Future<void> acceptMatch(String otherUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await _db
        .collection('users')
        .doc(currentUser.uid)
        .collection('matches')
        .doc(otherUserId)
        .update({'status': 'connected'});

    await _db
        .collection('users')
        .doc(otherUserId)
        .collection('matches')
        .doc(currentUser.uid)
        .update({'status': 'connected'});
  }

  // ---------------------------------------------------------
  // 🔥 Abandon (Decline)
  // NOTE: Your WavPage calls this as declineMatch()
  // ---------------------------------------------------------
  Future<void> declineMatch(String otherUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await _db
        .collection('users')
        .doc(currentUser.uid)
        .collection('matches')
        .doc(otherUserId)
        .update({'status': 'abandoned'});

    await _db
        .collection('users')
        .doc(otherUserId)
        .collection('matches')
        .doc(currentUser.uid)
        .update({'status': 'abandoned'});
  }

  // ---------------------------------------------------------
  // 🔥 Get all match entries
  // (pending + connected + abandoned)
  // ---------------------------------------------------------
  Future<List<Map<String, dynamic>>> getMatches() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final matchSnapshot = await _db
        .collection('users')
        .doc(currentUser.uid)
        .collection('matches')
        .orderBy('timestamp', descending: true)
        .get();

    List<Map<String, dynamic>> matches = [];

    for (var doc in matchSnapshot.docs) {
      final otherUserId = doc['userId'];

      final userDoc =
          await _db.collection('users').doc(otherUserId).get();

      matches.add({
        'userId': otherUserId,
        'username': userDoc['username'] ?? 'Unknown',
        'photoUrl': userDoc['photoUrl'] ?? '',
        'status': doc['status'] ?? 'pending',
        'timestamp': doc['timestamp'],
      });
    }

    return matches;
  }
}
