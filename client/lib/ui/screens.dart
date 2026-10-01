import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'camera_display.dart';
import 'instruments.dart';
import 'map_display.dart';
import 'theme.dart';

class OverviewScreen extends StatelessWidget {
  final SystemStore store;
  final ValueChanged<String> locate;
  final VoidCallback openMap;
  const OverviewScreen({super.key, required this.store, required this.locate, required this.openMap});
  @override
  Widget build(BuildContext context) {
    final nodes = store.nodes.values.toList();
    final active = store.alerts.where((a) => a['state'] != 'RESOLVED').toList();
    final cameras = nodes.where((n) => n.type == 'CAMERA').toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('SYSTEM OVERVIEW', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6), Text(store.tr('ONE FACILITY / 42 NODES / SHARED CONTROL', '单设施 / 42 节点 / 团队共享控制'), style: const TextStyle(color: muted, fontSize: 10)),
      const SizedBox(height: 20),
      Panel(title: 'FACILITY // LIVE STATE', trailing: TextButton(onPressed: openMap, child: Text(store.tr('EXPAND', '展开'))),
        padding: EdgeInsets.zero, child: SizedBox(height: 300, child: FittedBox(alignment: Alignment.topLeft, fit: BoxFit.contain,
          child: SizedBox(width: mapSize.width, height: mapSize.height,
            child: GestureDetector(onTapUp: (tap) {
              final positions = nodePositions(store.nodes.values, false);
              for (final entry in positions.entries) {
                if ((entry.value - tap.localPosition).distance < 35) { locate(entry.key); break; }
              }
            }, child: CustomPaint(painter: MapPainter(store: store, positions: nodePositions(store.nodes.values, false), network: false))))))),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (_, constraints) {
        final wide = constraints.maxWidth > 650;
        final summary = Panel(title: 'SYSTEM READINGS', child: Column(children: [
          Reading('CORE', store.connected ? 'ONLINE' : 'DISCONNECTED', color: store.connected ? accent : warning),
          Reading('NETWORK', '${nodes.where((n) => n.status != 'OFFLINE').length} / ${nodes.length} ONLINE'),
          Reading('CAMERA', '${cameras.where((n) => n.status != 'OFFLINE').length} / ${cameras.length} ONLINE'),
          Reading('POWER', nodes.isEmpty ? '—' : '${nodes.first.telemetry['power']}%'),
          Reading('SIMULATOR', store.paused ? 'PAUSED' : 'ACTIVE'),
          Reading('ALERTS', '${active.length} ACTIVE', color: active.isEmpty ? accent : warning),
        ]));
        final alerts = Panel(title: 'PRIORITY EVENTS', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (active.isEmpty) Text(store.tr('No active fault conditions.', '当前没有活动故障。'), style: const TextStyle(color: muted)),
          for (final a in active.take(4)) TextButton(onPressed: () => locate(a['node_id'] as String),
            style: TextButton.styleFrom(alignment: Alignment.centerLeft),
            child: Text('${a['severity']} // ${a['node_id']}\n${a['condition']}', style: TextStyle(color: statusColor(a['severity'] as String), fontSize: 11))),
        ]));
        return wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: summary), const SizedBox(width: 12), Expanded(child: alerts)])
          : Column(children: [summary, const SizedBox(height: 12), alerts]);
      }),
      const SizedBox(height: 12), Panel(title: 'RECENT EVENT STREAM', child: LogLines(store.logs.take(8).toList())),
    ]);
  }
}

class MapScreen extends StatefulWidget {
  final SystemStore store;
  final ValueChanged<String> inspect;
  const MapScreen({super.key, required this.store, required this.inspect});
  @override
  State<MapScreen> createState() => _MapScreenState();
}
class _MapScreenState extends State<MapScreen> {
  bool network = false;
  String filter = 'ALL', search = '';
  String? focused;
  final transform = TransformationController();
  @override
  void dispose() { transform.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final matches = store.nodes.values.where((n) => (filter == 'ALL' || n.type == filter) && (search.isEmpty || '${n.id} ${n.name} ${n.subtype}'.toLowerCase().contains(search.toLowerCase()))).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        OutlinedButton(onPressed: () => setState(() { network = false; focused = null; }), child: Text(store.tr('FACILITY', '设施视图'), style: TextStyle(color: !network ? accent : muted))),
        OutlinedButton(onPressed: () => setState(() { network = true; focused = null; }), child: Text(store.tr('NETWORK', '网络视图'), style: TextStyle(color: network ? accent : muted))),
        DropdownButton<String>(value: filter, items: ['ALL', 'CAMERA', 'DEVICE', 'SENSOR', 'SERVER', 'ROBOT', 'NETWORK', 'MODULE'].map((x) => DropdownMenuItem(value: x, child: Text(x, style: const TextStyle(fontSize: 11)))).toList(), onChanged: (v) => setState(() => filter = v!)),
        SizedBox(width: 210, child: TextField(key: const Key('node-search'), decoration: InputDecoration(labelText: store.tr('SEARCH NODE', '搜索节点'), isDense: true),
          onChanged: (v) => setState(() => search = v), onSubmitted: (_) { if (matches.isNotEmpty) widget.inspect(matches.first.id); })),
        OutlinedButton(onPressed: () { focused = null; transform.value = Matrix4.identity()..scale(.5); }, child: Text(store.tr('FIT', '复位'))),
      ])),
      if (search.isNotEmpty) SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, children: [for (final n in matches) TextButton(onPressed: () => widget.inspect(n.id), child: Text(n.id))])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Row(children: [
        Expanded(child: Text(network ? 'NETWORK: BLUE-GREY / POWER: AMBER / FAULT: RED' : 'SPACE / CAMERA COVERAGE / DEVICE LOCATION', style: const TextStyle(color: muted, fontSize: 8))),
        Text('${matches.length} NODES', style: const TextStyle(color: accent, fontSize: 9)),
      ])),
      Expanded(child: LayoutBuilder(builder: (context, constraints) {
        if (focused != store.selectedId || transform.value.isIdentity()) {
          focused = store.selectedId;
          final pos = nodePositions(store.nodes.values, network)[focused];
          final scale = pos == null ? (constraints.maxWidth / mapSize.width).clamp(.25, .75) : .8;
          final center = pos ?? const Offset(600, 400);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) transform.value = Matrix4.identity()..translate(constraints.maxWidth / 2 - center.dx * scale, constraints.maxHeight / 2 - center.dy * scale)..scale(scale);
          });
        }
        return MapDisplay(store: store, network: network, controller: transform,
          visible: search.isEmpty && filter == 'ALL' ? null : matches.map((n) => n.id).toSet(), onSelect: widget.inspect);
      })),
      if (store.selected != null) ListTile(dense: true, title: Text('${store.selectedId} // ${store.selected!.subtype}', style: const TextStyle(fontSize: 11)),
        subtitle: Text('${store.selected!.status} / ${store.selected!.module}', style: const TextStyle(fontSize: 9)),
        trailing: OutlinedButton(onPressed: () => widget.inspect(store.selectedId!), child: Text(store.tr('INSPECT', '检查')))),
    ]);
  }
}

class CameraScreen extends StatelessWidget {
  final SystemStore store;
  final ValueChanged<String> inspect;
  const CameraScreen({super.key, required this.store, required this.inspect});
  @override
  Widget build(BuildContext context) {
    final cameras = store.nodes.values.where((n) => n.type == 'CAMERA').toList();
    final camera = store.nodes[store.cameraId] ?? (cameras.isEmpty ? null : cameras.first);
    if (camera == null) return const Center(child: Text('CAMERA UNAVAILABLE'));
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: DropdownButton<String>(isExpanded: true, value: camera.id,
          items: cameras.map((n) => DropdownMenuItem(value: n.id, child: Text('${n.id} / ${n.module} / ${n.status}', style: const TextStyle(fontSize: 11)))).toList(),
          onChanged: store.setCamera)),
        const SizedBox(width: 8), OutlinedButton(onPressed: () => inspect(camera.id), child: Text(store.tr('CAM CONTROL', '云台控制'))),
      ])),
      Expanded(child: CameraDisplay(store: store, cameraId: camera.id, onTarget: inspect)),
      Padding(padding: const EdgeInsets.all(12), child: Text(store.tr('SELECT TARGET → SCAN → LINK → CONTROL // SIMULATED VISION', '选择画面目标 → 扫描 → 连接 → 控制 // 模拟视觉'), style: const TextStyle(fontSize: 9, color: muted))),
    ]);
  }
}

class DevicesScreen extends StatefulWidget {
  final SystemStore store;
  final ValueChanged<String> inspect;
  final ValueChanged<String> locate;
  const DevicesScreen({super.key, required this.store, required this.inspect, required this.locate});
  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}
class _DevicesScreenState extends State<DevicesScreen> {
  String search = '';
  bool system = false;
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final nodes = store.nodes.values.where((n) => '${n.id} ${n.subtype} ${n.module}'.toLowerCase().contains(search.toLowerCase())).toList();
    return Column(children: [Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Expanded(child: TextField(decoration: InputDecoration(labelText: store.tr('SEARCH DEVICES', '搜索设备')), onChanged: (v) => setState(() => search = v))),
      const SizedBox(width: 8), OutlinedButton(onPressed: () => setState(() => system = !system), child: Text(system ? 'SYSTEM' : 'LIST')),
    ])), Expanded(child: ListView(children: [
      if (system) for (final module in ['MOD-01', 'MOD-02', 'MOD-03', 'MOD-04']) ...[
        Padding(padding: const EdgeInsets.all(16), child: Text(module, style: const TextStyle(color: accent))),
        for (final n in nodes.where((n) => n.module == module)) _row(n.id),
      ] else for (final n in nodes) _row(n.id),
    ]))]);
  }
  Widget _row(String id) {
    final n = widget.store.nodes[id]!;
    return ListTile(key: ValueKey('device-$id'), onTap: () => widget.inspect(id),
      leading: Container(width: 4, height: 30, color: statusColor(n.status)),
      title: Text('$id // ${n.subtype}', style: const TextStyle(fontSize: 12)),
      subtitle: Text('${n.module} / ${n.status} / ${n.telemetry['temperature']} °C', style: const TextStyle(color: muted, fontSize: 10)),
      trailing: IconButton(tooltip: widget.store.tr('Locate node', '定位节点'), onPressed: () => widget.locate(id), icon: const Icon(Icons.my_location, size: 18)));
  }
}

class AlertsScreen extends StatefulWidget {
  final SystemStore store;
  final ValueChanged<String> locate, camera, inspect, logs;
  const AlertsScreen({super.key, required this.store, required this.locate, required this.camera, required this.inspect, required this.logs});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}
class _AlertsScreenState extends State<AlertsScreen> {
  bool history = false;
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final alerts = store.alerts.where((a) => history || a['state'] != 'RESOLVED').toList().reversed.toList();
    alerts.sort((a, b) => (a['severity'] == 'CRITICAL' ? 0 : 1).compareTo(b['severity'] == 'CRITICAL' ? 0 : 1));
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [Expanded(child: Text('SYSTEM ALERTS', style: Theme.of(context).textTheme.titleLarge)),
        TextButton(onPressed: () => setState(() => history = !history), child: Text(history ? store.tr('ACTIVE ONLY', '仅活动告警') : store.tr('HISTORY', '包含历史')))]),
      Text(store.tr('ACKNOWLEDGED ≠ RESOLVED / recovery follows the fault condition', '确认收到 ≠ 故障解决 / 故障条件消失后自动解决'), style: const TextStyle(color: muted, fontSize: 10)),
      const SizedBox(height: 16),
      if (alerts.isEmpty) Panel(title: 'NO ACTIVE ALERTS', child: Text(store.tr('Facility conditions are nominal.', '设施当前运行正常。'))),
      for (final a in alerts) Padding(padding: const EdgeInsets.only(bottom: 12), child: Panel(title: '${a['severity']} // ${a['node_id']}', trailing: StatusLamp(a['state'] as String),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(a['condition'] as String, style: TextStyle(color: statusColor(a['severity'] as String))),
          Reading('CREATED', a['created_at'] as String), Reading('OPERATOR', a['acknowledged_by'] as String? ?? 'UNASSIGNED'),
          if (a['resolved_at'] != null) Reading('RESOLVED', a['resolved_at'] as String),
          Wrap(spacing: 4, children: [
            TextButton(key: ValueKey('locate-${a['node_id']}'), onPressed: () => widget.locate(a['node_id'] as String), child: Text(store.tr('LOCATE', '定位节点'))),
            TextButton(onPressed: () => widget.camera(a['node_id'] as String), child: Text(store.tr('CAMERA', '摄像头'))),
            TextButton(onPressed: () => widget.inspect(a['node_id'] as String), child: Text(store.tr('INSPECT', '检查设备'))),
            TextButton(onPressed: () => widget.logs(a['node_id'] as String), child: Text(store.tr('LOG', '日志'))),
            if (a['state'] == 'ACTIVE') OutlinedButton(onPressed: store.canControl && store.connected ? () => report(context, () => store.acknowledge(a['id'] as String)) : null, child: Text(store.tr('ACKNOWLEDGE', '确认收到'))),
          ]),
        ]))),
    ]);
  }
}

class LogLines extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  const LogLines(this.logs, {super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    for (final e in logs) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(
      '${e['time']}\n${e['category']} // ${e['node_id'] ?? 'CORE'} // ${e['message']}\n${e['actor'] ?? 'SYSTEM'}${e['correlation_id'] == null ? '' : ' / ${e['correlation_id']}'}',
      style: TextStyle(fontSize: 10, color: e['category'] == 'ALERT' ? warning : muted))),
  ]);
}

class LogsScreen extends StatefulWidget {
  final SystemStore store;
  final String? nodeId;
  const LogsScreen({super.key, required this.store, this.nodeId});
  @override
  State<LogsScreen> createState() => _LogsScreenState();
}
class _LogsScreenState extends State<LogsScreen> {
  String category = '', query = '', node = '', since = '', until = '';
  List<Map<String, dynamic>>? result;
  bool loading = false;
  @override
  void initState() { super.initState(); node = widget.nodeId ?? ''; }
  Future<void> search({bool more = false}) async {
    setState(() => loading = true);
    await report(context, () async {
      final data = await widget.store.api.call('GET', '/api/logs', query: {
        'q': query, 'category': category, 'node_id': node,
        if (since.isNotEmpty) 'since': since, if (until.isNotEmpty) 'until': until,
        if (more && result?.isNotEmpty == true) 'before': '${result!.last['cursor']}',
      }) as List;
      if (mounted) setState(() => result = [...if (more && result != null) result!, ...data.map((x) => Map<String, dynamic>.from(x as Map))]);
    });
    if (mounted) setState(() => loading = false);
  }
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final live = store.logs.where((e) => node.isEmpty || e['node_id'] == node).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('LOG / EVENT TIMELINE', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 200, child: TextFormField(decoration: InputDecoration(labelText: store.tr('SEARCH', '搜索')), onChanged: (v) => query = v)),
        SizedBox(width: 160, child: TextFormField(initialValue: node, decoration: const InputDecoration(labelText: 'NODE ID'), onChanged: (v) => node = v)),
        DropdownButton<String>(value: category, items: ['', 'SYSTEM', 'NETWORK', 'COMMAND', 'ALERT', 'SECURITY', 'USER', 'TELEMETRY'].map((x) => DropdownMenuItem(value: x, child: Text(x.isEmpty ? 'ALL' : x))).toList(), onChanged: (v) => setState(() => category = v!)),
        SizedBox(width: 220, child: TextFormField(decoration: const InputDecoration(labelText: 'FROM / ISO-8601 + TIMEZONE'), onChanged: (v) => since = v)),
        SizedBox(width: 220, child: TextFormField(decoration: const InputDecoration(labelText: 'TO / ISO-8601 + TIMEZONE'), onChanged: (v) => until = v)),
        OutlinedButton(onPressed: loading ? null : search, child: Text(store.tr('QUERY', '查询'))),
        TextButton(onPressed: () => setState(() { result = null; node = widget.nodeId ?? ''; category = ''; }), child: Text(store.tr('LIVE', '实时'))),
      ]),
      const SizedBox(height: 16), Panel(title: result == null ? 'LIVE STREAM' : 'HISTORY', child: LogLines(result ?? live)),
      if (result != null) OutlinedButton(onPressed: loading ? null : () => search(more: true), child: Text(store.tr('LOAD EARLIER', '加载更早记录'))),
    ]);
  }
}
