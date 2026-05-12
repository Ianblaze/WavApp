import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AuthVideoBackground extends StatefulWidget {
  final Widget child;
  final double overlayOpacity;

  const AuthVideoBackground({
    super.key,
    required this.child,
    this.overlayOpacity = 0.4,
  });

  @override
  State<AuthVideoBackground> createState() => _AuthVideoBackgroundState();
}

class _AuthVideoBackgroundState extends State<AuthVideoBackground> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Using bg2 (splashbg.mp4) as requested for the sub-screens
    _controller = VideoPlayerController.asset('assets/images/splashbg.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _controller.setLooping(true);
          _controller.play();
          _controller.setVolume(0); // Ensure silent
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final totalHeight = mediaQuery.size.height + mediaQuery.viewInsets.bottom;
    final totalWidth = mediaQuery.size.width;

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Video Background layer ──
          Positioned(
            top: 0,
            left: 0,
            width: totalWidth,
            height: totalHeight,
            child: _isInitialized
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  )
                : Image.asset(
                    'assets/images/bgstatic.png',
                    fit: BoxFit.cover,
                  ),
          ),

          // ── Overlay (Uniform, no top-clipping gradients) ──
          Positioned(
            top: 0,
            left: 0,
            width: totalWidth,
            height: totalHeight,
            child: Container(
              color: Colors.black.withOpacity(widget.overlayOpacity),
            ),
          ),

          // ── Content ──
          widget.child,
        ],
      ),
    );
  }
}
