import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'instruments.dart';
import 'station.dart';
import 'theme.dart';
import 'terminal_actions.dart';

class AlertsScreen extends StatefulWidget {
  final TerminalActions? actions;
  final SystemStore store;
  final ValueChanged<String> locate, camera, inspect, logs;
  const AlertsScreen({
    super.key,
    required this.store,
    required this.locate,
    required this.camera,
    required this.inspect,
    required this.logs,
    this.actions,
  });
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool history = false;
  String? selected;
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final alerts =
        store.alerts.where((a) => history || a['state'] != 'RESOLVED').toList()
          ..sort(
            (a, b) => (a['severity'] == 'CRITICAL' ? 0 : 1).compareTo(
              b['severity'] == 'CRITICAL' ? 0 : 1,
            ),
          );
    final alert = alerts.isEmpty
        ? null
        : alerts.firstWhere(
            (a) => a['id'] == selected,
            orElse: () => alerts.first,
          );
    final node = alert == null ? null : store.nodes[alert['node_id']];
    widget.actions?.bind({
      'LOCATE': alert == null
          ? null
          : () => widget.locate(alert['node_id'] as String),
      'CAMERA': alert == null
          ? null
          : () => widget.camera(alert['node_id'] as String),
      'LINK': alert == null
          ? null
          : () => widget.inspect(alert['node_id'] as String),
      'ACK': alert?['state'] == 'ACTIVE' && store.canControl && store.connected
          ? () =>
                report(context, () => store.acknowledge(alert!['id'] as String))
          : null,
      'LOG': alert == null
          ? null
          : () => widget.logs(alert['node_id'] as String),
      'HISTORY': () => setState(() => history = !history),
    });
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _WatchAxis(store: store)),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'SYSTEM / ANOMALY ANALYSIS',
                      style: TextStyle(
                        fontFamily: 'RobotoCondensed',
                        fontSize: 15,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  SoftKey(
                    label: history ? 'ACTIVE' : 'HISTORY',
                    onPressed: () => setState(() => history = !history),
                  ),
                ],
              ),
            ),
            if (alert == null)
              Expanded(child: _Standby(store: store))
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        children: [
                          for (var i = 0; i < alerts.length; i++)
                            SoftKey(
                              key: ValueKey('alert-${alerts[i]['id']}'),
                              code: (i + 1).toString().padLeft(2, '0'),
                              label: alerts[i]['severity'] as String,
                              selected: alerts[i]['id'] == alert['id'],
                              color: statusColor(
                                alerts[i]['severity'] as String,
                              ),
                              onPressed: () => setState(
                                () => selected = alerts[i]['id'] as String,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'SYS ALERT / ${(alerts.indexOf(alert) + 1).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: muted,
                          fontSize: 10,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        (alert['condition'] as String).replaceAll('_', ' '),
                        style: TextStyle(
                          fontFamily: 'RobotoCondensed',
                          fontSize: 28,
                          letterSpacing: 2,
                          color: statusColor(alert['severity'] as String),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${node?.module ?? 'UNKNOWN'} / ${alert['node_id']}',
                        style: const TextStyle(
                          fontSize: 13,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _FaultPath(
                            store: store,
                            nodeId: alert['node_id'] as String,
                          ),
                        ),
                      ),
                      Reading('STATE', alert['state'] as String),
                      Reading(
                        'OPERATOR',
                        alert['acknowledged_by'] as String? ?? 'UNASSIGNED',
                      ),
                      Text(
                        alert['created_at'] as String,
                        style: const TextStyle(color: muted, fontSize: 8),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'ACK ≠ RESOLVE / CONDITION-DRIVEN RECOVERY',
                        style: TextStyle(color: muted, fontSize: 8),
                      ),
                      const Divider(height: 28),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Standby extends StatelessWidget {
  final SystemStore store;
  const _Standby({required this.store});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) => Stack(
      children: [
        Positioned(
          left: 18,
          top: 10,
          child: Text(
            'ALERT CHANNEL\nSTATUS / ${store.connected ? 'ARMED' : 'STALE'}\nSYS.ALERT.00 / WATCH ${store.paused ? 'HOLD' : 'ACTIVE'}',
            style: const TextStyle(
              fontSize: 9,
              color: muted,
              height: 2,
              letterSpacing: 1,
            ),
          ),
        ),
        Positioned(
          left: 35,
          top: box.maxHeight * .27,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '00',
                style: TextStyle(
                  fontFamily: 'RobotoCondensed',
                  fontSize: 72,
                  color: ink,
                  fontWeight: FontWeight.w200,
                ),
              ),
              Text(
                'ACTIVE ALERTS',
                style: TextStyle(fontSize: 9, letterSpacing: 2, color: muted),
              ),
            ],
          ),
        ),
        Positioned(
          right: 24,
          top: box.maxHeight * .37,
          child: const Text(
            'CRITICAL 000\nWARNING  000\nADVISORY 000',
            style: TextStyle(fontSize: 9, height: 2.2, color: muted),
          ),
        ),
        Positioned(
          left: 18,
          bottom: 62,
          child: Text(
            'MONITORING / ${store.nodes.length} NODES\n\nWATCH CHANNELS\nPWR BUS / ENVIRONMENT\nNETWORK / CAM ARRAY / SECURITY',
            style: const TextStyle(
              fontSize: 8,
              height: 2,
              letterSpacing: 1,
              color: muted,
            ),
          ),
        ),
        const Positioned(
          left: 18,
          bottom: 14,
          child: Text(
            'SYS > ALERT CHANNEL / STANDBY\nNO CURRENT EXCEPTIONS',
            style: TextStyle(fontSize: 9, color: accent, height: 1.8),
          ),
        ),
      ],
    ),
  );
}

class _WatchAxis extends CustomPainter {
  final SystemStore store;
  _WatchAxis({required this.store});
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = accent.withValues(alpha: .09)
      ..strokeWidth = .6;
    final x = size.width * .61;
    canvas.drawLine(Offset(x, 32), Offset(x, size.height - 30), pen);
    for (double y = 46; y < size.height - 30; y += 22) {
      canvas.drawLine(Offset(x - 4, y), Offset(x + 8, y), pen);
    }
    for (var i = 0; i < 4; i++) {
      final y = 80 + (size.height - 190) * i / 4;
      canvas.drawLine(Offset(x, y), Offset(size.width - 18, y), pen);
      drawLabel(
        canvas,
        'MOD-0${i + 1}',
        Offset(x + 12, y + 5),
        accent.withValues(alpha: .13),
        size: 8,
      );
    }
    for (var i = 0; i < store.displayEvents.length; i++) {
      canvas.drawCircle(
        Offset(x, size.height * .2 + i * 38),
        2,
        Paint()..color = accent.withValues(alpha: .16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WatchAxis oldDelegate) => true;
}

class _FaultPath extends CustomPainter {
  final SystemStore store;
  final String nodeId;
  _FaultPath({required this.store, required this.nodeId});
  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(32, size.height * .4);
    final targets = store.edges
        .where((e) => e['source'] == nodeId)
        .map((e) => e['target'] as String)
        .toSet()
        .take(5)
        .toList();
    final pen = Paint()
      ..color = critical.withValues(alpha: .6)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(origin, 9, pen);
    drawLabel(
      canvas,
      nodeId,
      origin + const Offset(-15, 22),
      critical,
      size: 10,
    );
    drawLabel(canvas, 'FAULT SOURCE', const Offset(0, 0), muted, size: 8);
    for (var i = 0; i < targets.length; i++) {
      final p = Offset(size.width * .64, 22 + i * 29);
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(size.width * .32, origin.dy)
        ..lineTo(size.width * .32, p.dy)
        ..lineTo(p.dx, p.dy);
      canvas.drawPath(path, pen);
      canvas.drawCircle(
        p,
        3,
        Paint()
          ..color = statusColor(store.nodes[targets[i]]?.status ?? 'UNKNOWN'),
      );
      drawLabel(canvas, targets[i], p + const Offset(9, -5), muted, size: 9);
    }
    if (targets.isEmpty)
      drawLabel(
        canvas,
        'LOCAL CONDITION / NO DOWNSTREAM PATH',
        const Offset(70, 65),
        muted,
        size: 9,
      );
  }

  @override
  bool shouldRepaint(covariant _FaultPath oldDelegate) => true;
}
