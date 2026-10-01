import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'instruments.dart';
import 'theme.dart';
export 'spatial_screens.dart';
export 'camera_screen.dart';
export 'alert_screen.dart';

class DevicesScreen extends StatefulWidget {
  final SystemStore store;
  final ValueChanged<String> inspect;
  final ValueChanged<String> locate;
  const DevicesScreen({
    super.key,
    required this.store,
    required this.inspect,
    required this.locate,
  });
  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  String search = '';
  bool system = false;
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final nodes = store.nodes.values
        .where(
          (n) => '${n.id} ${n.subtype} ${n.module}'.toLowerCase().contains(
            search.toLowerCase(),
          ),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: store.tr('SEARCH DEVICES', '搜索设备'),
                  ),
                  onChanged: (v) => setState(() => search = v),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => setState(() => system = !system),
                child: Text(system ? 'SYSTEM' : 'LIST'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              if (system)
                for (final module in [
                  'MOD-01',
                  'MOD-02',
                  'MOD-03',
                  'MOD-04',
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(module, style: const TextStyle(color: accent)),
                  ),
                  for (final n in nodes.where((n) => n.module == module))
                    _row(n.id),
                ]
              else
                for (final n in nodes) _row(n.id),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String id) {
    final n = widget.store.nodes[id]!;
    return ListTile(
      key: ValueKey('device-$id'),
      onTap: () => widget.inspect(id),
      leading: Container(width: 4, height: 30, color: statusColor(n.status)),
      title: Text('$id // ${n.subtype}', style: const TextStyle(fontSize: 12)),
      subtitle: Text(
        '${n.module} / ${n.status} / ${n.telemetry['temperature']} °C',
        style: const TextStyle(color: muted, fontSize: 10),
      ),
      trailing: SoftKey(
        label: 'LOCATE',
        onPressed: () => widget.locate(id),
      ),
    );
  }
}

class LogLines extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  const LogLines(this.logs, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final e in logs)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            '${e['time']}\n${e['category']} // ${e['node_id'] ?? 'CORE'} // ${e['message']}\n${e['actor'] ?? 'SYSTEM'}${e['correlation_id'] == null ? '' : ' / ${e['correlation_id']}'}',
            style: TextStyle(
              fontSize: 10,
              color: e['category'] == 'ALERT' ? warning : muted,
            ),
          ),
        ),
    ],
  );
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
  void initState() {
    super.initState();
    node = widget.nodeId ?? '';
  }

  Future<void> search({bool more = false}) async {
    setState(() => loading = true);
    await report(context, () async {
      final data =
          await widget.store.api.call(
                'GET',
                '/api/logs',
                query: {
                  'q': query,
                  'category': category,
                  'node_id': node,
                  if (since.isNotEmpty) 'since': since,
                  if (until.isNotEmpty) 'until': until,
                  if (more && result?.isNotEmpty == true)
                    'before': '${result!.last['cursor']}',
                },
              )
              as List;
      if (mounted)
        setState(
          () => result = [
            if (more && result != null) ...result!,
            ...data.map((x) => Map<String, dynamic>.from(x as Map)),
          ],
        );
    });
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final live = store.logs
        .where((e) => node.isEmpty || e['node_id'] == node)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'LOG / EVENT TIMELINE',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 200,
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: store.tr('SEARCH', '搜索'),
                ),
                onChanged: (v) => query = v,
              ),
            ),
            SizedBox(
              width: 160,
              child: TextFormField(
                initialValue: node,
                decoration: const InputDecoration(labelText: 'NODE ID'),
                onChanged: (v) => node = v,
              ),
            ),
            DropdownButton<String>(
              value: category,
              items:
                  [
                        '',
                        'SYSTEM',
                        'NETWORK',
                        'DEVICE',
                        'CAMERA',
                        'COMMAND',
                        'ALERT',
                        'SECURITY',
                        'USER',
                        'TELEMETRY',
                      ]
                      .map(
                        (x) => DropdownMenuItem(
                          value: x,
                          child: Text(x.isEmpty ? 'ALL' : x),
                        ),
                      )
                      .toList(),
              onChanged: (v) => setState(() => category = v!),
            ),
            SizedBox(
              width: 220,
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'FROM / ISO-8601 + TIMEZONE',
                ),
                onChanged: (v) => since = v,
              ),
            ),
            SizedBox(
              width: 220,
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'TO / ISO-8601 + TIMEZONE',
                ),
                onChanged: (v) => until = v,
              ),
            ),
            OutlinedButton(
              onPressed: loading ? null : search,
              child: Text(store.tr('QUERY', '查询')),
            ),
            TextButton(
              onPressed: () => setState(() {
                result = null;
                node = widget.nodeId ?? '';
                category = '';
              }),
              child: Text(store.tr('LIVE', '实时')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Panel(
          title: result == null ? 'LIVE STREAM' : 'HISTORY',
          child: LogLines(result ?? live),
        ),
        if (result != null)
          OutlinedButton(
            onPressed: loading ? null : () => search(more: true),
            child: Text(store.tr('LOAD EARLIER', '加载更早记录')),
          ),
      ],
    );
  }
}
