import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'instruments.dart';
import 'theme.dart';

class Inspector extends StatelessWidget {
  final SystemStore store;
  final VoidCallback? openCamera;
  final VoidCallback? openLogs;
  const Inspector({
    super.key,
    required this.store,
    this.openCamera,
    this.openLogs,
  });

  Future<void> control(
    BuildContext context,
    String action,
    Object? value,
  ) async {
    await report(context, () async {
      final request = store.commandRequest(action, value);
      final high =
          ['restart', 'recover', 'disconnect'].contains(action) ||
          action == 'power' && value == false;
      if (high) {
        final prepared = await store.prepare(request);
        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(store.tr('COMMAND REQUEST', '控制请求确认')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${action.toUpperCase()} // ${request['node_id']}',
                    style: const TextStyle(color: warning),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    store.tr(
                      'Affected nodes (including dependencies):',
                      '影响节点（包括依赖设备）：',
                    ),
                  ),
                  Text((prepared['affected_nodes'] as List).join('\n')),
                  const SizedBox(height: 12),
                  Text(
                    store.tr(
                      'Confirmation expires in 60 seconds. Simulated control.',
                      '确认请求 60 秒后失效。本操作控制模拟设备。',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(store.tr('CANCEL', '取消')),
              ),
              OutlinedButton(
                key: const Key('confirm-command'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(store.tr('CONFIRM', '确认执行')),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        request['confirmation_id'] = prepared['confirmation_id'];
      }
      final result = await store.execute(request);
      if (context.mounted) {
        final diagnostic = result['diagnostic'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result['state']} // ${result['error'] ?? result['id']}${diagnostic == null ? '' : '\n$diagnostic'}',
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = store.selected;
    if (n == null)
      return Panel(
        title: store.tr('NODE INSPECTOR', '节点检查器'),
        child: Text(
          store.tr('Select a node or camera target.', '选择拓扑节点或摄像头中的设备。'),
        ),
      );
    final allowed = store.linked && store.canControl && !store.busy;
    return Panel(
      title: 'NODE INSPECTOR // ${n.id}',
      trailing: StatusLamp(n.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(n.name, style: Theme.of(context).textTheme.titleLarge),
          Reading('TYPE', n.subtype),
          Reading('MODULE', n.module),
          Reading('FIRMWARE', n.metadata['firmware'].toString()),
          Reading('UPTIME', '${n.telemetry['uptime']} SEC'),
          Reading('POWER', '${n.telemetry['power']}%'),
          Reading(
            'THERMAL',
            '${n.telemetry['temperature']} °C',
            color: n.fault == 'THERMAL_HIGH' ? warning : ink,
          ),
          Reading('LATENCY', '${n.telemetry['latency']} ms'),
          Reading(
            'ERROR',
            n.fault ?? 'NONE',
            color: n.fault == null ? muted : warning,
          ),
          Reading('VERSION', '${n.version}'),
          Reading(
            'LAST COMMAND',
            n.data['last_command']?.toString().substring(0, 8) ?? '—',
          ),
          const Divider(height: 28),
          Text(
            'OBSERVE  /  IDENTIFY  /  LINK  /  CONTROL',
            style: const TextStyle(fontSize: 9, color: muted),
          ),
          const SizedBox(height: 10),
          Reading(
            'CHANNEL',
            store.connected ? store.stage : 'OFFLINE',
            color: store.linked ? accent : warning,
          ),
          if (!store.connected)
            Text(
              store.tr(
                'Data stale. Reconnect before controlling.',
                '数据已过期。恢复连接后才能操作。',
              ),
              style: const TextStyle(color: warning),
            ),
          if (store.scannedId != n.id)
            OutlinedButton(
              key: const Key('scan-device'),
              onPressed: store.connected && store.stage != 'SCANNING'
                  ? () => report(context, store.scan)
                  : null,
              child: Text(
                store.stage == 'SCANNING'
                    ? 'SCANNING…'
                    : store.tr('SCAN DEVICE', '扫描设备'),
              ),
            ),
          if (store.scannedId == n.id && !store.linked && store.canControl)
            OutlinedButton(
              key: const Key('link-device'),
              onPressed: store.connected && store.stage != 'AUTHENTICATING'
                  ? () => report(context, store.link)
                  : null,
              child: Text(
                store.stage == 'AUTHENTICATING'
                    ? 'AUTHENTICATING…'
                    : store.tr('ESTABLISH LINK', '建立连接'),
              ),
            ),
          if (!store.canControl)
            Text(
              store.tr('OBSERVER // Read-only access', '观察员 // 只读权限'),
              style: const TextStyle(color: muted),
            ),
          if (store.linked) ...[
            const SizedBox(height: 12),
            Text(
              store.tr('CONTROL CHANNEL AVAILABLE', '控制通道已建立'),
              style: const TextStyle(color: accent, fontSize: 11),
            ),
            if (n.capabilities.contains('power'))
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: allowed
                        ? () => control(context, 'power', true)
                        : null,
                    child: Text(store.tr('RESTORE POWER', '恢复供电')),
                  ),
                  OutlinedButton(
                    onPressed: allowed
                        ? () => control(context, 'power', false)
                        : null,
                    child: Text(store.tr('ISOLATE POWER', '隔离供电')),
                  ),
                ],
              ),
            if (n.capabilities.contains('door'))
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: allowed
                        ? () => control(context, 'door', 'open')
                        : null,
                    child: Text(store.tr('OPEN HATCH', '打开门禁')),
                  ),
                  OutlinedButton(
                    onPressed: allowed
                        ? () => control(context, 'door', 'closed')
                        : null,
                    child: Text(store.tr('CLOSE HATCH', '关闭门禁')),
                  ),
                ],
              ),
            if (n.capabilities.contains('brightness'))
              _slider(
                context,
                'brightness',
                0,
                100,
                (n.controls['brightness'] as num).toDouble(),
                allowed,
              ),
            if (n.capabilities.contains('pan'))
              _slider(
                context,
                'pan',
                -90,
                90,
                (n.controls['pan'] as num).toDouble(),
                allowed,
              ),
            if (n.capabilities.contains('tilt'))
              _slider(
                context,
                'tilt',
                -45,
                45,
                (n.controls['tilt'] as num).toDouble(),
                allowed,
              ),
            if (n.capabilities.contains('zoom'))
              _slider(
                context,
                'zoom',
                1,
                4,
                (n.controls['zoom'] as num).toDouble(),
                allowed,
              ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: allowed
                      ? () => control(context, 'diagnostic', null)
                      : null,
                  child: Text(store.tr('DIAGNOSTIC', '诊断')),
                ),
                if (n.capabilities.contains('recover') && n.fault != null)
                  OutlinedButton(
                    key: const Key('recover-device'),
                    onPressed: allowed
                        ? () => control(context, 'recover', null)
                        : null,
                    child: Text(store.tr('RECOVER', '恢复故障')),
                  ),
                if (n.capabilities.contains('restart'))
                  OutlinedButton(
                    onPressed: allowed
                        ? () => control(context, 'restart', null)
                        : null,
                    child: Text(store.tr('RESTART', '重启')),
                  ),
                if (n.capabilities.contains('disconnect'))
                  OutlinedButton(
                    onPressed: allowed
                        ? () => control(
                            context,
                            'disconnect',
                            n.controls['connected'] == true,
                          )
                        : null,
                    child: Text(store.tr('TOGGLE LINK', '切换网络连接')),
                  ),
              ],
            ),
          ],
          const Divider(height: 28),
          Wrap(
            spacing: 8,
            children: [
              if (openCamera != null)
                TextButton(
                  onPressed: openCamera,
                  child: Text(store.tr('OPEN CAMERA', '查看摄像头')),
                ),
              if (openLogs != null)
                TextButton(
                  onPressed: openLogs,
                  child: Text(store.tr('OPEN LOG', '查看日志')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slider(
    BuildContext context,
    String action,
    double min,
    double max,
    double current,
    bool enabled,
  ) => ControlSlider(
    key: ValueKey('${store.selectedId}-$action'),
    label: action.toUpperCase(),
    min: min,
    max: max,
    value: current,
    enabled: enabled,
    onSubmit: (value) => control(context, action, value),
  );
}

class ControlSlider extends StatefulWidget {
  final String label;
  final double min, max, value;
  final bool enabled;
  final ValueChanged<double> onSubmit;
  const ControlSlider({
    super.key,
    required this.label,
    required this.min,
    required this.max,
    required this.value,
    required this.enabled,
    required this.onSubmit,
  });
  @override
  State<ControlSlider> createState() => _ControlSliderState();
}

class _ControlSliderState extends State<ControlSlider> {
  double? draft;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Reading(widget.label, (draft ?? widget.value).toStringAsFixed(1)),
      Slider(
        min: widget.min,
        max: widget.max,
        value: (draft ?? widget.value).clamp(widget.min, widget.max).toDouble(),
        onChanged: widget.enabled ? (v) => setState(() => draft = v) : null,
        onChangeEnd: widget.enabled
            ? (v) {
                widget.onSubmit(v);
                setState(() => draft = null);
              }
            : null,
      ),
    ],
  );
}
