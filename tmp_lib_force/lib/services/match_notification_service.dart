// lib/services/match_notification_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import your match_dock_popup - adjust the path based on your project structure
// If it's in lib/widgets/match_dock_popup.dart use:
import '../pages/match_dock_popup.dart';
// If it's in lib/pages/match_dock_popup.dart use:
// import '../pages/match_dock_popup.dart';

class MatchNotificationService {
  // Singleton pattern - only one instance exists
  static final MatchNotificationService _instance = MatchNotificationService._internal();
  factory MatchNotificationService() => _instance;
  MatchNotificationService._internal();

  final _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _matchListener;
  BuildContext? _context;
  Set<String> _processedMatches = {}; // Prevent duplicate notifications

  /// Initialize the listener with app context
  void initialize(BuildContext context) {
    _context = context;
    _startListening();
  }

  /// Clean up when app closes
  void dispose() {
    _matchListener?.cancel();
    _matchListener = null;
    _context = null;
    _processedMatches.clear();
  }

  void _startListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ No user logged in, skipping match listener');
      return;
    }

    debugPrint('🔥 Starting match notification listener for user: ${user.uid}');

    _matchListener = _db
        .collection('users')
        .doc(user.uid)
        .collection('matches')
        .where('status', isEqualTo: 'incoming')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final matchId = change.doc.id;
          
          // Prevent duplicate notifications for the same match
          if (_processedMatches.contains(matchId)) continue;
          _processedMatches.add(matchId);
          
          debugPrint('🎵 New incoming match detected: $matchId');
          _showNotificationForMatch(change.doc);
        }
      }
    }, onError: (error) {
      debugPrint('❌ Match listener error: $error');
    });
  }

  Future<void> _showNotificationForMatch(DocumentSnapshot matchDoc) async {
    if (_context == null || !_context!.mounted) {
      debugPrint('⚠️ Context not available for notification');
      return;
    }

    try {
      final otherId = matchDoc.id;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch other user's data
      final otherUserDoc = await _db.collection('users').doc(otherId).get();
      if (!otherUserDoc.exists) {
        debugPrint('⚠️ Other user not found: $otherId');
        return;
      }

      final otherData = otherUserDoc.data() ?? {};
      final username = otherData['username'] ?? 'Unknown User';
      final photoUrl = otherData['photoUrl'] ?? '';

      // Calculate similarity
      final myDoc = await _db.collection('users').doc(user.uid).get();
      final myProfile = (myDoc.data()?['tasteProfile'] as Map<String, dynamic>?) ?? {};
      final otherProfile = (otherData['tasteProfile'] as Map<String, dynamic>?) ?? {};
      
      final similarity = _computeSimilarity(myProfile, otherProfile);

      debugPrint('🎉 Showing match popup for: $username (${similarity.toStringAsFixed(0)}%)');

      // Show the popup
      if (_context != null && _context!.mounted) {
        Navigator.of(_context!).push(
          PageRouteBuilder(
            opaque: false,
            barrierDismissible: false,
            pageBuilder: (ctx, anim, secondAnim) => MatchDockPopup(
              username: username,
              photoUrl: photoUrl,
              similarity: similarity.toStringAsFixed(0),
              onConnect: () async {
                Navigator.pop(ctx);
                await _acceptMatch(otherId);
              },
              onAbandon: (reason) async {
                Navigator.pop(ctx);
                await _abandonMatch(otherId, reason);
              },
              onDismiss: () {
                Navigator.pop(ctx);
              },
            ),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('❌ Error showing match notification: $e\n$st');
    }
  }

  Future<void> _acceptMatch(String otherId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final myRef = _db.collection('users').doc(user.uid).collection('matches').doc(otherId);
      final otherRef = _db.collection('users').doc(otherId).collection('matches').doc(user.uid);

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
      debugPrint('✅ Match accepted: $otherId');
    } catch (e) {
      debugPrint('❌ Error accepting match: $e');
    }
  }

  Future<void> _abandonMatch(String otherId, String? reason) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final myRef = _db.collection('users').doc(user.uid).collection('matches').doc(otherId);
      final otherRef = _db.collection('users').doc(otherId).collection('matches').doc(user.uid);

      final batch = _db.batch();

      batch.update(myRef, {
        'status': 'abandoned',
        'decision': 'abandon',
        'reason': reason ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      batch.update(otherRef, {
        'status': 'abandoned',
        'decision': 'abandon_by_other',
        'reason': reason ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('✅ Match abandoned: $otherId');
    } catch (e) {
      debugPrint('❌ Error abandoning match: $e');
    }
  }

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

  /// Restart listener (useful after login/logout)
  void restart(BuildContext context) {
    dispose();
    initialize(context);
  }
}