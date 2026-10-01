import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

class VideoTexture extends StatefulWidget {
  final bool crt, noise, glitch;
  const VideoTexture({
    super.key,
    required this.crt,
    required this.noise,
    required this.glitch,
  });
  @override
  State<VideoTexture> createState() => _VideoTextureState();
}

class _VideoTextureState extends State<VideoTexture>
    with SingleTickerProviderStateMixin {
  late final cycle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(covariant VideoTexture oldWidget) {
    super.didUpdateWidget(oldWidget);
    sync();
  }

  void sync() {
    if (MediaQuery.disableAnimationsOf(context) ||
        !(widget.crt || widget.noise || widget.glitch))
      cycle.stop();
    else if (!cycle.isAnimating)
      cycle.repeat();
  }

  @override
  void dispose() {
    cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _VideoPainter(cycle, widget.crt, widget.noise, widget.glitch),
      ),
    ),
  );
}

class _VideoPainter extends CustomPainter {
  final Animation<double> cycle;
  final bool crt, noise, glitch;
  _VideoPainter(this.cycle, this.crt, this.noise, this.glitch)
    : super(repaint: cycle);
  @override
  void paint(Canvas canvas, Size size) {
    if (crt) {
      final p = Paint()..color = Colors.black.withValues(alpha: .075);
      for (double y = 0; y < size.height; y += 3) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      }
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = Colors.black.withValues(
            alpha: .025 + .009 * math.sin(cycle.value * math.pi * 2),
          ),
      );
      final area = Offset.zero & size;
      canvas.drawRect(area, Paint()..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withValues(alpha: .15)],
        stops: const [.35, 1], radius: .9,
      ).createShader(area));
    }
    if (noise) {
      final random = math.Random((cycle.value * 144).floor());
      final p = Paint()..color = ink.withValues(alpha: .025);
      for (var i = 0; i < 160; i++) {
        canvas.drawRect(
          Rect.fromLTWH(
            random.nextDouble() * size.width,
            random.nextDouble() * size.height,
            1 + random.nextDouble() * 6,
            .8,
          ),
          p,
        );
      }
      p.color = Colors.black.withValues(alpha: .055);
      for (var i = 0; i < 80; i++) {
        canvas.drawCircle(Offset(random.nextDouble() * size.width, random.nextDouble() * size.height), .5, p);
      }
      // Compression/field ghosting belongs to the optical image, never text.
      final y = size.height * ((cycle.value * 2) % 1);
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 11),
        Paint()..color = Colors.black.withValues(alpha: .025),
      );
    }
    if (glitch)
      canvas.drawRect(
        Rect.fromLTWH(0, size.height * cycle.value, size.width, 2),
        Paint()..color = ink.withValues(alpha: .05),
      );
  }

  @override
  bool shouldRepaint(covariant _VideoPainter oldDelegate) =>
      crt != oldDelegate.crt ||
      noise != oldDelegate.noise ||
      glitch != oldDelegate.glitch;
}
