import 'package:flutter/material.dart';
import '../domain/node.dart';
import '../state/system_store.dart';
import 'theme.dart';

const mapSize = Size(1200, 850);

Map<String, Offset> nodePositions(Iterable<Node> nodes, bool network) {
  final positions = <String, Offset>{};
  for (var module = 1; module <= 4; module++) {
    final origin = Offset((module - 1) % 2 * 590.0 + 25, (module - 1) ~/ 2 * 410.0 + 20);
    final members = nodes.where((n) => n.module == 'MOD-${module.toString().padLeft(2, '0')}' && n.type != 'MODULE').toList();
    for (final n in members) {
      positions[n.id] = origin + Offset(n.x * 550, n.y * 380);
    }
    positions['MOD-${module.toString().padLeft(2, '0')}'] = origin + const Offset(82, 30);
  }
  if (network) {
    // Dedicated backbone layer avoids implying that rooms are network cables.
    positions['NET-01'] = const Offset(600, 415);
  }
  return positions;
}

class MapDisplay extends StatelessWidget {
  final SystemStore store;
  final bool network;
  final Set<String>? visible;
  final ValueChanged<String> onSelect;
  final TransformationController? controller;
  const MapDisplay({super.key, required this.store, required this.network, required this.onSelect, this.visible, this.controller});
  @override
  Widget build(BuildContext context) {
    final positions = nodePositions(store.nodes.values, network);
    return ClipRect(child: InteractiveViewer(
      transformationController: controller, constrained: false, boundaryMargin: const EdgeInsets.all(80),
      minScale: 0.25, maxScale: 2.5,
      child: GestureDetector(onTapUp: (details) {
        String? nearest; double best = 36;
        for (final entry in positions.entries) {
          if (visible != null && !visible!.contains(entry.key)) continue;
          final distance = (entry.value - details.localPosition).distance;
          if (distance < best) { nearest = entry.key; best = distance; }
        }
        if (nearest != null) onSelect(nearest);
      }, child: SizedBox(width: mapSize.width, height: mapSize.height,
        child: CustomPaint(painter: MapPainter(store: store, positions: positions, network: network, visible: visible)))),
    ));
  }
}

class MapPainter extends CustomPainter {
  final SystemStore store;
  final Map<String, Offset> positions;
  final bool network;
  final Set<String>? visible;
  MapPainter({required this.store, required this.positions, required this.network, this.visible});
  void label(Canvas canvas, String text, Offset p, Color color, {double size = 10}) {
    final painter = TextPainter(text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontFamily: 'RobotoMono')), textDirection: TextDirection.ltr)..layout();
    painter.paint(canvas, p);
  }
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = line.withValues(alpha: 0.35)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 25) { canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid); }
    for (double y = 0; y < size.height; y += 25) { canvas.drawLine(Offset(0, y), Offset(size.width, y), grid); }
    for (var i = 0; i < 4; i++) {
      final rect = Rect.fromLTWH(i % 2 * 590.0 + 25, i ~/ 2 * 410.0 + 20, 550, 380);
      canvas.drawRect(rect, Paint()..color = line..style = PaintingStyle.stroke);
      label(canvas, 'SECTOR ${String.fromCharCode(65 + i)} // MOD-0${i + 1}', rect.topLeft + const Offset(14, 12), muted);
      label(canvas, '${network ? "DEPENDENCY" : "FACILITY"} COORD / ${i + 1}.00', rect.bottomLeft + const Offset(14, -20), muted, size: 8);
    }
    if (network) {
      for (final edge in store.edges) {
        final a = positions[edge['source']], b = positions[edge['target']];
        if (a == null || b == null || (visible != null && (!visible!.contains(edge['source']) || !visible!.contains(edge['target'])))) continue;
        final selected = edge['source'] == store.selectedId || edge['target'] == store.selectedId;
        final failed = store.nodes[edge['source']]?.status == 'OFFLINE';
        final color = failed ? critical : selected ? accent : edge['kind'] == 'POWER' ? warning.withValues(alpha: .35) : const Color(0xff496a75);
        final path = Path()..moveTo(a.dx, a.dy)..lineTo(a.dx, (a.dy + b.dy) / 2)..lineTo(b.dx, (a.dy + b.dy) / 2)..lineTo(b.dx, b.dy);
        canvas.drawPath(path, Paint()..color = color..strokeWidth = selected || failed ? 1.8 : 0.8..style = PaintingStyle.stroke);
      }
    }
    for (final n in store.nodes.values) {
      if (visible != null && !visible!.contains(n.id)) continue;
      final p = positions[n.id];
      if (p == null) continue;
      final selected = store.selectedId == n.id;
      final color = statusColor(n.status);
      if (!network && n.type == 'CAMERA') {
        final path = Path()..moveTo(p.dx, p.dy)..lineTo(p.dx + 80, p.dy - 45)..lineTo(p.dx + 80, p.dy + 45)..close();
        canvas.drawPath(path, Paint()..color = accent.withValues(alpha: 0.04));
      }
      canvas.drawRect(Rect.fromCenter(center: p, width: 58, height: 31), Paint()..color = selected ? const Color(0xff193b33) : surface);
      canvas.drawRect(Rect.fromCenter(center: p, width: 58, height: 31), Paint()..color = selected ? accent : color.withValues(alpha: 0.5)..style = PaintingStyle.stroke);
      canvas.drawCircle(p + const Offset(-21, 0), 2, Paint()..color = color);
      label(canvas, n.type == 'MODULE' ? 'MOD' : n.subtype.substring(0, n.subtype.length < 3 ? n.subtype.length : 3), p + const Offset(-12, -6), color, size: 9);
      label(canvas, n.id, p + const Offset(-29, 23), selected ? ink : muted);
      if (n.status != 'ONLINE') label(canvas, n.status, p + const Offset(-29, 37), color, size: 8);
      if (selected) {
        final paint = Paint()..color = accent;
        canvas.drawLine(p + const Offset(-40, 0), p + const Offset(-32, 0), paint);
        canvas.drawLine(p + const Offset(32, 0), p + const Offset(40, 0), paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) => true;
}
