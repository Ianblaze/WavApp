import 'package:flutter/material.dart';

class MatchPopup extends StatefulWidget {
  final String username;
  final String? photoUrl;
  final VoidCallback onConnect;
  final VoidCallback onAbandon;
  final VoidCallback onDismiss;

  const MatchPopup({
    super.key,
    required this.username,
    required this.photoUrl,
    required this.onConnect,
    required this.onAbandon,
    required this.onDismiss,
  });

  @override
  State<MatchPopup> createState() => _MatchPopupState();
}

class _MatchPopupState extends State<MatchPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dim background that dismisses popup
        Positioned.fill(
          child: GestureDetector(
            onTap: _dismiss,
            child: Container(color: Colors.black38),
          ),
        ),

        // Slide-down notification card
        Positioned(
          top: 40,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _slideAnim,
            child: Center(
              child: Container(
                width: 330,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "🎵 New Match!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Profile Picture
                    CircleAvatar(
                      radius: 38,
                      backgroundImage: (widget.photoUrl != null &&
                              widget.photoUrl!.isNotEmpty)
                          ? NetworkImage(widget.photoUrl!)
                          : const AssetImage("assets/images/default_pfp.png")
                              as ImageProvider,
                    ),

                    const SizedBox(height: 10),

                    Text(
                      widget.username,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Connect / Abandon buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Abandon
                        IconButton(
                          iconSize: 30,
                          icon: const Icon(Icons.close, color: Colors.redAccent),
                          onPressed: () {
                            widget.onAbandon();
                            _dismiss();
                          },
                        ),

                        // Connect
                        IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.favorite,
                              color: Colors.greenAccent),
                          onPressed: () {
                            widget.onConnect();
                            _dismiss();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Dismiss
                    TextButton(
                      onPressed: _dismiss,
                      child: const Text(
                        "Dismiss",
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
