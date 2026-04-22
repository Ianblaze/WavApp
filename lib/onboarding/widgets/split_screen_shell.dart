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
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalH = constraints.maxHeight;
          final totalW = constraints.maxWidth;
          final splitY = totalH * (topFlex / (topFlex + bottomFlex));
          final illustrationMaxH = (totalH * 0.32).clamp(160.0, 320.0);
          final titleFont = (totalW * 0.095).clamp(26.0, 40.0);
          final subtitleFont = (totalW * 0.042).clamp(14.0, 18.0);
          final hPad = (totalW * 0.065).clamp(18.0, 26.0);

          return Stack(
            children: [
              Column(
                children: [
                  // 1. Top Illustration Area
                  Expanded(
                    flex: topFlex,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: topGradient,
                        ),
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
                  
                  // 2. Bottom Content Area (Pure White)
                  Expanded(
                    flex: bottomFlex,
                    child: Container(
                      width: double.infinity,
                      color: Colors.white,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(hPad, totalH * 0.025, hPad, totalH * 0.02),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontFamily: 'Circular',
                                    fontSize: titleFont,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F0B1A),
                                    letterSpacing: -1.2,
                                    height: 1.05,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 3,
                                ),
                              ),
                              SizedBox(height: totalH * 0.012),
                              Flexible(
                                child: Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontFamily: 'Circular',
                                    fontSize: subtitleFont,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF0F0B1A).withOpacity(0.7),
                                    height: 1.45,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 3,
                                ),
                              ),
                              if (extras != null) ...[
                                SizedBox(height: totalH * 0.02),
                                extras!,
                              ],
                              const Spacer(),
                              cta,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 3. Elegant Subtle Spill Bleed
              Positioned(
                left: 0,
                right: 0,
                top: splitY - 1,
                height: 140, // Taller, even softer spill
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          topGradient.last.withOpacity(0.65),
                          topGradient.last.withOpacity(0.0),
                        ],
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
