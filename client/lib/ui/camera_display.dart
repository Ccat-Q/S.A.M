import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'theme.dart';

class CameraDisplay extends StatefulWidget {
  final SystemStore store;
  final String cameraId;
  final ValueChanged<String> onTarget;
  const CameraDisplay({super.key, required this.store, required this.cameraId, required this.onTarget});
  @override
  State<CameraDisplay> createState() => _CameraDisplayState();
}
class _CameraDisplayState extends State<CameraDisplay> with SingleTickerProviderStateMixin {
  late final AnimationController pulse;
  @override
  void initState() { super.initState(); pulse = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(); }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) { pulse.stop(); }
    else if (!pulse.isAnimating) { pulse.repeat(); }
  }
  @override
  void dispose() { pulse.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final camera = widget.store.nodes[widget.cameraId];
    if (camera == null) return const SizedBox.shrink();
    final targets = (widget.store.cameraTargets[widget.cameraId] as List? ?? []).map((x) => Map<String, dynamic>.from(x as Map)).toList();
    final motionReduced = MediaQuery.of(context).disableAnimations;
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final zoom = (camera.controls['zoom'] as num).toDouble();
      final pan = (camera.controls['pan'] as num).toDouble() / 90 * size.width * 0.15;
      final tilt = (camera.controls['tilt'] as num).toDouble() / 45 * size.height * 0.15;
      final matrix = Matrix4.diagonal3Values(zoom, zoom, 1)..setTranslationRaw(size.width * (1 - zoom) / 2 + pan, size.height * (1 - zoom) / 2 + tilt, 0);
      return ClipRect(child: Stack(children: [
        Positioned.fill(child: Transform(transform: matrix, child: AnimatedBuilder(animation: pulse, builder: (_, __) => CustomPaint(
          painter: FacilityPainter(widget.store, camera.id, motionReduced ? 0 : pulse.value))))),
        if (camera.status != 'OFFLINE') Positioned.fill(child: Transform(transform: matrix, child: Stack(children: [
          for (final target in targets) Positioned(
            left: (target['x'] as num).toDouble() * size.width, top: (target['y'] as num).toDouble() * size.height,
            width: (target['width'] as num).toDouble() * size.width, height: (target['height'] as num).toDouble() * size.height,
            child: Semantics(button: true, label: target['node_id'] as String, child: GestureDetector(
              key: ValueKey('target-${target['node_id']}'), onTap: () => widget.onTarget(target['node_id'] as String),
              child: Container(decoration: BoxDecoration(border: Border.all(color: widget.store.selectedId == target['node_id'] ? accent : accent.withValues(alpha: .4))),
                alignment: Alignment.bottomLeft, child: Container(color: background.withValues(alpha: .9), padding: const EdgeInsets.all(4),
                  child: Text('${target['node_id']} // ${widget.store.nodes[target['node_id']]?.subtype}', style: const TextStyle(fontSize: 8, color: accent))))))),
        ]))),
        Positioned(left: 16, top: 16, child: Container(color: background.withValues(alpha: .8), padding: const EdgeInsets.all(8), child: Text(
          '${camera.id} / ${camera.module}\n${camera.status}   SIGNAL ${camera.telemetry['signal']}%\nFPS ${camera.telemetry['fps']}   LATENCY ${camera.telemetry['latency']}ms', style: const TextStyle(fontSize: 10, color: ink)))),
        Positioned(right: 16, top: 16, child: Text('SIMULATION\nT+${widget.store.tick * 2}s', textAlign: TextAlign.right, style: const TextStyle(color: warning, fontSize: 10))),
        Positioned(left: 16, bottom: 16, child: Text('PAN ${camera.controls['pan']}  TILT ${camera.controls['tilt']}  ZOOM ${zoom.toStringAsFixed(1)}×', style: const TextStyle(fontSize: 10))),
        if (camera.status == 'OFFLINE') Center(child: Text('NO SIGNAL // ${camera.id}', style: const TextStyle(color: warning))),
        const Center(child: IgnorePointer(child: Icon(Icons.add, size: 20, color: Color(0x668fc9bc)))),
        if (widget.store.crt) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: ScanlinePainter()))),
      ]));
    });
  }
}

class FacilityPainter extends CustomPainter {
  final SystemStore store;
  final String cameraId;
  final double phase;
  FacilityPainter(this.store, this.cameraId, this.phase);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xff101c1b));
    if (store.nodes[cameraId]?.status == 'OFFLINE') return;
    final pen = Paint()..color = const Color(0xff324a44)..strokeWidth = 1..style = PaintingStyle.stroke;
    final center = Offset(size.width * .52, size.height * .46);
    final inner = Rect.fromCenter(center: center, width: size.width * .48, height: size.height * .45);
    canvas.drawRect(inner, pen);
    for (final corner in [Offset.zero, Offset(size.width, 0), Offset(0, size.height), Offset(size.width, size.height)]) {
      final end = Offset(corner.dx == 0 ? inner.left : inner.right, corner.dy == 0 ? inner.top : inner.bottom);
      canvas.drawLine(corner, end, pen);
    }
    for (var i = 1; i <= 6; i++) {
      final ratio = i / 7;
      final frame = Rect.lerp(inner, Offset.zero & size, ratio)!;
      canvas.drawRect(frame, pen..color = const Color(0xff233a33));
    }
    final targets = store.cameraTargets[cameraId] as List? ?? [];
    for (final t in targets) {
      final rect = Rect.fromLTWH((t['x'] as num).toDouble() * size.width, (t['y'] as num).toDouble() * size.height,
          (t['width'] as num).toDouble() * size.width, (t['height'] as num).toDouble() * size.height);
      final n = store.nodes[t['node_id']];
      canvas.drawRect(rect, Paint()..color = const Color(0xff172a25));
      canvas.drawRect(rect.deflate(5), pen..color = const Color(0xff52635c));
      for (var i = 0; i < 5; i++) {
        canvas.drawLine(rect.topLeft + Offset(10, 15 + i * 8), rect.topRight + Offset(-10, 15 + i * 8), pen);
      }
      canvas.drawCircle(rect.bottomRight - const Offset(12, 12), 3, Paint()..color = statusColor(n?.status ?? 'OFFLINE'));
    }
    // Original maintenance carriage moving on a rail; not a detected real entity.
    final cart = Rect.fromLTWH(size.width * (.2 + .4 * phase), size.height * .78, 34, 18);
    canvas.drawRect(cart, Paint()..color = const Color(0xff627c70));
    if (store.noise) {
      final random = math.Random((phase * 100).floor());
      for (var i = 0; i < 200; i++) { canvas.drawCircle(Offset(random.nextDouble() * size.width, random.nextDouble() * size.height), .4, Paint()..color = const Color(0x158fc9bc)); }
    }
    if (store.chromatic) canvas.drawRect((Offset.zero & size).deflate(8), Paint()..color = const Color(0x184e8399)..strokeWidth = 2..style = PaintingStyle.stroke);
    if (store.glitch && phase > .985) canvas.drawRect(Rect.fromLTWH(0, size.height * .35, size.width, 2), Paint()..color = const Color(0x208fc9bc));
  }
  @override
  bool shouldRepaint(covariant FacilityPainter oldDelegate) => true;
}

class ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x10000000);
    for (double y = 0; y < size.height; y += 4) { canvas.drawLine(Offset(0, y), Offset(size.width, y), paint); }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
