import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

class UserProfileProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserProfile? _profile;
  StreamSubscription<DocumentSnapshot>? _profileStream;

  UserProfile? get profile => _profile;

  void startListening(String uid) {
    _profileStream?.cancel();
    _profileStream = _db.collection('users').doc(uid)
        .snapshots()
        .listen((doc) async {
      if (!doc.exists) {
        if (_profile != null) {
          // Doc was deleted AFTER profile was loaded = ban or admin action
          if (kDebugMode) debugPrint('User doc deleted mid-session — signing out');
          await FirebaseAuth.instance.signOut();
        } else {
          // Doc missing on first load = network dropout recovery path
          await _ensureUserDoc(uid);
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      // Check for explicit ban flag
      final isBanned = data['banned'] as bool? ?? false;
      if (isBanned) {
        if (kDebugMode) debugPrint('User is banned — signing out');
        await FirebaseAuth.instance.signOut();
        return;
      }

      _profile = UserProfile.fromDoc(doc);
      notifyListeners();
    });
  }

  /// Creates a minimal user doc if one doesn't exist.
  /// This is a recovery path — normal signup creates the doc atomically.
  Future<void> _ensureUserDoc(String uid) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    try {
      final docRef = _db.collection('users').doc(uid);
      // Double-check inside the write — another device may have created it
      await _db.runTransaction((txn) async {
        final snap = await txn.get(docRef);
        if (!snap.exists) {
          txn.set(docRef, {
            'uid': uid,
            'username': firebaseUser.displayName ?? '',
            'email': firebaseUser.email ?? '',
            'photoUrl': firebaseUser.photoURL ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'authProvider': firebaseUser.providerData.isNotEmpty
                ? firebaseUser.providerData.first.providerId
                : 'unknown',
            'passwordStrengthVerified': false,  // will trigger ReauthPasswordScreen if email user
          });
          if (kDebugMode) debugPrint('UserProfileProvider: created missing user doc for $uid');
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('UserProfileProvider: failed to create user doc: $e');
    }
  }

  void stopListening() {
    _profileStream?.cancel();
    _profileStream = null;
    _profile = null;
    notifyListeners();
  }

  Future<void> updateProfile({String? username, String? photoUrl}) async {
    if (_profile == null) return;
    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (updates.isEmpty) return;
    await _db.collection('users').doc(_profile!.uid).update(updates);
  }

  @override
  void dispose() {
    _profileStream?.cancel();
    super.dispose();
  }
}
