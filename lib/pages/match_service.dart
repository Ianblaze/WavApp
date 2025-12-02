// match_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MatchService {
  final _db = FirebaseFirestore.instance;

  // ============================================================
  // 🔥 SEND MATCH REQUEST (WE ARE INITIATOR)
  // ============================================================
  Future<void> sendMatchRequest(String otherUserId) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null || me == otherUserId) return;

    final myRef = _db.collection('users').doc(me).collection('matches').doc(otherUserId);
    final otherRef = _db.collection('users').doc(otherUserId).collection('matches').doc(me);

    final batch = _db.batch();

    // My outgoing request
    batch.set(myRef, {
      'userId': otherUserId,
      'status': 'pending',
      'decision': 'connect',
      'assignedRole': 'initiator',
      'reason': '',
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Their incoming request
    batch.set(otherRef, {
      'userId': me,
      'status': 'incoming',
      'decision': 'none',
      'assignedRole': 'receiver',
      'reason': '',
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // ============================================================
  // 🔥 ACCEPT REQUEST (RECEIVER → CONNECT)
  // ============================================================
  Future<void> acceptIncomingRequest(String otherUserId) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;

    final myRef = _db.collection('users').doc(me).collection('matches').doc(otherUserId);
    final otherRef = _db.collection('users').doc(otherUserId).collection('matches').doc(me);

    final batch = _db.batch();

    batch.update(myRef, {
      'status': 'connected',
      'decision': 'connect',
      'timestamp': FieldValue.serverTimestamp(),
    });

    batch.update(otherRef, {
      'status': 'connected',
      'decision': 'connect',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ============================================================
  // 🔥 DECLINE REQUEST (RECEIVER → ABANDON)
  // ============================================================
  Future<void> declineIncomingRequest(String otherUserId, String? reason) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;

    final myRef = _db.collection('users').doc(me).collection('matches').doc(otherUserId);
    final otherRef = _db.collection('users').doc(otherUserId).collection('matches').doc(me);

    final batch = _db.batch();

    // YOU abandoned
    batch.update(myRef, {
      'status': 'abandoned',
      'decision': 'abandon',
      'reason': reason ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // OTHER sees "abandon_by_other"
    batch.update(otherRef, {
      'status': 'abandoned',
      'decision': 'abandon_by_other',
      'reason': reason ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ============================================================
  // 🔥 MAIN MATCHING LOGIC — CALLED AFTER EACH LIKE
  // ============================================================
  Future<void> processMatchesForUser() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;

    final meDoc = await _db.collection('users').doc(me).get();
    final meProfile = (meDoc.data()?['tasteProfile'] as Map<String, dynamic>?) ?? {};

    if (meProfile.isEmpty) return;

    final allUsers = await _db.collection('users').get();

    for (var doc in allUsers.docs) {
      final otherId = doc.id;
      if (otherId == me) continue;

      final otherProfile =
          (doc.data()['tasteProfile'] as Map<String, dynamic>?) ?? {};

      if (otherProfile.isEmpty) continue;

      final sim = _computeSimilarity(meProfile, otherProfile);

      // Only strong matches
      if (sim < 60.0) continue;

      try {
        await _handleCompatibility(me, otherId);
      } catch (e) {
        print("⚠️ match error with $otherId → $e");
      }
    }
  }

  // ============================================================
  // 🔥 INTERNAL COMPATIBILITY HANDLER
  // ============================================================
  Future<void> _handleCompatibility(String me, String otherId) async {
    final myRef = _db.collection('users').doc(me).collection('matches').doc(otherId);
    final otherRef = _db.collection('users').doc(otherId).collection('matches').doc(me);

    final mySnap = await myRef.get();
    final otherSnap = await otherRef.get();

    // 1 — They already sent us a request → Auto connect
    if (mySnap.exists && mySnap.data()?['status'] == 'incoming') {
      await acceptIncomingRequest(otherId);
      return;
    }

    // 2 — If ANY existing status → skip duplicates
    if (mySnap.exists) {
      final s = mySnap.data()?['status'];
      if (s == 'pending' || s == 'incoming' || s == 'connected' || s == 'abandoned') {
        return;
      }
    }

    // 3 — Random initiator coin flip
    final coin = Random().nextBool();

    if (coin) {
      await sendMatchRequest(otherId);
    } else {
      return; // other user will initiate later
    }
  }

  // ============================================================
  // 🔥 SIMILARITY CALCULATION
  // ============================================================
  double _computeSimilarity(Map<String, dynamic> a, Map<String, dynamic> b) {
    int matches = 0;
    final keys = ['topArtist', 'topGenre', 'topMood', 'bpmRange', 'key'];

    for (var k in keys) {
      final va = (a[k] ?? '').toString().toLowerCase();
      final vb = (b[k] ?? '').toString().toLowerCase();
      if (va.isNotEmpty && va == vb) matches++;
    }

    return (matches / keys.length) * 100;
  }

  // ============================================================
  // 🔥 FETCH MATCHES FOR MATCH PAGE
  // ============================================================
  Future<List<Map<String, dynamic>>> getMatches() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return [];

    final snap = await _db
        .collection('users')
        .doc(me)
        .collection('matches')
        .orderBy('timestamp', descending: true)
        .get();

    List<Map<String, dynamic>> out = [];

    for (var doc in snap.docs) {
      final otherId = doc.id;
      final otherUser = await _db.collection('users').doc(otherId).get();

      out.add({
        'userId': otherId,
        'username': otherUser.data()?['username'] ?? 'Unknown',
        'photoUrl': otherUser.data()?['photoUrl'] ?? '',
        'status': doc['status'],
        'decision': doc['decision'],
        'reason': doc['reason'],
        'assignedRole': doc['assignedRole'],
        'timestamp': doc['timestamp'],
      });
    }

    return out;
  }
}
