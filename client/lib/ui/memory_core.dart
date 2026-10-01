import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'instruments.dart';
import 'station.dart';
import 'theme.dart';
import 'terminal_actions.dart';

class MemoryRecord {
  final String id, type, source, date, content;
  final String? nodeId;
  final double? confidence;
  const MemoryRecord({
    required this.id,
    required this.type,
    required this.source,
    required this.date,
    required this.content,
    this.nodeId,
    this.confidence,
  });
}

List<MemoryRecord> memoryRecords(SystemStore store) => [
  for (final event
      in store.logs.where((e) => e['category'] != 'TELEMETRY').take(48))
    MemoryRecord(
      id: 'EVT.${event['cursor']}',
      type:
          event['category'] == 'DEVICE' &&
              (event['message'] as String? ?? '').contains('IDENTIFIED')
          ? 'OBSERVATION'
          : event['category'] == 'SECURITY' ? 'FRAGMENT' : 'EVENT',
      source: event['category'] as String? ?? 'SYSTEM',
      date: event['time'] as String? ?? 'UNKNOWN',
      nodeId: event['node_id'] as String?,
      content: event['message'] as String? ?? '',
      confidence: (event['data']?['confidence'] as num?)?.toDouble(),
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
    type: 'VISUAL',
    source: 'BUNDLED ORIGINAL MOCK SCENE',
    date: 'BUILD ASSET',
    content:
        'Pre-rendered optical simulation. This is an asset reference, not a captured recording.',
  ),
  for (final module in store.nodes.values.where((n) => n.type == 'MODULE'))
    MemoryRecord(id: 'REL.${module.id}', type: 'CONSTRUCTED', source: 'DETERMINISTIC NODE RELATION / NOT AI', date: 'CURRENT STATE', nodeId: module.id,
      content: store.nodes.values.where((n) => n.module == module.id && n.id != module.id).map((n) => n.id).join(' → ')),
];
Color memoryColor(String type) => switch (type) {
  'FRAGMENT' => SamTokens.amber,
  'EVENT' => SamTokens.blue,
  'VISUAL' => const Color(0xffc5b1be),
  'OBSERVATION' => accent,
  'CONSTRUCTED' => critical,
  _ => ink,
};

class MemoryCoreScreen extends StatefulWidget {
  final TerminalActions? actions;
  final ValueChanged<bool>? onOperation;
  final SystemStore store;
  final ValueChanged<String> locate;
  const MemoryCoreScreen({
    super.key,
    required this.store,
    required this.locate,
    this.actions,
    this.onOperation,
  });
  @override
  State<MemoryCoreScreen> createState() => _MemoryCoreScreenState();
}

class _MemoryCoreScreenState extends State<MemoryCoreScreen> with SingleTickerProviderStateMixin {
  bool showRelations = true;
  String query = '', filter = 'ALL', selected = '';
  String previous = '';
  late final reindex = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  void selectMemory(String id) {
    setState(() { previous = selected; selected = id; });
    widget.onOperation?.call(id.isNotEmpty);
    if (MediaQuery.disableAnimationsOf(context)) reindex.value = 1;
    else reindex.forward(from: 0);
  }
  @override
  void dispose() { reindex.dispose(); super.dispose(); }
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
    widget.actions?.bind({
      'OPEN': shown.isEmpty
          ? null
          : () => selectMemory(current?.id ?? shown.first.id),
      'RELATE': current == null
          ? null
          : () => setState(() => showRelations = !showRelations),
      'FILTER': () async {
        final type = await terminalSelect(context, 'MEMORY TYPE', [
          'ALL',
          ...records.map((r) => r.type).toSet(),
        ]);
        if (type != null && mounted) setState(() => filter = type);
        if (mounted && selected.isNotEmpty) selectMemory('');
      },
      'TRACE': current?.nodeId == null
          ? null
          : () => widget.locate(current!.nodeId!),
      if (current != null) 'RETURN': () => selectMemory(''),
    });
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
                'MEM.CORE.00 / INDEX ${shown.length.toString().padLeft(4, '0')}',
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
            onChanged: (v) { setState(() => query = v); if (selected.isNotEmpty) selectMemory(''); },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final type in [
                'ALL',
                'EVENT',
                'OBSERVATION',
                'FRAGMENT',
                'SYSTEM',
                'VISUAL',
                'AUDIO',
                'CONSTRUCTED',
              ])
                SoftKey(
                  label: type,
                  selected: filter == type,
                  color: memoryColor(type),
                  onPressed: type == 'ALL' || records.any((r) => r.type == type)
                      ? () { setState(() => filter = type); if (selected.isNotEmpty) selectMemory(''); }
                      : null,
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (_, box) => AnimatedBuilder(animation: reindex, builder: (_, __) => GestureDetector(
              key: const Key('memory-ring'),
              behavior: HitTestBehavior.opaque,
              onTapUp: (e) {
                final size = Size(box.maxWidth, box.maxHeight);
                final positions = memoryPositions(shown, size, selected, related.map((r) => r.id).toSet());
                final before = memoryPositions(shown, size, previous, const {});
                String? nearest;
                var nearestDistance = 22.0;
                for (var i = 0; i < shown.length; i++) {
                  final p = Offset.lerp(before[shown[i].id], positions[shown[i].id], Curves.easeOut.transform(reindex.value))!;
                  final distance = (p - e.localPosition).distance;
                  if (distance < nearestDistance) {
                    nearest = shown[i].id;
                    nearestDistance = distance;
                  }
                }
                if (nearest != null) selectMemory(nearest!);
              },
              child: CustomPaint(
                size: Size(box.maxWidth, box.maxHeight),
                painter: _MemoryRing(
                  records: shown,
                  selected: selected,
                  previous: previous, progress: reindex.value,
                  relations: showRelations
                      ? related.map((r) => r.id).toSet()
                      : {},
                ),
              ),
            )),
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
                      'SOURCE / ${current.source}\nTIMESTAMP / ${current.date}\nTYPE / ${current.type}\nNODE / ${current.nodeId ?? '—'}   RELATED / ${related.length}\nCONFIDENCE / ${current.confidence?.toStringAsFixed(2) ?? 'NOT SCORED'}',
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
  final String previous;
  final double progress;
  _MemoryRing({
    required this.records,
    required this.selected,
    required this.relations,
    required this.previous, required this.progress,
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
    final positions = memoryPositions(records, size, selected, relations);
    final before = memoryPositions(records, size, previous, const {});
    for (final id in positions.keys) { positions[id] = Offset.lerp(before[id], positions[id], Curves.easeOut.transform(progress))!; }
    final current = records.where((r) => r.id == selected).firstOrNull;
    final byNode = <String, String>{};
    var baseLines = 0;
    for (final record in records) {
      final node = record.nodeId;
      if (node == null) continue;
      final other = byNode[node];
      if (other != null && baseLines++ < 24) {
        canvas.drawLine(positions[other]!, positions[record.id]!, pen..color = memoryColor(record.type).withValues(alpha: .12));
      } else { byNode[node] = record.id; }
    }
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
        active ? 7 : relations.contains(r.id) ? 3.5 : 2.5,
        Paint()..color = memoryColor(r.type).withValues(alpha: active ? 1 : .6),
      );
      if (active) {
        canvas.drawCircle(p, 13, pen..color = ink);
        drawLabel(canvas, r.id, p + Offset(p.dx > center.dx ? -80 : 16, p.dy < 18 ? 16 : -6), ink, size: 9);
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
    final core = TextPainter(text: const TextSpan(text: 'MEMORY CORE\nASSOCIATIVE INDEX', style: TextStyle(fontFamily: 'RobotoMono', fontSize: 8, letterSpacing: 1.3, height: 2, color: muted)), textAlign: TextAlign.center, textDirection: TextDirection.ltr)..layout();
    core.paint(canvas, center - Offset(core.width / 2, core.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MemoryRing oldDelegate) => true;
}

Map<String, Offset> memoryPositions(List<MemoryRecord> records, Size size, String selected, Set<String> relations) {
  final ordered = selected.isEmpty ? records : [
    ...records.where((r) => r.id == selected),
    ...records.where((r) => r.id != selected && relations.contains(r.id)),
    ...records.where((r) => r.id != selected && !relations.contains(r.id)),
  ];
  final center = Offset(size.width / 2, size.height / 2), radius = math.min(size.width * .4, size.height * .4);
  return {for (var i = 0; i < ordered.length; i++) ordered[i].id: center + Offset(math.cos(i / math.max(1, ordered.length) * math.pi * 2 - math.pi / 2), math.sin(i / math.max(1, ordered.length) * math.pi * 2 - math.pi / 2)) * radius};
}
