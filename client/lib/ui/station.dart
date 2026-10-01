import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/node.dart';
import '../state/system_store.dart';
import 'theme.dart';

const stationSize = Size(1200, 1050);
const moduleCenters = <String, Offset>{
  'MOD-01': Offset(255, 410),
  'MOD-02': Offset(580, 235),
  'MOD-03': Offset(940, 500),
  'MOD-04': Offset(555, 810),
};
const moduleNames = <String, String>{
  'MOD-01': 'POWER / SERVICE DECK',
  'MOD-02': 'ENVIRONMENT / HABITAT',
  'MOD-03': 'COMPUTE / RELAY',
  'MOD-04': 'ROBOTICS / TRANSFER',
};

class StationDisplay extends StatefulWidget {
  final SystemStore store;
  final String? selected, interior;
  final bool faultOnly;
  const StationDisplay({super.key, required this.store, this.selected,
    this.interior, this.faultOnly = false});
  @override
  State<StationDisplay> createState() => _StationDisplayState();
}
class _StationDisplayState extends State<StationDisplay> with SingleTickerProviderStateMixin {
  late final motion = AnimationController(vsync: this, duration: const Duration(seconds: 24));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) motion.stop();
    else if (!motion.isAnimating) motion.repeat();
  }
  @override
  void dispose() { motion.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: CustomPaint(
    painter: StationPainter(store: widget.store, selected: widget.selected,
      interior: widget.interior, faultOnly: widget.faultOnly, motion: motion)));
}

void drawLabel(
  Canvas canvas,
  String text,
  Offset p,
  Color color, {
  double size = 11,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'RobotoCondensed',
        fontSize: size,
        letterSpacing: 1.4,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, p);
}

class StationPainter extends CustomPainter {
  final SystemStore store;
  final String? selected, interior;
  final Animation<double>? motion;
  final bool faultOnly;
  StationPainter({required this.store, this.selected, this.interior,
    this.motion, this.faultOnly = false}) : super(repaint: motion);
  @override
  void paint(Canvas canvas, Size size) {
    if (interior != null) {
      drawInterior(canvas);
      return;
    }
    final pen = Paint()
      ..color = accent.withValues(alpha: .35)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke;
    final core = const Offset(565, 490);
    final phase = motion?.value ?? 0;
    // Docking spine: two independent rails, pressure collars and elbow joints.
    for (final entry in moduleCenters.entries) {
      final p = entry.value;
      final mid = Offset((core.dx + p.dx) / 2, core.dy);
      final path = Path()
        ..moveTo(core.dx, core.dy)
        ..lineTo(mid.dx, mid.dy)
        ..lineTo(p.dx, p.dy);
      canvas.drawPath(
        path,
        pen
          ..strokeWidth = 25
          ..color = line.withValues(alpha: .16),
      );
      canvas.drawPath(
        path,
        pen
          ..strokeWidth = .8
          ..color = accent.withValues(alpha: .35),
      );
      final perpendicular = Offset(-(p.dy - core.dy), p.dx - core.dx);
      final normal = perpendicular / perpendicular.distance * 11;
      canvas.drawLine(core + normal, p + normal, pen);
      canvas.drawLine(core - normal, p - normal, pen);
      for (var i = 1; i < 5; i++) {
        final collar = Offset.lerp(core, p, i / 5)!;
        canvas.drawCircle(collar, 14, pen..color = line);
      }
      if (store.connected && !store.paused && motion != null) {
        final progress = (phase * 3 + moduleCenters.keys.toList().indexOf(entry.key) * .23) % 1;
        canvas.drawCircle(Offset.lerp(core, p, progress)!, 2.5,
          Paint()..color = accent.withValues(alpha: .28));
      }
    }
    canvas.drawCircle(core, 67, pen..color = accent.withValues(alpha: .6));
    canvas.drawCircle(core, 49 + math.sin(phase * math.pi * 2) * 1.2, pen);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.drawLine(
        core + Offset(math.cos(a), math.sin(a)) * 49,
        core + Offset(math.cos(a), math.sin(a)) * 67,
        pen..color = line,
      );
    }
    drawLabel(
      canvas,
      'CENTRAL\nTRANSFER',
      core - const Offset(29, 14),
      muted,
      size: 10,
    );
    // Asymmetric radiator wings / antenna hardware, not a device grid.
    for (final origin in [const Offset(395, 610), const Offset(745, 340)]) {
      final rect = Rect.fromLTWH(origin.dx, origin.dy, 170, 65);
      canvas.drawRect(rect, pen..color = line);
      for (var i = 1; i < 12; i++) {
        canvas.drawLine(
          rect.topLeft + Offset(i * 14, 0),
          rect.bottomLeft + Offset(i * 14, 0),
          pen,
        );
      }
      canvas.drawLine(rect.center, core, pen);
    }
    // Fixed facility geometry; these are structural annotations, not invented
    // online devices or telemetry. All actionable nodes retain server IDs.
    final structures = <String, List<Offset>>{
      'AIRLOCK / DOCK.02': [const Offset(1030, 505), const Offset(1100, 565), const Offset(1120, 635)],
      'UTILITY ARM': [const Offset(265, 355), const Offset(190, 245), const Offset(290, 175), const Offset(335, 190)],
      'SERVICE TUNNEL': [const Offset(570, 280), const Offset(390, 285), const Offset(330, 345)],
      'RELAY / EXT.01': [const Offset(650, 475), const Offset(805, 280), const Offset(950, 260)],
      'POWER STRUCTURE': [const Offset(230, 465), const Offset(175, 555), const Offset(90, 565)],
    };
    for (final entry in structures.entries) {
      final points = entry.value;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) { path.lineTo(p.dx, p.dy); }
      canvas.drawPath(path, pen..color = accent.withValues(alpha: .23)..strokeWidth = .7);
      canvas.drawPath(path.shift(const Offset(5, 5)), pen..color = line);
      canvas.drawCircle(points.last, 11, pen);
      drawLabel(canvas, entry.key, points.last + const Offset(-50, -24), muted, size: 8);
    }
    for (final entry in moduleCenters.entries) {
      final id = entry.key, p = entry.value;
      final fault = store.alerts.any(
        (a) =>
            a['state'] != 'RESOLVED' && store.nodes[a['node_id']]?.module == id,
      );
      final color = fault
          ? critical
          : selected == id
          ? ink
          : accent.withValues(alpha: .55);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      final angle = id == 'MOD-02' || id == 'MOD-04' ? math.pi / 2 : -.12;
      canvas.rotate(angle);
      final hull = Path()
        ..moveTo(-116, -37)
        ..lineTo(-91, -63)
        ..lineTo(84, -63)
        ..lineTo(116, -36)
        ..lineTo(116, 36)
        ..lineTo(84, 63)
        ..lineTo(-91, 63)
        ..lineTo(-116, 37)
        ..close();
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected == id ? 1 + .18 * math.sin(phase * math.pi * 4) : .9
        ..color = color;
      canvas.drawPath(hull, Paint()..color = background);
      canvas.drawPath(
        hull.shift(const Offset(16, -18)),
        outline..color = color.withValues(alpha: .3),
      );
      canvas.drawPath(hull, outline..color = color);
      for (double x = -90; x <= 85; x += 28) {
        canvas.drawLine(
          Offset(x, -62),
          Offset(x, 62),
          outline..color = color.withValues(alpha: .3),
        );
        canvas.drawLine(Offset(x, -62), Offset(x + 16, -80), outline);
      }
      canvas.drawLine(
        const Offset(-116, 0),
        const Offset(116, 0),
        outline..color = color.withValues(alpha: .2),
      );
      canvas.drawRect(const Rect.fromLTWH(-22, -30, 52, 26), outline);
      canvas.drawCircle(const Offset(94, 0), 15, outline);
      if (selected == id) {
        canvas.drawPath(hull, Paint()..color = accent.withValues(alpha: .035));
        for (final offset in [const Offset(-140, -90), const Offset(135, 82)]) {
          canvas.drawLine(
            offset,
            offset + const Offset(25, 0),
            outline..color = ink,
          );
          canvas.drawLine(offset, offset + const Offset(0, 18), outline);
        }
      }
      canvas.restore();
      final label =
          p +
          (id == 'MOD-02'
              ? const Offset(90, -25)
              : id == 'MOD-04'
              ? const Offset(95, 25)
              : const Offset(-106, 92));
      drawLabel(canvas, id, label, color, size: selected == id ? 17 : 14);
      drawLabel(
        canvas,
        moduleNames[id]!,
        label + const Offset(0, 24),
        muted,
        size: 9,
      );
      final cameras = store.nodes.values
          .where((n) => n.module == id && n.type == 'CAMERA')
          .toList();
      if (faultOnly && !fault) continue;
      for (var i = 0; i < cameras.length; i++) {
        final cp = p + Offset(-52 + i * 72, -24);
        canvas.drawCircle(
          cp,
          4,
          Paint()..color = statusColor(cameras[i].status).withValues(alpha:
            cameras[i].status == 'OFFLINE' ? .45 : .48 + .22 * math.pow(math.sin((phase * 6 + i * .4) * math.pi), 8).toDouble()),
        );
        canvas.drawLine(cp, cp + const Offset(18, -14), outline..color = line);
      }
      if (fault)
        drawLabel(
          canvas,
          '! SYS ALERT',
          label + const Offset(0, 40),
          critical,
          size: 11,
        );
    }
    // Sparse coordinate marks leave the black field intact.
    for (final p in [
      const Offset(92, 142),
      const Offset(1080, 280),
      const Offset(85, 845),
    ]) {
      canvas.drawLine(
        p - const Offset(12, 0),
        p + const Offset(12, 0),
        pen..color = line,
      );
      canvas.drawLine(p - const Offset(0, 12), p + const Offset(0, 12), pen);
      drawLabel(
        canvas,
        '${p.dx.toInt()}.${p.dy.toInt() + (phase * 3).floor()}',
        p + const Offset(16, 0),
        muted,
        size: 8,
      );
    }
    drawLabel(
      canvas,
      'AXIS / 042.17  •  PRESSURISED VOLUME',
      const Offset(260, 990),
      muted,
      size: 9,
    );
  }

  void drawInterior(Canvas canvas) {
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..color = accent.withValues(alpha: .45)
      ..strokeWidth = .8;
    final hull = Path()
      ..moveTo(130, 380)
      ..lineTo(210, 235)
      ..lineTo(890, 235)
      ..lineTo(1040, 370)
      ..lineTo(1040, 700)
      ..lineTo(880, 820)
      ..lineTo(200, 820)
      ..lineTo(130, 700)
      ..close();
    canvas.drawPath(hull, pen);
    canvas.drawPath(hull.shift(const Offset(22, -22)), pen..color = line);
    canvas.drawLine(const Offset(320, 235), const Offset(320, 820), pen);
    canvas.drawLine(const Offset(850, 235), const Offset(850, 820), pen);
    drawLabel(
      canvas,
      '$interior / INTERNAL SYSTEMS',
      const Offset(155, 160),
      ink,
      size: 20,
    );
    for (final n in store.nodes.values.where(
      (n) => n.module == interior && n.type != 'MODULE',
    )) {
      final p = interiorPosition(n);
      final color = store.selectedId == n.id ? ink : statusColor(n.status);
      canvas.drawCircle(p, 6, Paint()..color = color);
      canvas.drawLine(
        p,
        p + const Offset(50, -22),
        pen..color = color.withValues(alpha: .5),
      );
      drawLabel(
        canvas,
        '${n.id}\n${n.subtype}',
        p + const Offset(52, -32),
        color,
        size: 11,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StationPainter oldDelegate) => true;
}

Offset interiorPosition(Node n) {
  final order = int.tryParse(n.id.split('-').last) ?? 1;
  return switch (n.subtype) {
    'POWER' => const Offset(240, 430),
    'DOOR' => const Offset(870, 540),
    'LIGHT' => const Offset(530, 280),
    'CAMERA' => Offset(order <= 4 ? 195 : 915, order <= 4 ? 315 : 740),
    'SENSOR' => Offset(425 + order % 2 * 180, 640 + order % 2 * 90),
    'SERVER' => const Offset(470, 420),
    'ROBOT' => const Offset(680, 715),
    _ => Offset(610 + order % 2 * 135, 420 + order % 2 * 100),
  };
}
