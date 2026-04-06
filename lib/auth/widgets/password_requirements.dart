// lib/auth/widgets/password_requirements.dart
import 'package:flutter/material.dart';

class PasswordRequirements extends StatelessWidget {
  final String password;

  const PasswordRequirements({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Requirement('At least 8 characters', password.length >= 8),
        _Requirement('One uppercase letter',
            password.contains(RegExp(r'[A-Z]'))),
        _Requirement('One number', password.contains(RegExp(r'[0-9]'))),
        _Requirement('One special character',
            password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  final String label;
  final bool met;

  const _Requirement(this.label, this.met);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: met ? Colors.greenAccent : Colors.white54,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Circular',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: met ? Colors.greenAccent : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}
