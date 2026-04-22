// lib/onboarding/steps/photo_step.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../onboarding_controller.dart';
import '../widgets/split_screen_shell.dart';

class PhotoStep extends StatefulWidget {
  final VoidCallback onNext;
  const PhotoStep({super.key, required this.onNext});

  @override
  State<PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends State<PhotoStep> {
  final _picker = ImagePicker();
  bool _uploading = false;
  Uint8List? _previewBytes;

  Future<void> _pick() async {
    final img = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;

    setState(() => _uploading = true);
    final bytes = await img.readAsBytes();
    setState(() => _previewBytes = bytes);

    final ctrl = context.read<OnboardingController>();
    if (kIsWeb) {
      await ctrl.uploadPhoto(bytes);
    } else {
      // ignore: avoid_dynamic_calls
      await ctrl.uploadPhoto(img);
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<OnboardingController>();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = MediaQuery.of(context).size.width;
        final h = MediaQuery.of(context).size.height;
        final avatarSize = (w * 0.35).clamp(100.0, 160.0);
        final iconSize = avatarSize * 0.3;

        return SplitScreenShell(
          topGradient: const [Color(0xFFFFD4FF), Color(0xFFEDD4FF), Color(0xFFD4E4FF)],
          illustration: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: h * 0.02),
              Center(
                child: GestureDetector(
                  onTap: _uploading ? null : _pick,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: avatarSize, height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.35),
                      border: Border.all(
                        color: ctrl.photoUrl != null
                            ? const Color(0xFFFF99CC)
                            : Colors.white.withOpacity(0.5),
                        width: ctrl.photoUrl != null ? 3.0 : 1.5,
                      ),
                      image: _previewBytes != null
                          ? DecorationImage(
                              image: MemoryImage(_previewBytes!),
                              fit: BoxFit.cover)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: _previewBytes == null
                        ? _uploading
                            ? Center(
                                child: SizedBox(
                                  width: avatarSize * 0.25,
                                  height: avatarSize * 0.25,
                                  child: const CircularProgressIndicator(
                                    color: Color(0xFFFF99CC),
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              )
                            : Icon(Icons.add_a_photo_rounded,
                                size: iconSize, color: const Color(0xFFFF99CC))
                        : null,
                  ),
                ),
              ),
              SizedBox(height: h * 0.03),
              Text(
                _uploading
                    ? 'uploading...'
                    : ctrl.photoUrl != null
                        ? 'looking good!'
                        : 'tap to upload',
                style: TextStyle(
                  fontFamily: 'Circular',
                  fontSize: (w * 0.038).clamp(12.0, 15.0),
                  color: ctrl.photoUrl != null
                      ? const Color(0xFF5DCAA5)
                      : const Color(0xFF8A7EA5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          title: 'Add a photo',
          subtitle: 'Helps others recognise you. You can always add one later.',
          cta: SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB3D9),
                foregroundColor: const Color(0xFF4B1528),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              onPressed: _uploading ? null : widget.onNext,
              child: Text(
                ctrl.photoUrl != null ? 'next →' : 'skip for now →',
                style: const TextStyle(
                  fontFamily: 'Circular',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}
