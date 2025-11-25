import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Google Sign-In object with Web clientId included
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    clientId: kIsWeb
        ? "473711579608-up2ti7fp7rm5r91e00l2sd9tb14s2uif.apps.googleusercontent.com"
        : null,
  );

  // ----------------------------
  // CURRENT USER
  // ----------------------------
  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ----------------------------
  // GOOGLE SIGN-IN
  // ----------------------------
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final UserCredential result =
          await _auth.signInWithCredential(credential);

      final user = result.user;

      if (user != null) {
        await _saveUserToFirestore(user);
      }

      return user;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      rethrow;
    }
  }

  // ----------------------------
  // EMAIL SIGN-UP
  // ----------------------------
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;

      if (user != null) {
        await user.updateDisplayName(name);
        await user.reload();

        await _db.collection("users").doc(user.uid).set({
          "name": name,
          "email": email,
          "createdAt": FieldValue.serverTimestamp(),
          "authProvider": "email",
        });
      }

      return user;
    } catch (e) {
      debugPrint("Email Signup Error: $e");
      rethrow;
    }
  }

  // ----------------------------
  // EMAIL LOGIN
  // ----------------------------
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result =
          await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } catch (e) {
      debugPrint("Email Login Error: $e");
      rethrow;
    }
  }

  // ----------------------------
  // RESET PASSWORD
  // ----------------------------
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ----------------------------
  // FIRESTORE USER SAVE
  // ----------------------------
  Future<void> _saveUserToFirestore(User user) async {
    final doc = await _db.collection("users").doc(user.uid).get();

    if (!doc.exists) {
      await _db.collection("users").doc(user.uid).set({
        "name": user.displayName ?? "",
        "email": user.email ?? "",
        "photoUrl": user.photoURL ?? "",
        "createdAt": FieldValue.serverTimestamp(),
        "authProvider": "google",
      });
    } else {
      await _db.collection("users").doc(user.uid).update({
        "lastLogin": FieldValue.serverTimestamp(),
      });
    }
  }

  // ----------------------------
  // LOGOUT
  // ----------------------------
  Future<void> signOut() async {
    if (await _googleSignIn.isSignedIn()) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }
}

/// ########################################################################
/// ###################### PHONE AUTH SERVICE ##############################
/// ########################################################################

/// ########################################################################
/// ###################### PHONE AUTH SERVICE ##############################
/// ########################################################################

class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? verificationId;

  // ----------------------------
  // SEND OTP
  // ----------------------------
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      // Ensure phone number has country code
      String formattedPhone = phoneNumber;
      if (!phoneNumber.startsWith('+')) {
        // Default to +91 for India, change as needed
        formattedPhone = '+91$phoneNumber';
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),

        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final result = await _auth.signInWithCredential(credential);
            if (result.user != null) {
              await _saveUserToFirestore(result.user!);
            }
          } catch (e) {
            debugPrint("Auto verification error: $e");
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          debugPrint("Verification failed: ${e.code} - ${e.message}");
          onError(e.message ?? "Phone verification failed");
        },

        codeSent: (String verId, int? resendToken) {
          verificationId = verId;
          debugPrint("Code sent! Verification ID: $verId");
          onCodeSent(verId);
        },

        codeAutoRetrievalTimeout: (String verId) {
          verificationId = verId;
          debugPrint("Auto retrieval timeout: $verId");
        },
      );
    } catch (e) {
      debugPrint("Send OTP error: $e");
      onError(e.toString());
    }
  }

  // ----------------------------
  // VERIFY OTP
  // ----------------------------
  Future<User?> verifyOtp({
    required String otp,
    required String verificationId, // Accept verificationId as parameter
    required Function(String error) onError,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      final result = await _auth.signInWithCredential(credential);
      
      if (result.user != null) {
        await _saveUserToFirestore(result.user!);
      }
      
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Verify OTP error: ${e.code} - ${e.message}");
      if (e.code == 'invalid-verification-code') {
        onError("Invalid OTP. Please try again.");
      } else {
        onError(e.message ?? "Invalid OTP");
      }
      return null;
    } catch (e) {
      debugPrint("Verify OTP general error: $e");
      onError("Invalid OTP");
      return null;
    }
  }

  // ----------------------------
  // SAVE USER TO FIRESTORE
  // ----------------------------
  Future<void> _saveUserToFirestore(User user) async {
    try {
      final doc = await _db.collection("users").doc(user.uid).get();

      if (!doc.exists) {
        await _db.collection("users").doc(user.uid).set({
          "name": user.displayName ?? "",
          "phoneNumber": user.phoneNumber ?? "",
          "createdAt": FieldValue.serverTimestamp(),
          "authProvider": "phone",
        });
      } else {
        await _db.collection("users").doc(user.uid).update({
          "lastLogin": FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Error saving user to Firestore: $e");
    }
  }
}