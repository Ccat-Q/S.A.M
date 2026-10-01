import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'instruments.dart';
import 'station.dart';
import 'theme.dart';

class MemoryRecord {
  final String id, type, source, date, content;
  final String? nodeId;
  const MemoryRecord({
    required this.id,
    required this.type,
    required this.source,
    required this.date,
    required this.content,
    this.nodeId,
  });
}

List<MemoryRecord> memoryRecords(SystemStore store) => [
  for (final event
      in store.logs.where((e) => e['category'] != 'TELEMETRY').take(48))
    MemoryRecord(
      id: 'EVT.${event['cursor']}',
      type:
          event['category'] == 'DEVICE' &&
              (event['message'] as String? ?? '').contains('SCAN')
          ? 'FRAGMENT'
          : 'EVENT',
      source: event['category'] as String? ?? 'SYSTEM',
      date: event['time'] as String? ?? 'UNKNOWN',
      nodeId: event['node_id'] as String?,
      content: event['message'] as String? ?? '',
    ),
  for (final node in store.nodes.values)
    MemoryRecord(
      id: 'SYS.${node.id}',
      type: 'SYSTEM',
      source: 'LIVE NODE / SNAPSHOT',
      date: 'CURRENT STATE',
      nodeId: node.id,
      content: '${node.subtype} / ${node.status} / ${node.module}',
    ),
  const MemoryRecord(
    id: 'MEDIA.001',
    type: 'MEDIA',
    source: 'BUNDLED ORIGINAL MOCK SCENE',
    date: 'BUILD ASSET',
    content:
        'Pre-rendered optical simulation. This is an asset reference, not a captured recording.',
  ),
];
Color memoryColor(String type) => switch (type) {
  'FRAGMENT' => SamTokens.amber,
  'EVENT' => SamTokens.blue,
  'MEDIA' => const Color(0xffc5b1be),
  'CONSTRUCTED' => critical,
  _ => ink,
};

class MemoryCoreScreen extends StatefulWidget {
  final SystemStore store;
  final ValueChanged<String> locate;
  const MemoryCoreScreen({
    super.key,
    required this.store,
    required this.locate,
  });
  @override
  State<MemoryCoreScreen> createState() => _MemoryCoreScreenState();
}

class _MemoryCoreScreenState extends State<MemoryCoreScreen> {
  String query = '', filter = 'ALL', selected = '';
  @override
  Widget build(BuildContext context) {
    final records = memoryRecords(widget.store);
    final shown = records
        .where(
          (r) =>
              (filter == 'ALL' || filter == r.type) &&
              '${r.id} ${r.nodeId} ${r.content}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    final current = shown.where((r) => r.id == selected).firstOrNull;
    final relationNodes = <String>{
      if (current?.nodeId != null) current!.nodeId!,
    };
    if (current?.nodeId != null) {
      final source = widget.store.nodes[current!.nodeId];
      if (source != null) relationNodes.add(source.module);
      for (final edge in widget.store.edges) {
        if (edge['source'] == current.nodeId)
          relationNodes.add(edge['target'] as String);
        if (edge['target'] == current.nodeId)
          relationNodes.add(edge['source'] as String);
      }
    }
    final related = records
        .where(
          (r) =>
              r.nodeId != null &&
              relationNodes.contains(r.nodeId) &&
              r.id != current?.id,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'MEMORY / CORE',
                  style: TextStyle(
                    fontFamily: 'RobotoCondensed',
                    fontSize: 16,
                    letterSpacing: 3,
                  ),
                ),
              ),
              Text(
                '${shown.length.toString().padLeft(3, '0')} / RECORDS',
                style: const TextStyle(color: muted, fontSize: 9),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'MEMORY QUERY / ID · NODE · CONTENT',
            ),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final type in [
                'ALL',
                'EVENT',
                'FRAGMENT',
                'SYSTEM',
                'MEDIA',
                'AUDIO',
                'CONSTRUCTED',
              ])
                SoftKey(
                  label: type,
                  selected: filter == type,
                  color: memoryColor(type),
                  onPressed: type == 'ALL' || records.any((r) => r.type == type)
                      ? () => setState(() => filter = type)
                      : null,
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (_, box) => GestureDetector(
              key: const Key('memory-ring'),
              behavior: HitTestBehavior.opaque,
              onTapUp: (e) {
                final size = Size(box.maxWidth, box.maxHeight),
                    center = Offset(size.width / 2, size.height / 2);
                final radius = math.min(size.width * .4, size.height * .4);
                String? nearest;
                var nearestDistance = 22.0;
                for (var i = 0; i < shown.length; i++) {
                  final a =
                      i / math.max(1, shown.length) * math.pi * 2 - math.pi / 2;
                  final p = center + Offset(math.cos(a), math.sin(a)) * radius;
                  final distance = (p - e.localPosition).distance;
                  if (distance < nearestDistance) {
                    nearest = shown[i].id;
                    nearestDistance = distance;
                  }
                }
                if (nearest != null) setState(() => selected = nearest!);
              },
              child: CustomPaint(
                size: Size(box.maxWidth, box.maxHeight),
                painter: _MemoryRing(
                  records: shown,
                  selected: selected,
                  relations: related.map((r) => r.id).toSet(),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: current == null
              ? const Text(
                  'SELECT MEMORY NODE\nEVENT / NODE RELATION PROJECTION — NO AI INFERENCE',
                  style: TextStyle(color: muted, fontSize: 8, height: 1.8),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEMORY / ${current.id}',
                      style: TextStyle(
                        fontSize: 15,
                        letterSpacing: 1.5,
                        color: memoryColor(current.type),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${current.source}\n${current.date}\nNODE ${current.nodeId ?? '—'} / RELATIONS ${related.length}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: muted,
                        height: 1.7,
                      ),
                    ),
                    Text(
                      current.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                    if (current.nodeId != null)
                      SoftKey(
                        label: 'LOCATE SOURCE >',
                        onPressed: () => widget.locate(current.nodeId!),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MemoryRing extends CustomPainter {
  final List<MemoryRecord> records;
  final String selected;
  final Set<String> relations;
  _MemoryRing({
    required this.records,
    required this.selected,
    required this.relations,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2),
        radius = math.min(size.width * .4, size.height * .4);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .5
      ..color = line;
    canvas.drawCircle(center, radius, pen);
    canvas.drawCircle(
      center,
      radius + 8,
      pen..color = line.withValues(alpha: .4),
    );
    final positions = <String, Offset>{};
    for (var i = 0; i < records.length; i++) {
      final a = i / math.max(1, records.length) * math.pi * 2 - math.pi / 2;
      positions[records[i].id] =
          center + Offset(math.cos(a), math.sin(a)) * radius;
    }
    final current = records.where((r) => r.id == selected).firstOrNull;
    if (current?.nodeId != null) {
      for (final r in records.where((r) => relations.contains(r.id))) {
        final a = positions[current!.id]!, b = positions[r.id]!;
        final path = Path()
          ..moveTo(a.dx, a.dy)
          ..quadraticBezierTo(center.dx, center.dy, b.dx, b.dy);
        canvas.drawPath(
          path,
          pen..color = memoryColor(r.type).withValues(alpha: .6),
        );
      }
    }
    for (var i = 0; i < records.length; i++) {
      final r = records[i], p = positions[r.id]!, active = r.id == selected;
      canvas.drawCircle(
        p,
        active ? 7 : 2.5,
        Paint()..color = memoryColor(r.type).withValues(alpha: active ? 1 : .6),
      );
      if (active) {
        canvas.drawCircle(p, 13, pen..color = ink);
        drawLabel(canvas, r.id, p + const Offset(16, -6), ink, size: 10);
      } else if (i % 7 == 0)
        drawLabel(
          canvas,
          i.toString().padLeft(3, '0'),
          p + const Offset(7, -4),
          muted,
          size: 7,
        );
    }
    drawLabel(
      canvas,
      'RELATION FIELD / ${records.length}',
      Offset(16, size.height - 18),
      muted,
      size: 8,
    );
  }

  @override
  bool shouldRepaint(covariant _MemoryRing oldDelegate) => true;
}
