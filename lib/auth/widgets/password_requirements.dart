// lib/auth/widgets/password_requirements.dart
import 'package:flutter/material.dart';

class PasswordRequirements extends StatelessWidget {
  final String password;

  const PasswordRequirements({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Requirement(
          'At least 8 characters',
          password.length >= 8,
          progress: (password.length / 8).clamp(0.0, 1.0),
        ),
        _Requirement('One uppercase letter', password.contains(RegExp(r'[A-Z]'))),
        _Requirement('One number', password.contains(RegExp(r'[0-9]'))),
        _Requirement(
          'One special character',
          password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
        ),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  final String label;
  final bool met;
  final double? progress;

  const _Requirement(this.label, this.met, {this.progress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (progress != null && !met)
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return CircularProgressIndicator(
                        value: value,
                        strokeWidth: 2,
                        color: const Color(0xFF4ADE80).withOpacity(0.5),
                        backgroundColor: Colors.white10,
                      );
                    },
                  ),
                Icon(
                  met ? Icons.check_circle_rounded : (progress != null ? null : Icons.radio_button_unchecked_rounded),
                  color: met ? const Color(0xFF4ADE80) : Colors.white24,
                  size: met ? 16 : 14,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Circular',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: met ? const Color(0xFF4ADE80) : Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

