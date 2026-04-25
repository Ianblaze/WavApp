import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../auth/utils/auth_exception.dart';

const _y2kPink      = Color(0xFFFF6FE8);
const _y2kPurple    = Color(0xFFB69CFF);
const _textPrimary  = Color(0xFF3A2A45);
const _textMuted    = Color(0xFF8A7EA5);
const _hotPink      = Color(0xFFFF2D8A);

class ProfileSetupDialog extends StatefulWidget {
  const ProfileSetupDialog({super.key});

  @override
  State<ProfileSetupDialog> createState() => _ProfileSetupDialogState();
}

class _ProfileSetupDialogState extends State<ProfileSetupDialog> {
  final TextEditingController _usernameCtrl = TextEditingController();
  XFile? _pickedImage;
  Uint8List? _webImageBytes;
  bool _loading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = context.read<UserProfileProvider>().profile;
      if (profile != null) {
        _usernameCtrl.text = profile.username;
      }
    });
  }

  Future<void> pickImage() async {
    final img = await _picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      if (kIsWeb) {
        _webImageBytes = await img.readAsBytes();
      }
      setState(() => _pickedImage = img);
    }
  }

  Future<String?> _uploadImage() async {
    if (_pickedImage == null) return null;
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final storageRef = FirebaseStorage.instance.ref().child("user_photos/$uid.jpg");
      if (kIsWeb) {
        await storageRef.putData(_webImageBytes!, SettableMetadata(contentType: "image/jpeg"));
      } else {
        await storageRef.putFile(File(_pickedImage!.path));
      }
      return await storageRef.getDownloadURL();
    } catch (e) {
      debugPrint("UPLOAD ERROR: $e");
      return null;
    }
  }

  Future<void> saveProfile() async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a username", style: TextStyle(fontFamily: 'Circular')), backgroundColor: _hotPink),
      );
      return;
    }

    setState(() => _loading = true);
    final photoUrl = await _uploadImage();

    if (_pickedImage != null && photoUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Upload failed. Try again.", style: TextStyle(fontFamily: 'Circular')), backgroundColor: _hotPink),
        );
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final auth = context.read<AuthProvider>();
      await auth.updateUsername(username, extraUpdates: {
        if (photoUrl != null) "photoUrl": photoUrl,
      });
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message, style: const TextStyle(fontFamily: 'Circular')), backgroundColor: _hotPink),
        );
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An error occurred", style: TextStyle(fontFamily: 'Circular')), backgroundColor: _hotPink),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFFF0F8),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _y2kPink.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Edit Profile",
              style: TextStyle(
                fontFamily: 'Circular',
                color: _textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),

            // Profile Image Picker
            GestureDetector(
              onTap: pickImage,
              child: Stack(
                children: [
                  Container(
                    width: 100, height: 100,
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_y2kPink, _y2kPurple],
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        image: _pickedImage == null
                            ? null
                            : kIsWeb
                                ? DecorationImage(image: MemoryImage(_webImageBytes!), fit: BoxFit.cover)
                                : DecorationImage(image: FileImage(File(_pickedImage!.path)), fit: BoxFit.cover),
                      ),
                      child: _pickedImage == null
                          ? Icon(Icons.add_a_photo_rounded, size: 28, color: _y2kPurple.withOpacity(0.6))
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded, size: 16, color: _textPrimary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: _usernameCtrl,
              style: const TextStyle(fontFamily: 'Circular', color: _textPrimary, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.6),
                hintText: "Username",
                hintStyle: TextStyle(fontFamily: 'Circular', color: _textMuted.withOpacity(0.4)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hotPink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Save Changes", style: TextStyle(fontFamily: 'Circular', fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
