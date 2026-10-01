import 'package:flutter/material.dart';
import '../state/system_store.dart';
import '../domain/node.dart';
import 'theme.dart';
import 'terminal_effects.dart';
import 'video_texture.dart';

String cameraAsset(Node camera) => int.parse(camera.id.split('-').last) <= 4
    ? 'assets/camera/service-deck.png'
    : 'assets/camera/relay-deck.png';

class CameraDisplay extends StatelessWidget {
  final SystemStore store;
  final String cameraId;
  final ValueChanged<String> onTarget;
  final bool thumbnail;
  const CameraDisplay({
    super.key,
    required this.store,
    required this.cameraId,
    required this.onTarget,
    this.thumbnail = false,
  });
  @override
  Widget build(BuildContext context) {
    final camera = store.nodes[cameraId];
    if (camera == null) return const SizedBox.shrink();
    final targets = (store.cameraTargets[cameraId] as List? ?? [])
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final zoom = (camera.controls['zoom'] as num).toDouble();
        final pan =
            (camera.controls['pan'] as num).toDouble() / 90 * size.width * .15;
        final tilt =
            (camera.controls['tilt'] as num).toDouble() /
            45 *
            size.height *
            .15;
        final matrix = Matrix4.diagonal3Values(zoom, zoom, 1)
          ..setTranslationRaw(
            size.width * (1 - zoom) / 2 + pan,
            size.height * (1 - zoom) / 2 + tilt,
            0,
          );
        return ClipRect(
          child: Stack(
            children: [
              if (camera.status != 'OFFLINE')
                Positioned.fill(
                  child: Transform(
                    transform: matrix,
                    child: ColorFiltered(colorFilter: const ColorFilter.matrix([
                      .90,.075,.025,0,0, .075,.90,.025,0,0, .075,.15,.775,0,0, 0,0,0,1,0,
                    ]), child: Image.asset(cameraAsset(camera), fit: BoxFit.fill)),
                  ),
                ),
              if (camera.status != 'OFFLINE' && store.chromatic)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Transform(
                      transform: matrix.clone()
                        ..setTranslationRaw(
                          matrix.storage[12] + .6,
                          matrix.storage[13],
                          0,
                        ),
                      child: Opacity(
                        opacity: .025,
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            SamTokens.blue,
                            BlendMode.color,
                          ),
                          child: Image.asset(
                            cameraAsset(camera),
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (camera.status != 'OFFLINE' && !thumbnail)
                Positioned.fill(child: VideoTexture(crt: store.crt, noise: store.noise, glitch: store.glitch)),
              if (camera.status != 'OFFLINE' && !thumbnail)
                Positioned.fill(
                  child: Transform(
                    transform: matrix,
                    child: Stack(
                      children: [
                        for (final t in targets)
                          Positioned(
                            left: (t['x'] as num).toDouble() * size.width,
                            top: (t['y'] as num).toDouble() * size.height,
                            width: (t['width'] as num).toDouble() * size.width,
                            height:
                                (t['height'] as num).toDouble() * size.height,
                            child: Semantics(
                              button: true,
                              label: 'Target ${t['node_id']}',
                              child: MouseRegion(
                                onEnter: (_) =>
                                    onTarget(t['node_id'] as String),
                                child: GestureDetector(
                                  key: ValueKey('target-${t['node_id']}'),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => onTarget(t['node_id'] as String),
                                  child: CustomPaint(
                                    painter: _TargetMarker(
                                      selected:
                                          store.selectedId == t['node_id'],
                                      identified:
                                          store.scannedId == t['node_id'],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _CameraFrame()),
                ),
              ),
              if (!thumbnail) ...[
                Positioned(
                  left: 14,
                  top: 14,
                  child: Text(
                    '${camera.module}\nOPTICAL SENSOR / ${camera.id}\n${camera.status}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: ink,
                      height: 1.6,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  top: 14,
                  child: Text(
                    'SIG ${camera.telemetry['signal']}\n${camera.telemetry['fps']} FPS\n${camera.telemetry['latency']} MS',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 9,
                      color: ink,
                      height: 1.6,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 14,
                  child: Text(
                    'PAN ${camera.controls['pan']} / TILT ${camera.controls['tilt']}\nZOOM ${zoom.toStringAsFixed(1)} / T+${store.tick * 2}s',
                    style: const TextStyle(
                      fontSize: 8,
                      color: ink,
                      height: 1.6,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: const Text(
                    'MOCK FEED\nPRE-RENDERED',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 8, color: ink, height: 1.6),
                  ),
                ),
              ],
              if (camera.status == 'OFFLINE')
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'NO SIGNAL',
                        style: TextStyle(
                          fontSize: 18,
                          letterSpacing: 5,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$cameraId / OPTICAL CHANNEL LOST',
                        style: const TextStyle(fontSize: 8, color: muted),
                      ),
                    ],
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: AnalogPainter(
                      crt: store.crt,
                      noise: store.noise,
                      glitch: store.glitch,
                      chromatic: store.chromatic,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TargetMarker extends CustomPainter {
  final bool selected, identified;
  _TargetMarker({required this.selected, required this.identified});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final p = Paint()
      ..color = ink.withValues(alpha: selected ? .8 : .35)
      ..strokeWidth = .65
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, selected ? 7 : 1.5, p);
    if (!selected) return;
    for (final d in [
      const Offset(1, 0),
      const Offset(-1, 0),
      const Offset(0, 1),
      const Offset(0, -1),
    ])
      canvas.drawLine(center + d * 10, center + d * 16, p);
    if (identified) {
      for (final corner in [
        Offset.zero,
        Offset(size.width, 0),
        Offset(0, size.height),
        Offset(size.width, size.height),
      ]) {
        final dx = corner.dx == 0 ? 1.0 : -1.0,
            dy = corner.dy == 0 ? 1.0 : -1.0;
        canvas.drawLine(corner, corner + Offset(dx * 10, 0), p);
        canvas.drawLine(corner, corner + Offset(0, dy * 10), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TargetMarker oldDelegate) =>
      selected != oldDelegate.selected || identified != oldDelegate.identified;
}

class _CameraFrame extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = ink.withValues(alpha: .55)
      ..strokeWidth = .65;
    for (final corner in [
      const Offset(6, 6),
      Offset(size.width - 6, 6),
      Offset(6, size.height - 6),
      Offset(size.width - 6, size.height - 6),
    ]) {
      final dx = corner.dx < 10 ? 1.0 : -1.0, dy = corner.dy < 10 ? 1.0 : -1.0;
      canvas.drawLine(corner, corner + Offset(dx * 18, 0), p);
      canvas.drawLine(corner, corner + Offset(0, dy * 18), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
