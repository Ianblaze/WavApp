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
          _controller!.setVolume(0);
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
    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── 1. Static Placeholder ──
          Positioned.fill(
            child: Image.asset(
              'assets/images/bgstatic.png',
              fit: BoxFit.cover,
            ),
          ),

          // ── 2. Isolated Video Layer ──
          // We isolate this to prevent rebuilds from the input fields affecting video performance.
          if (_isInitialized && _controller != null)
            _VideoLayer(controller: _controller!),

          // ── 3. Dark Overlay ──
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withOpacity(widget.overlayOpacity),
            ),
          ),

          // ── 4. Loading Shimmer ──
          if (!_isInitialized)
            const Positioned.fill(
              child: _LoadingShimmer(),
            ),

          // ── 5. Content ──
          // Use a RepaintBoundary here too to isolate UI repaints from the background.
          RepaintBoundary(child: widget.child),
        ],
      ),
    );
  }
}

class _VideoLayer extends StatelessWidget {
  final VideoPlayerController controller;
  const _VideoLayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    // Isolated repaint boundary for the video texture itself.
    return Positioned.fill(
      child: RepaintBoundary(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}

class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();
  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, child) {
        final progress = _shimmerCtrl.value;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + 2.0 * progress, -0.3),
              end: Alignment(-0.5 + 2.0 * progress, 0.3),
              colors: [
                Colors.white.withOpacity(0.0),
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: Container(
            color: Colors.white.withOpacity(0.03),
          ),
        );
      },
    );
  }
}

