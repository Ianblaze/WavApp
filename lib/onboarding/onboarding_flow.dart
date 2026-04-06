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

    final grads = _bgGradients[ctrl.step.clamp(0, 2)];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: grads,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar: back + progress
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
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
              const SizedBox(height: 4),
              // Step label
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'step ${ctrl.step + 1} of 3',
                      style: const TextStyle(
                        fontFamily: 'Circular',
                        fontSize: 11,
                        color: Color(0xFF8A7EA5),
                      ),
                    ),
                    if (ctrl.step == 0)
                      GestureDetector(
                        onTap: () {
                          context.read<OnboardingController>().nextStep();
                          _goTo(1);
                        },
                        child: const Text(
                          'skip',
                          style: TextStyle(
                            fontFamily: 'Circular',
                            fontSize: 11,
                            color: Color(0xFFB69CFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Page content
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(), // controlled programmatically
                  children: [
                    PhotoStep(onNext: () { context.read<OnboardingController>().nextStep(); _goTo(1); }),
                    GenreStep(onNext: () { context.read<OnboardingController>().nextStep(); _goTo(2); }),
                    ArtistStep(onNext: () { context.read<OnboardingController>().nextStep(); }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
