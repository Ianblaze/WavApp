import os
import re

path = r'c:\Users\ian\Desktop\final_sem_proj\swipify\lib\pages\home_tab.dart'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Split text at MusicDNAVisualizer
parts = text.split('// 🧬 MUSIC DNA VISUALIZER')
if len(parts) == 1:
    parts = text.split('// 🧬 MUSIC DNA VISUAL')
if len(parts) < 2:
    print("Could not find MusicDNAVisualizer")
    exit(1)

head = parts[0]

# Now let's fix Head

head = re.sub(r'  // ── DNA Zoom State[\s\S]*?_DNAData _dnaData = _DNAData\.empty\(\);\n', r'  _DNAData _dnaData = _DNAData.empty();\n', head)
head = re.sub(r'    // Smooth cubic zoom — no jarring jump[\s\S]*?reverseCurve: Curves\.easeInCubic,\n    \);\n', '', head)
head = re.sub(r'    _zoomCtrl\.dispose\(\);\n', '', head)
head = re.sub(r'  void _toggleZoom\(\) \{[\s\S]*?\}\n  \}\n', '', head)

ui_find = r'          Positioned\.fill\([\s\S]*?Opacity\([\s\S]*?ChildListDelegate\(\[\n'
ui_repl = '''          Positioned.fill(
            child: MusicDNAVisualizer(
              scrollController: _scrollController,
              fillProgress:     (_totalLikedCount / 50).clamp(0.0, 1.0),
              dnaData:          _dnaData,
            ),
          ),
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
'''
head = re.sub(ui_find, ui_repl, head)

# Close parentheses for the CustomScrollView block correctly 
post_ui_find = r'                        \]\),\n                      \),\n                    \),\n                  \],\n                \),\n              \),\n            \),\n          \),[\s\S]*?if \(_isDNAMode\)[\s\S]*?_toggleZoom,\n              \),\n            \),\n'
post_ui_repl = '''                        ]),
                      ),
                    ),
                  ],
                ),
'''
head = re.sub(post_ui_find, post_ui_repl, head)


# The new Music DNA Visualizer
dna_code = '''// 🧬 MUSIC DNA VISUALIZER
// ═══════════════════════════════════════════════════════════════════
import 'dart:math' as math;
class MusicDNAVisualizer extends StatefulWidget {
  final ScrollController scrollController;
  final double fillProgress;
  final _DNAData dnaData;

  const MusicDNAVisualizer({
    super.key,
    required this.scrollController,
    required this.fillProgress,
    required this.dnaData,
  });

  @override
  State<MusicDNAVisualizer> createState() => _MusicDNAVisualizerState();
}

class _MusicDNAVisualizerState extends State<MusicDNAVisualizer> with SingleTickerProviderStateMixin {
  late final AnimationController _timeCtrl;

  @override
  void initState() {
    super.initState();
    _timeCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }

  @override
  void dispose() { _timeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_timeCtrl, widget.scrollController]),
      builder: (_, __) {
        return CustomPaint(
          size: Size.infinite,
          painter: _SimpleDNAPainter(
            time: _timeCtrl.value,
            scrollOffset: widget.scrollController.hasClients ? widget.scrollController.offset : 0.0,
            genre: widget.dnaData.topGenre,
          ),
        );
      },
    );
  }
}

class _SimpleDNAPainter extends CustomPainter {
  final double time;
  final double scrollOffset;
  final String genre;

  _SimpleDNAPainter({
    required this.time,
    required this.scrollOffset,
    required this.genre,
  });

  Color _genreColor(String genre) {
    switch (genre.toLowerCase()) {
      case 'pop': return const Color(0xFFFF6FE8);
      case 'rock': return const Color(0xFFFF6B2B);
      case 'hip hop': case 'rap': return const Color(0xFF4A90FF);
      case 'r&b': case 'soul': return const Color(0xFF9B59FF);
      case 'electronic': case 'edm': return const Color(0xFF00C9B1);
      case 'indie': case 'alternative': return const Color(0xFF3A6FFF);
      case 'classical': case 'jazz': return const Color(0xFFE8D05C);
      default:
        if (genre.isEmpty) return const Color(0xFFB69CFF);
        return Colors.primaries[genre.hashCode % Colors.primaries.length];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final wavelength = 180.0;
    final strandWidth = 40.0;
    final baseAngle = time * 2 * math.pi;
    final scrollPhase = -(scrollOffset * 0.0025);
    
    final mainColor = _genreColor(genre);

    final yStart = -wavelength;
    final yEnd = size.height + wavelength;
    final step = 8.0;

    final ptsA = <Offset>[];
    final ptsB = <Offset>[];
    final depA = <double>[];

    for (double y = yStart; y <= yEnd; y += step) {
      final angle = (y / wavelength) * 2 * math.pi + baseAngle + scrollPhase;
      ptsA.add(Offset(cx + math.sin(angle) * strandWidth, y));
      ptsB.add(Offset(cx + math.sin(angle + math.pi) * strandWidth, y));
      depA.add(math.cos(angle));
    }

    final paintRung = Paint()
      ..color = mainColor.withOpacity(0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < ptsA.length; i += 3) {
      canvas.drawLine(ptsA[i], ptsB[i], paintRung);
    }

    final paintA = Paint()
      ..color = mainColor.withOpacity(0.6)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
      
    final paintB = Paint()
      ..color = mainColor.withOpacity(0.3)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (depA.isNotEmpty && depA[depA.length ~/ 2] > 0) {
      _drawPath(canvas, ptsB, paintB);
      _drawPath(canvas, ptsA, paintA);
    } else {
      _drawPath(canvas, ptsA, paintA);
      _drawPath(canvas, ptsB, paintB);
    }
  }

  void _drawPath(Canvas canvas, List<Offset> pts, Paint paint) {
    if (pts.isEmpty) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SimpleDNAPainter old) =>
      old.time != time || old.scrollOffset != scrollOffset || old.genre != genre;
}
'''

new_text = head + dna_code

with open(path, 'w', encoding='utf-8') as f:
    f.write(new_text)
print("Done writing back!")
