import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'theme.dart';

class TerminalSurface extends StatefulWidget {
  final Widget child;
  final SystemStore store;
  const TerminalSurface({super.key, required this.child, required this.store});
  @override
  State<TerminalSurface> createState() => _TerminalSurfaceState();
}

class _TerminalSurfaceState extends State<TerminalSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController cycle;
  Offset? cursor;
  DateTime? touchedAt;
  Timer? clearCursor;
  @override
  void initState() {
    super.initState();
    cycle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      cycle.stop();
    } else if (!cycle.isAnimating) {
      cycle.repeat();
    }
  }

  @override
  void dispose() {
    clearCursor?.cancel();
    cycle.dispose();
    super.dispose();
  }

  void target(Offset p, {bool transient = false}) {
    clearCursor?.cancel();
    setState(() {
      cursor = p;
      touchedAt = transient ? DateTime.now() : null;
    });
    if (transient)
      clearCursor = Timer(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => cursor = null);
      });
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.precise,
    onHover: (e) => target(e.localPosition),
    onExit: (_) => setState(() => cursor = null),
    child: Listener(
      onPointerDown: (e) => target(e.localPosition, transient: true),
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: cycle,
                  builder: (_, __) => CustomPaint(
                    painter: AnalogPainter(
                      crt: widget.store.crt,
                      noise: widget.store.noise,
                      glitch: widget.store.glitch,
                      chromatic: widget.store.chromatic,
                      phase: cycle.value,
                      cursor: cursor,
                      cursorOpacity: touchedAt == null
                          ? 1
                          : (1 -
                                    DateTime.now()
                                            .difference(touchedAt!)
                                            .inMilliseconds /
                                        450)
                                .clamp(0.0, 1.0)
                                .toDouble(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class AnalogPainter extends CustomPainter {
  final bool crt, noise, glitch, chromatic;
  final double phase;
  final Offset? cursor;
  final double cursorOpacity;
  AnalogPainter({
    this.crt = false,
    this.noise = false,
    this.glitch = false,
    this.chromatic = false,
    this.phase = 0,
    this.cursor,
    this.cursorOpacity = 1,
  });
  @override
  void paint(Canvas canvas, Size size) {
    if (crt) {
      final p = Paint()
        ..color = Colors.black.withValues(alpha: SamTokens.scanlineOpacity);
      for (double y = 0; y < size.height; y += 3) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      }
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const RadialGradient(
            radius: .8,
            colors: [Colors.transparent, Color(0x30000000)],
          ).createShader(Offset.zero & size),
      );
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = ink.withValues(
            alpha: .004 + .003 * math.sin(phase * math.pi * 2),
          ),
      );
    }
    if (noise) {
      final random = math.Random((phase * 24).floor());
      final p = Paint()..color = ink.withValues(alpha: SamTokens.noiseOpacity);
      for (var i = 0; i < 280; i++) {
        canvas.drawRect(
          Rect.fromLTWH(
            random.nextDouble() * size.width,
            random.nextDouble() * size.height,
            .8,
            .8,
          ),
          p,
        );
      }
    }
    if (glitch)
      canvas.drawRect(
        Rect.fromLTWH(0, size.height * phase, size.width, 1.2),
        Paint()..color = ink.withValues(alpha: .035),
      );
    if (chromatic) {
      canvas.drawLine(
        const Offset(.5, 0),
        Offset(.5, size.height),
        Paint()..color = const Color(0x2589b9cf),
      );
      canvas.drawLine(
        Offset(size.width - .5, 0),
        Offset(size.width - .5, size.height),
        Paint()..color = const Color(0x25d87872),
      );
    }
    if (cursor != null) {
      final p = Paint()
        ..color = SamTokens.phosphor.withValues(alpha: .65 * cursorOpacity)
        ..strokeWidth = .65
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(cursor!, 3, p);
      for (final d in [
        const Offset(1, 0),
        const Offset(-1, 0),
        const Offset(0, 1),
        const Offset(0, -1),
      ]) {
        canvas.drawLine(cursor! + d * 5, cursor! + d * 9, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant AnalogPainter oldDelegate) => true;
}

class DisplayLayer extends StatelessWidget {
  final Widget child;
  final int delay;
  const DisplayLayer({super.key, required this.child, this.delay = 0});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(
      begin: MediaQuery.disableAnimationsOf(context) ? 1.0 : 0.0,
      end: 1.0,
    ),
    duration: const Duration(milliseconds: 380),
    builder: (_, progress, child) {
      final start = delay / 380;
      final reveal = ((progress - start) / (1 - start)).clamp(0.0, 1.0);
      return ClipRect(clipper: _DisplayClip(reveal), child: child);
    },
    child: child,
  );
}

class DisplayRedraw extends StatelessWidget {
  final Widget child;
  const DisplayRedraw({super.key, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(
      begin: MediaQuery.disableAnimationsOf(context) ? 1.0 : .02,
      end: 1.0,
    ),
    duration: const Duration(milliseconds: 280),
    builder: (_, value, child) =>
        ClipRect(clipper: _DisplayClip(value), child: child),
    child: child,
  );
}

class _DisplayClip extends CustomClipper<Rect> {
  final double value;
  _DisplayClip(this.value);
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height * value);
  @override
  bool shouldReclip(covariant _DisplayClip oldClipper) =>
      value != oldClipper.value;
}
