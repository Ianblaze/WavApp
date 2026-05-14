import 'package:flutter/material.dart';

/// The shared visual shell for all intro and setup screens.
/// 
/// Top portion: full gradient, holds the illustration widget.
/// Bottom portion: lighter gradient, holds title/subtitle/CTA.
class SplitScreenShell extends StatelessWidget {
  final List<Color> topGradient;
  final Widget illustration;
  final String title;
  final String subtitle;
  final Widget cta;
  final Widget? extras;
  final int topFlex;
  final int bottomFlex;

  /// Optional override for the bottom gradient.
  final List<Color>? bottomGradient;

  const SplitScreenShell({
    super.key,
    required this.topGradient,
    required this.illustration,
    required this.title,
    required this.subtitle,
    required this.cta,
    this.extras,
    this.topFlex = 58,
    this.bottomFlex = 42,
    this.bottomGradient,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent, // Allow background to show through
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalH = constraints.maxHeight;
          final totalW = constraints.maxWidth;
          final illustrationMaxH = (totalH * 0.38).clamp(200.0, 360.0);
          final titleFont = (totalW * 0.085).clamp(24.0, 36.0);
          final subtitleFont = (totalW * 0.04).clamp(13.0, 16.0);
          final hPad = (totalW * 0.065).clamp(18.0, 26.0);

          return Column(
            children: [
              // 1. Top Illustration Area
              Expanded(
                flex: topFlex,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 10),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: illustrationMaxH),
                          child: illustration,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // 2. Bottom Content Area (Glassmorphic White)
              Expanded(
                flex: bottomFlex,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, totalH * 0.015),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontSize: titleFont,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -1.0,
                              height: 1.1,
                            ),
                            overflow: TextOverflow.visible,
                            maxLines: 3,
                          ),
                          SizedBox(height: totalH * 0.012),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontSize: subtitleFont,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.75),
                              height: 1.5,
                            ),
                            overflow: TextOverflow.visible,
                            maxLines: 3,
                          ),
                          if (extras != null) ...[
                            SizedBox(height: totalH * 0.02),
                            extras!,
                          ],
                          const SizedBox(height: 20),
                          cta,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ],
          );
        },
      ),
    );
  }
}

