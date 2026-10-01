import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// Both the optical raster and its sensor markers use this mild radial warp.
// Values are normalized; controls are applied outside the lens transform.
Offset lensPoint(Offset p, bool enabled) {
  if (!enabled) return p;
  final d = p - const Offset(.5, .5);
  return const Offset(.5, .5) + d * (1.012 / (1 + .032 * d.distanceSquared));
}
Rect lensTarget(Rect rect, bool enabled) {
  final a = lensPoint(rect.topLeft, enabled), b = lensPoint(rect.bottomRight, enabled);
  return Rect.fromPoints(a, b);
}

class OpticalImage extends StatefulWidget {
  final String asset;
  final bool lens;
  const OpticalImage({super.key, required this.asset, required this.lens});
  @override
  State<OpticalImage> createState() => _OpticalImageState();
}
class _OpticalImageState extends State<OpticalImage> {
  ImageStream? stream;
  ImageInfo? frame;
  late final listener = ImageStreamListener((info, _) {
    final next = info.clone();
    if (!mounted) { next.dispose(); return; }
    setState(() { frame?.dispose(); frame = next; });
  });
  void resolve() {
    stream?.removeListener(listener);
    stream = AssetImage(widget.asset).resolve(createLocalImageConfiguration(context));
    stream!.addListener(listener);
  }
  @override
  void didChangeDependencies() { super.didChangeDependencies(); resolve(); }
  @override
  void didUpdateWidget(covariant OpticalImage old) { super.didUpdateWidget(old); if (old.asset != widget.asset) resolve(); }
  @override
  void dispose() { stream?.removeListener(listener); frame?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => frame == null ? const SizedBox.shrink()
    : CustomPaint(painter: _LensRaster(frame!.image, widget.lens));
}
class _LensRaster extends CustomPainter {
  final ui.Image image;
  final bool enabled;
  _LensRaster(this.image, this.enabled);
  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled) {
      canvas.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), Offset.zero & size, Paint()..filterQuality = FilterQuality.low);
      return;
    }
    const cells = 20;
    final positions = <Offset>[], textures = <Offset>[], indices = <int>[];
    for (var y = 0; y <= cells; y++) {
      for (var x = 0; x <= cells; x++) {
        final source = Offset(x / cells, y / cells), warped = lensPoint(source, true);
        positions.add(Offset(warped.dx * size.width, warped.dy * size.height));
        textures.add(Offset(source.dx * image.width, source.dy * image.height));
        if (x < cells && y < cells) {
          final i = y * (cells + 1) + x;
          indices.addAll([i, i + 1, i + cells + 1, i + 1, i + cells + 2, i + cells + 1]);
        }
      }
    }
    final vertices = ui.Vertices(ui.VertexMode.triangles, positions, textureCoordinates: textures, indices: indices);
    final paint = Paint()..filterQuality = FilterQuality.low
      ..shader = ui.ImageShader(image, ui.TileMode.clamp, ui.TileMode.clamp, Matrix4.identity().storage);
    canvas.drawVertices(vertices, ui.BlendMode.srcOver, paint);
    vertices.dispose();
  }
  @override
  bool shouldRepaint(covariant _LensRaster old) => image != old.image || enabled != old.enabled;
}
