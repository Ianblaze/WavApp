import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileSetupDialog extends StatefulWidget {
  const ProfileSetupDialog({super.key});

  @override
  State<ProfileSetupDialog> createState() => _ProfileSetupDialogState();
}

class _ProfileSetupDialogState extends State<ProfileSetupDialog> {
  final TextEditingController _usernameCtrl = TextEditingController();
  XFile? _pickedImage;
  Uint8List? _webImageBytes; // <-- FIX FOR WEB
  bool _loading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> pickImage() async {
    final img = await _picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      if (kIsWeb) {
        // read bytes for web preview
        _webImageBytes = await img.readAsBytes();
      }

      setState(() => _pickedImage = img);
    }
  }

  // Upload image function for Web + Mobile
  Future<String?> _uploadImage() async {
    if (_pickedImage == null) return null;

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final storageRef =
          FirebaseStorage.instance.ref().child("user_photos/$uid.jpg");

      if (kIsWeb) {
        // WEB
        await storageRef.putData(
          _webImageBytes!,
          SettableMetadata(contentType: "image/jpeg"),
        );
      } else {
        // ANDROID / iOS
        await storageRef.putFile(File(_pickedImage!.path));
      }

      return await storageRef.getDownloadURL();
    } catch (e) {
      debugPrint("UPLOAD ERROR: $e");
      return null;
    }
  }

  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final username = _usernameCtrl.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a username")),
      );
      return;
    }

    setState(() => _loading = true);

    // Upload image
    final photoUrl = await _uploadImage();

    if (_pickedImage != null && photoUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Image upload failed. Try again."),
              backgroundColor: Colors.red),
        );
        setState(() => _loading = false);
      }
      return;
    }

    await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
      "username": username,
      "photoUrl": photoUrl ?? "",
      "likedSongs": [],
      "recentMatches": [],
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF121212),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Set up your profile",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // FIXED WEB / MOBILE PROFILE PREVIEW
            GestureDetector(
              onTap: pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF1F1F1F),
                backgroundImage: _pickedImage == null
                    ? null
                    : kIsWeb
                        ? MemoryImage(_webImageBytes!)
                        : FileImage(File(_pickedImage!.path)),
                child: _pickedImage == null
                    ? const Icon(Icons.camera_alt,
                        size: 32, color: Colors.white70)
                    : null,
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _usernameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                hintText: "Username",
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: _loading ? null : saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.black),
                      )
                    : const Text("Save",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
