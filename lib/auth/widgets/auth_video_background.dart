import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AuthVideoBackground extends StatefulWidget {
  final Widget child;
  final double overlayOpacity;
  final bool isPlaying;

  const AuthVideoBackground({
    super.key,
    required this.child,
    this.overlayOpacity = 0.4,
    this.isPlaying = true,
  });

  @override
  State<AuthVideoBackground> createState() => _AuthVideoBackgroundState();
}

class _AuthVideoBackgroundState extends State<AuthVideoBackground> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.asset('assets/images/splashbg.mp4');
    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _controller!.setLooping(true);
          _controller!.setVolume(0); // Ensure muted for backgrounds
          if (widget.isPlaying) {
            _controller!.play();
          }
        });
      }
    } catch (e) {
      debugPrint('Error initializing background video: $e');
    }
  }

  @override
  void didUpdateWidget(AuthVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying && _isInitialized) {
      if (widget.isPlaying) {
        _controller?.play();
      } else {
        _controller?.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lock background to full screen dimensions
    final mediaQuery = MediaQuery.of(context);
    final totalHeight = mediaQuery.size.height + mediaQuery.viewInsets.bottom;
    final totalWidth = mediaQuery.size.width;

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Static Placeholder / Fallback ──
          Positioned.fill(
            child: Image.asset(
              'assets/images/bgstatic.png',
              fit: BoxFit.cover,
            ),
          ),

          // ── Video Layer ──
          if (_isInitialized && _controller != null)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),

          // ── Dark Overlay ──
          Positioned.fill(
            child: ColoredBox(
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
