// lib/onboarding/onboarding_flow.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'onboarding_controller.dart';
import 'steps/photo_step.dart';
import 'steps/genre_step.dart';
import 'steps/artist_step.dart';
import 'done_screen.dart';
import 'widgets/progress_worm.dart';

// Y2K palette — same as rest of auth
const _bgGradients = [
  [Color(0xFFFFD4FF), Color(0xFFEDD4FF)],  // step 0 — pink/lavender
  [Color(0xFFEDD4FF), Color(0xFFD4E4FF)],  // step 1 — lavender/blue
  [Color(0xFFD4E4FF), Color(0xFFEDD4FF)],  // step 2 — blue/lavender
];

class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OnboardingController(),
      child: const _OnboardingShell(),
    );
  }
}

class _OnboardingShell extends StatefulWidget {
  const _OnboardingShell();

  @override
  State<_OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends State<_OnboardingShell> {
  final _pageCtrl = PageController();

  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  void _goTo(int step) {
    _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<OnboardingController>();

    // Once done, show done screen
    if (ctrl.step >= 3) {
      return const DoneScreen();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // The individual steps with their own SplitScreenShell layouts
          PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              PhotoStep(onNext: () {
                context.read<OnboardingController>().nextStep();
                _goTo(1);
              }),
              GenreStep(onNext: () {
                context.read<OnboardingController>().nextStep();
                _goTo(2);
              }),
              ArtistStep(onNext: () {
                context.read<OnboardingController>().nextStep();
              }),
            ],
          ),

          // Shared minimal header overlay (Back button and Progress)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
              child: Row(
                children: [
                  if (ctrl.step > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF1A0D26), size: 20),
                      onPressed: () {
                        context.read<OnboardingController>().prevStep();
                        _goTo(ctrl.step - 1);
                      },
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: ProgressWorm(
                      currentStep: ctrl.step,
                      totalSteps: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
