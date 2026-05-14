import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AuthVideoBackground extends StatefulWidget {
  final Widget child;
  final double overlayOpacity;
  final bool isPlaying;
  final String videoPath;
  final String? secondaryVideoPath;
  final bool showSecondary;

  const AuthVideoBackground({
    super.key,
    required this.child,
    this.overlayOpacity = 0.4,
    this.isPlaying = true,
    this.videoPath = 'assets/images/splashbg.mp4',
    this.secondaryVideoPath,
    this.showSecondary = false,
  });

  @override
  State<AuthVideoBackground> createState() => _AuthVideoBackgroundState();
}

class _AuthVideoBackgroundState extends State<AuthVideoBackground> {
  VideoPlayerController? _controller;
  VideoPlayerController? _secondaryController;
  bool _isInitialized = false;
  bool _isSecondaryInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.asset(widget.videoPath);
    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _controller!.setLooping(true);
          _controller!.setVolume(0);
          if (widget.isPlaying && !widget.showSecondary) {
            _controller!.play();
          }
        });
      }
    } catch (e) {
      debugPrint('Error initializing primary video: $e');
    }

    if (widget.secondaryVideoPath != null) {
      _secondaryController = VideoPlayerController.asset(widget.secondaryVideoPath!);
      try {
        await _secondaryController!.initialize();
        if (mounted) {
          setState(() {
            _isSecondaryInitialized = true;
            _secondaryController!.setLooping(true);
            _secondaryController!.setVolume(0);
            if (widget.isPlaying && widget.showSecondary) {
              _secondaryController!.play();
            }
          });
        }
      } catch (e) {
        debugPrint('Error initializing secondary video: $e');
      }
    }
  }

  @override
  void didUpdateWidget(AuthVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle play/pause
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (widget.showSecondary) {
          _secondaryController?.play();
        } else {
          _controller?.play();
        }
      } else {
        _controller?.pause();
        _secondaryController?.pause();
      }
    }

    // Handle cross-fade video state
    if (widget.showSecondary != oldWidget.showSecondary && widget.isPlaying) {
      if (widget.showSecondary) {
        _secondaryController?.play();
        _controller?.pause();
      } else {
        _controller?.play();
        _secondaryController?.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _secondaryController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── 1. Static Placeholder ──
        const DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/bgstatic.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),

        // ── 2. Primary Video Layer ──
        if (_isInitialized && _controller != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: widget.showSecondary ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 800),
                child: _VideoLayer(controller: _controller!),
              ),
            ),
          ),

        // ── 3. Secondary Video Layer ──
        if (_isSecondaryInitialized && _secondaryController != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: widget.showSecondary ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 800),
                child: _VideoLayer(controller: _secondaryController!),
              ),
            ),
          ),

        // ── 4. Dark Overlay ──
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withOpacity(widget.overlayOpacity),
            ),
          ),
        ),

        // ── 5. Loading Shimmer ──
        if (!_isInitialized)
          const Positioned.fill(
            child: IgnorePointer(
              child: _LoadingShimmer(),
            ),
          ),

        // ── 6. Content ──
        widget.child,
      ],
    );
  }
}

class _VideoLayer extends StatelessWidget {
  final VideoPlayerController controller;
  const _VideoLayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    if (size.width == 0 || size.height == 0) {
      return const SizedBox.shrink();
    }

    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.center,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(controller),
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

