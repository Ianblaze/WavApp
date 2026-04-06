// lib/onboarding/steps/photo_step.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../onboarding_controller.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('add a photo',
              style: TextStyle(fontFamily: 'Circular', fontSize: 26,
                  fontWeight: FontWeight.w800, color: Color(0xFF1A0D26),
                  letterSpacing: -.4)),
          const SizedBox(height: 4),
          const Text('helps others recognise you',
              style: TextStyle(fontFamily: 'Circular', fontSize: 14,
                  color: Color(0xFF8A7EA5))),
          const Spacer(),
          Center(
            child: GestureDetector(
              onTap: _uploading ? null : _pick,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.3),
                  border: Border.all(
                    color: ctrl.photoUrl != null
                        ? const Color(0xFFFF99CC)
                        : Colors.white.withOpacity(0.5),
                    width: ctrl.photoUrl != null ? 2.5 : 1.5,
                    style: ctrl.photoUrl != null
                        ? BorderStyle.solid
                        : BorderStyle.none,
                  ),
                  image: _previewBytes != null
                      ? DecorationImage(
                          image: MemoryImage(_previewBytes!),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: _previewBytes == null
                    ? _uploading
                        ? const CircularProgressIndicator(
                            color: Color(0xFFFF99CC), strokeWidth: 2)
                        : const Icon(Icons.add_a_photo_rounded,
                            size: 36, color: Color(0xFFFF99CC))
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _uploading
                  ? 'uploading...'
                  : ctrl.photoUrl != null
                      ? 'looking good!'
                      : 'tap to upload',
              style: TextStyle(
                fontFamily: 'Circular',
                fontSize: 13,
                color: ctrl.photoUrl != null
                    ? const Color(0xFF5DCAA5)
                    : const Color(0xFF8A7EA5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB3D9),
                foregroundColor: const Color(0xFF4B1528),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
                elevation: 0,
              ),
              onPressed: _uploading ? null : widget.onNext,
              child: Text(
                ctrl.photoUrl != null ? 'next →' : 'skip for now →',
                style: const TextStyle(fontFamily: 'Circular',
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
