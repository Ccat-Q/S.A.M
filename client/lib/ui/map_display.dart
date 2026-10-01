import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/node.dart';
import '../state/system_store.dart';
import 'station.dart';
import 'theme.dart';

const mapSize = Size(1200, 1050);
Map<String, Offset> nodePositions(Iterable<Node> nodes, bool network) {
  if (!network)
    return {
      for (final n in nodes)
        n.id: n.type == 'MODULE'
            ? moduleCenters[n.id] ?? const Offset(600, 500)
            : interiorPosition(n),
    };
  final result = <String, Offset>{'NET-01': const Offset(600, 520)};
  for (var i = 0; i < 4; i++) {
    final angle = -math.pi / 2 + i * math.pi / 2;
    final hub =
        const Offset(600, 520) + Offset(math.cos(angle), math.sin(angle)) * 240;
    final module = 'MOD-0${i + 1}';
    result['NET-0${i + 2}'] = hub;
    final members = nodes
        .where((n) => n.module == module && n.type != 'NETWORK')
        .toList();
    for (var j = 0; j < members.length; j++) {
      final a = angle + (j - (members.length - 1) / 2) * .14;
      result[members[j].id] =
          const Offset(600, 520) +
          Offset(math.cos(a), math.sin(a)) * (j % 2 == 0 ? 405 : 460);
    }
  }
  return result;
}

class MapDisplay extends StatelessWidget {
  final SystemStore store;
  final bool network;
  final Set<String>? visible;
  final ValueChanged<String> onSelect;
  final TransformationController? controller;
  const MapDisplay({
    super.key,
    required this.store,
    required this.network,
    required this.onSelect,
    this.visible,
    this.controller,
  });
  @override
  Widget build(BuildContext context) {
    final positions = nodePositions(store.nodes.values, network);
    return ClipRect(
      child: InteractiveViewer(
        transformationController: controller,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(250),
        minScale: .15,
        maxScale: 3,
        child: GestureDetector(
          onTapUp: (e) {
            String? nearest;
            double best = math.max(
              36.0,
              22 / (controller?.value.getMaxScaleOnAxis() ?? 1),
            );
            for (final p in positions.entries) {
              if (visible != null && !visible!.contains(p.key)) continue;
              final d = (p.value - e.localPosition).distance;
              if (d < best) {
                nearest = p.key;
                best = d;
              }
            }
            if (nearest != null) onSelect(nearest);
          },
          child: SizedBox(
            width: mapSize.width,
            height: mapSize.height,
            child: CustomPaint(
              painter: MapPainter(
                store: store,
                positions: positions,
                network: network,
                visible: visible,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  final SystemStore store;
  final Map<String, Offset> positions;
  final bool network;
  final Set<String>? visible;
  MapPainter({
    required this.store,
    required this.positions,
    required this.network,
    this.visible,
  });
  @override
  void paint(Canvas canvas, Size size) {
    if (!network) {
      StationPainter(
        store: store,
        selected: store.selected?.module,
      ).paint(canvas, size);
      return;
    }
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    for (final radius in [170.0, 330.0, 480.0]) {
      canvas.drawCircle(
        const Offset(600, 520),
        radius,
        pen..color = line.withValues(alpha: .35),
      );
    }
    for (final edge in store.edges) {
      final a = positions[edge['source']], b = positions[edge['target']];
      if (a == null ||
          b == null ||
          (visible != null &&
              (!visible!.contains(edge['source']) ||
                  !visible!.contains(edge['target']))))
        continue;
      final selected =
          edge['source'] == store.selectedId ||
          edge['target'] == store.selectedId;
      final failed = store.nodes[edge['source']]?.status == 'OFFLINE';
      final color = failed
          ? critical
          : edge['kind'] == 'POWER'
          ? SamTokens.amber
          : SamTokens.blue;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(
          (a.dx + b.dx) / 2 + 18,
          (a.dy + b.dy) / 2 - 18,
          b.dx,
          b.dy,
        );
      canvas.drawPath(
        path,
        pen
          ..color = color.withValues(alpha: selected || failed ? .9 : .25)
          ..strokeWidth = selected ? 1.4 : .65,
      );
    }
    for (final n in store.nodes.values) {
      if (visible != null && !visible!.contains(n.id)) continue;
      final p = positions[n.id];
      if (p == null) continue;
      final selected = n.id == store.selectedId;
      final color = statusColor(n.status);
      canvas.drawCircle(
        p,
        n.type == 'NETWORK' ? 9 : 3,
        Paint()..color = selected ? ink : color,
      );
      if (selected)
        canvas.drawCircle(
          p,
          18,
          pen
            ..color = ink
            ..strokeWidth = .7,
        );
      drawLabel(
        canvas,
        n.id,
        p + const Offset(9, -16),
        selected ? ink : muted,
        size: 10,
      );
      drawLabel(
        canvas,
        n.subtype,
        p + const Offset(9, 1),
        n.type == 'NETWORK' ? SamTokens.blue : color,
        size: 8,
      );
    }
    drawLabel(
      canvas,
      'BUS.00 / DIGITAL NETWORK',
      const Offset(470, 575),
      SamTokens.blue,
      size: 12,
    );
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) => true;
}
