// lib/providers/match_provider.dart
//
// Single source of truth for match state and real-time notifications.
// Uses a subtle toast instead of a full popup (industry standard).

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/match.dart';
import '../services/matching_engine.dart';

class MatchProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MatchingEngine _engine = MatchingEngine();

  List<Match> _matches = [];
  bool _isLoading = false;
  String? _error;
  int _pendingCount = 0;

  List<Match> get matches => _matches;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get pendingCount => _pendingCount;

  StreamSubscription<QuerySnapshot>? _matchStream;
  StreamSubscription<QuerySnapshot>? _notificationStream;
  BuildContext? _notificationContext;
  final Set<String> _processedMatches = {};

  // Callback to switch to Matches tab (set by HomePage)
  VoidCallback? onNavigateToMatches;

  // ── Match stream (populates the Matches tab) ─────────────────
  void startMatchStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    _matchStream?.cancel();
    _matchStream = _db
        .collection('users').doc(uid).collection('matches')
        // Removing orderBy to avoid index-related permission issues for now
        .snapshots()
        .listen((snap) async {
      final List<Match> resolved = [];
      int pending = 0;
      for (var doc in snap.docs) {
        final data = doc.data();
        final otherId = doc.id;
        
        try {
          final otherDoc = await _db.collection('users').doc(otherId).get();
          final otherData = otherDoc.data() ?? {};

          final match = Match.fromFirestore(
            odocId: otherId,
            matchData: data,
            otherUserData: otherData,
          );
          resolved.add(match);
          if (match.status == 'incoming') pending++;
        } catch (e) {
          debugPrint('⚠️ MatchProvider: Failed to load profile for $otherId: $e');
        }
      }

      // Sort locally since we removed server-side orderBy
      resolved.sort((a, b) {
        final ta = a.matchedAt?.millisecondsSinceEpoch ?? 0;
        final tb = b.matchedAt?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });

      _matches = resolved;
      _pendingCount = pending;
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (e) {
      debugPrint('❌ MatchProvider stream error: $e');
      if (e.toString().contains('permission-denied')) {
        // Retry once after a delay to handle race condition with user doc creation
        Future.delayed(const Duration(seconds: 2), () => startMatchStream());
      } else {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  // ── Real-time notification listener (toast style) ────────────
  void startNotificationListener(BuildContext context) {
    _notificationContext = context;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    debugPrint('🔔 MatchProvider: Starting notification listener for $uid');

    _notificationStream = _db
        .collection('users').doc(uid).collection('matches')
        .where('status', isEqualTo: 'incoming')
        .snapshots()
        .listen((snap) {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final matchId = change.doc.id;
          if (_processedMatches.contains(matchId)) continue;
          _processedMatches.add(matchId);
          debugPrint('🎵 New incoming match: $matchId');
          _showMatchToast(change.doc);
        }
      }
    });
  }

  /// Show a minimal snackbar notification.
  Future<void> _showMatchToast(DocumentSnapshot matchDoc) async {
    if (_notificationContext == null || !_notificationContext!.mounted) return;
    try {
      final matchData = matchDoc.data() as Map<String, dynamic>? ?? {};

      final otherDoc = await _db.collection('users').doc(matchDoc.id).get();
      final otherData = otherDoc.data() ?? {};

      final username = otherData['username'] ?? 'Someone';
      final score = (matchData['similarityScore'] as num?)?.toDouble() ?? 0;
      final sharedGenres = List<String>.from(matchData['sharedGenres'] ?? []);

      // Build display text
      String detail = '';
      if (score > 0) detail = '${score.toStringAsFixed(0)}%';
      if (sharedGenres.isNotEmpty) {
        final genreText = sharedGenres.take(2).join(', ');
        detail = detail.isNotEmpty ? '$detail · $genreText' : genreText;
      }

      if (_notificationContext != null && _notificationContext!.mounted) {
        ScaffoldMessenger.of(_notificationContext!).showSnackBar(
          SnackBar(
            content: Text(
              detail.isNotEmpty
                  ? '🎵 New match with $username — $detail'
                  : '🎵 New match with $username',
              style: const TextStyle(
                fontFamily: 'Circular',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            backgroundColor: const Color(0xFF1E1E2A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View',
              textColor: const Color(0xFFFF6FE8),
              onPressed: () => onNavigateToMatches?.call(),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error showing match toast: $e');
    }
  }

  // ── Actions ──────────────────────────────────────────────────
  Future<void> acceptMatch(String otherUserId) async {
    await _engine.acceptMatch(otherUserId);
  }

  Future<void> declineMatch(String otherUserId, String? reason) async {
    await _engine.declineMatch(otherUserId, reason);
  }

  // ── Cleanup ──────────────────────────────────────────────────
  void stopNotificationListener() {
    _notificationStream?.cancel();
    _notificationStream = null;
    _notificationContext = null;
    _processedMatches.clear();
  }

  @override
  void dispose() {
    _matchStream?.cancel();
    _notificationStream?.cancel();
    super.dispose();
  }
}

