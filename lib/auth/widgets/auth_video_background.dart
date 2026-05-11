import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AuthVideoBackground extends StatefulWidget {
  final Widget child;
  final double overlayOpacity;

  const AuthVideoBackground({
    super.key,
    required this.child,
    this.overlayOpacity = 0.2,
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
    _controller = VideoPlayerController.asset('assets/images/splashbg.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.setLooping(true);
          _controller.setVolume(0);
          _controller.play();
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
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Video Layer ──
        if (_isInitialized)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          )
        else
          const SizedBox.expand(child: ColoredBox(color: Colors.white)),

        // ── Dark Overlay ──
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withOpacity(widget.overlayOpacity)),
        ),

        // ── Content ──
        widget.child,
      ],
    );
  }
}
