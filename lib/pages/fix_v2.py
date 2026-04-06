import os
import re

path = r'c:\Users\ian\Desktop\final_sem_proj\swipify\lib\pages\home_tab.dart'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

parts = text.split('// 🧬 MUSIC DNA VISUALIZER')
if len(parts) < 2:
    print("Error: Could not trace visualizer marker.")
    exit(1)

head = parts[0]

dna_code = '''// 🧬 MUSIC DNA VISUALIZER
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

class _Particle {
  final double x, yBase, speed, size;
  final Color color;
  _Particle(this.x, this.yBase, this.speed, this.size, this.color);
}

class _MusicDNAVisualizerState extends State<MusicDNAVisualizer> with SingleTickerProviderStateMixin {
  late final AnimationController _timeCtrl;
  late final List<_Particle> _particles;
  
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

  Color _moodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':       return const Color(0xFFFF6FE8);
      case 'energetic':   return const Color(0xFFFF6B2B);
      case 'chill':       return const Color(0xFF4A90FF);
      case 'melancholic': return const Color(0xFF9B59FF);
      case 'reflective':  return const Color(0xFF00C9B1);
      case 'sad':         return const Color(0xFF3A6FFF);
      default:            return const Color(0xFF7BA7FF); // fallback blue
    }
  }

  @override
  void initState() {
    super.initState();
    _timeCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    
    // Generate particles
    final rnd = math.Random(42);
    final cA = _genreColor(widget.dnaData.topGenre);
    final cB = _moodColor(widget.dnaData.topMood);
    
    _particles = List.generate(45, (i) {
      final isA = rnd.nextBool();
      return _Particle(
        rnd.nextDouble() * 400 - 200, // x offset from center
        rnd.nextDouble(),             // y normalized phase
        0.2 + rnd.nextDouble() * 0.5, // speed
        1.0 + rnd.nextDouble() * 2.5, // size
        (isA ? cA : cB).withOpacity(0.15 + rnd.nextDouble() * 0.3)
      );
    });
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
            colorA: _genreColor(widget.dnaData.topGenre),
            colorB: _moodColor(widget.dnaData.topMood),
            bpmRange: widget.dnaData.bpmRange,
            particles: _particles,
          ),
        );
      },
    );
  }
}

class _SimpleDNAPainter extends CustomPainter {
  final double time;
  final double scrollOffset;
  final Color colorA;
  final Color colorB;
  final String bpmRange;
  final List<_Particle> particles;

  _SimpleDNAPainter({
    required this.time,
    required this.scrollOffset,
    required this.colorA,
    required this.colorB,
    required this.bpmRange,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final wavelength = 180.0;
    final strandWidth = 40.0;
    
    // 2. Scroll-driven acceleration
    final baseAngle = time * 2 * math.pi;
    final scrollPhase = -(scrollOffset * 0.005); 
    
    // 3. Ambient BPM Breathing
    double bpm = 100.0;
    if (bpmRange.isNotEmpty) {
      final parts = bpmRange.replaceAll(RegExp(r'[^0-9-]'), '').split('-');
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        bpm = double.tryParse(parts[0]) ?? 100.0;
      }
    }
    final bps = bpm / 60.0;
    final pulse = 1.0 + 0.15 * math.sin(time * 12.0 * bps * 2 * math.pi);
    
    // 5. Ambient Dust Particles
    for (final p in particles) {
      final pY = (p.yBase - time * p.speed) % 1.0;
      final actY = pY * size.height;
      final actX = cx + p.x + math.sin(time * 4 * math.pi + p.x) * 15;
      
      final fade = math.sin(pY * math.pi);
      final pPaint = Paint()..color = p.color.withOpacity(p.color.opacity * fade);
      
      canvas.drawCircle(Offset(actX, actY), p.size * pulse, pPaint);
    }

    final yStart = -wavelength;
    final yEnd = size.height + wavelength;
    final step = 8.0;

    final ptsA = <Offset>[];
    final ptsB = <Offset>[];
    final depA = <double>[];
    final fades = <double>[];

    for (double y = yStart; y <= yEnd; y += step) {
      final angle = (y / wavelength) * 2 * math.pi + baseAngle + scrollPhase;
      ptsA.add(Offset(cx + math.sin(angle) * strandWidth * pulse, y));
      ptsB.add(Offset(cx + math.sin(angle + math.pi) * strandWidth * pulse, y));
      depA.add(math.cos(angle));
      
      // 4. Cinematic Fading
      final yNorm = (y / size.height).clamp(0.0, 1.0);
      fades.add(math.sin(yNorm * math.pi));
    }

    // Draw Strands
    for (int isA = 0; isA <= 1; isA++) {
      final aIsFront = depA.isNotEmpty && depA[depA.length ~/ 2] > 0;
      final drawA = (isA == 1) ? aIsFront : !aIsFront;
      
      final pts = drawA ? ptsA : ptsB;
      final color = drawA ? colorA : colorB;
      
      if (pts.isEmpty) continue;
      
      // Segment drawing
      for (int i = 0; i < pts.length - 1; i++) {
        final f = fades[i];
        if (f < 0.05) continue;
        
        final pColor = color.withOpacity((drawA ? 0.75 : 0.35) * f);
        final paint = Paint()
          ..color = pColor
          ..strokeWidth = (drawA ? 3.5 : 2.5) * pulse
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
          
        canvas.drawLine(pts[i], pts[i+1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleDNAPainter old) =>
      old.time != time || old.scrollOffset != scrollOffset || old.colorA != colorA || old.colorB != colorB || old.bpmRange != bpmRange;
}
'''
with open(path, 'w', encoding='utf-8') as f:
    f.write(head + dna_code)

print("Updated DNA additions!")
