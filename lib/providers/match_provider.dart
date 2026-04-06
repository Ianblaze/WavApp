import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/match.dart';
import '../pages/match_dock_popup.dart';
import '../pages/match_service.dart';

class MatchProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Match> _matches = [];
  bool _isLoading = false;
  String? _error;

  List<Match> get matches => _matches;
  bool get isLoading => _isLoading;
  String? get error => _error;

  StreamSubscription<QuerySnapshot>? _matchStream;
  StreamSubscription<QuerySnapshot>? _notificationStream;
  BuildContext? _notificationContext;
  final Set<String> _processedMatches = {};

  void startMatchStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _isLoading = true;
    notifyListeners();
    _matchStream = _db
        .collection('users').doc(uid).collection('matches')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snap) async {
      final List<Match> resolved = [];
      for (var doc in snap.docs) {
        final data = doc.data();
        final otherId = doc.id;
        final otherDoc = await _db.collection('users').doc(otherId).get();
        final otherData = otherDoc.data() ?? {};
        resolved.add(Match(
          userId: otherId,
          username: otherData['username'] ?? 'Unknown',
          photoUrl: otherData['photoUrl'] ?? '',
          status: data['status'] ?? '',
          decision: data['decision'] ?? '',
          reason: data['reason'] ?? '',
          assignedRole: data['assignedRole'] ?? '',
          chatId: data['chatId'],
          docId: doc.id,
        ));
      }
      _matches = resolved;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  void startNotificationListener(BuildContext context) {
    _notificationContext = context;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
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
          _showMatchPopup(change.doc);
        }
      }
    });
  }

  Future<void> _showMatchPopup(DocumentSnapshot matchDoc) async {
    if (_notificationContext == null || !_notificationContext!.mounted) return;
    try {
      final otherId = matchDoc.id;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final otherDoc = await _db.collection('users').doc(otherId).get();
      final otherData = otherDoc.data() ?? {};
      final myDoc = await _db.collection('users').doc(uid).get();
      final myProfile = (myDoc.data()?['tasteProfile'] as Map<String, dynamic>?) ?? {};
      final otherProfile = (otherData['tasteProfile'] as Map<String, dynamic>?) ?? {};
      final similarity = MatchService.computeSimilarity(myProfile, otherProfile);
      if (_notificationContext != null && _notificationContext!.mounted) {
        Navigator.of(_notificationContext!).push(PageRouteBuilder(
          opaque: false,
          barrierDismissible: false,
          pageBuilder: (ctx, anim, _) => MatchDockPopup(
            username: otherData['username'] ?? 'Unknown',
            photoUrl: otherData['photoUrl'] ?? '',
            similarity: similarity.toStringAsFixed(0),
            onConnect: () async {
              Navigator.pop(ctx);
              await acceptMatch(otherId);
            },
            onAbandon: (reason) async {
              Navigator.pop(ctx);
              await declineMatch(otherId, reason);
            },
            onDismiss: () => Navigator.pop(ctx),
          ),
        ));
      }
    } catch (e, st) {
      debugPrint('Error showing match popup: $e\n$st');
    }
  }

  Future<void> acceptMatch(String otherUserId) async {
    await MatchService().acceptIncomingRequest(otherUserId);
  }

  Future<void> declineMatch(String otherUserId, String? reason) async {
    await MatchService().declineIncomingRequest(otherUserId, reason);
  }

  Future<void> sendMatchRequest(String otherUserId) async {
    await MatchService().sendMatchRequest(otherUserId);
  }

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
