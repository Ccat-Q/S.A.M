import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'instruments.dart';
import 'station.dart';
import 'theme.dart';
import 'terminal_actions.dart';

String alertTime(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toUtc();
  return date == null
      ? '--:--:--'
      : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
}

Color alertInk(Map<String, dynamic> a) => a['state'] == 'RESOLVED'
    ? muted
    : a['severity'] == 'CRITICAL'
    ? critical
    : warning;

class AlertsScreen extends StatefulWidget {
  final TerminalActions? actions;
  final ValueChanged<bool>? onOperation;
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
    this.onOperation,
  });
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool history = false, detail = false;
  String? selected;
  void choose(String id) {
    setState(() {
      selected = id;
      detail = true;
    });
    widget.onOperation?.call(true);
  }

  void register() {
    setState(() {
      selected = null;
      detail = false;
    });
    widget.onOperation?.call(false);
  }

  void toggleHistory() {
    setState(() {
      history = !history;
      selected = null;
      detail = false;
    });
    widget.onOperation?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final active = store.alerts.where((a) => a['state'] != 'RESOLVED').toList()
      ..sort(
        (a, b) => (a['severity'] == 'CRITICAL' ? 0 : 1).compareTo(
          b['severity'] == 'CRITICAL' ? 0 : 1,
        ),
      );
    final events = [...store.alerts]
      ..sort(
        (a, b) =>
            (b['created_at'] as String).compareTo(a['created_at'] as String),
      );
    final candidates = history ? events : active;
    final alert =
        candidates.where((a) => a['id'] == selected).firstOrNull ??
        candidates.firstOrNull;
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
          : () {
              SystemMessages.shared.emit('LINK REQUEST / ${alert['node_id']}');
              widget.inspect(alert['node_id'] as String);
            },
      'ACK': alert?['state'] == 'ACTIVE' && store.canControl && store.connected
          ? () =>
                report(context, () => store.acknowledge(alert!['id'] as String))
          : null,
      'HISTORY': toggleHistory,
    });
    final number = active.length.toString().padLeft(3, '0');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'SYSTEM / ANOMALY ANALYSIS',
                  style: TextStyle(
                    fontFamily: 'RobotoCondensed',
                    fontSize: 14,
                    letterSpacing: 1.7,
                  ),
                ),
              ),
              SoftKey(
                key: const Key('alert-register-return'),
                label: detail
                    ? 'RETURN'
                    : history
                    ? 'ACTIVE'
                    : 'HISTORY',
                onPressed: detail ? register : toggleHistory,
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (_, box) {
              final wide = box.maxWidth >= 700;
              final leftWidth = box.maxWidth * (wide ? .44 : .52);
              final matrixWidth = box.maxWidth * (wide ? .46 : .43);
        final visibleEvents = events;
              return Stack(
                children: [
                  Positioned(
                    left: 18,
                    top: 5,
                    child: Text(
                      'ALERT CHANNEL\nSTATUS / ${store.connected ? 'ARMED' : 'STALE'}\nSYS.ALERT.00 / WATCH ${store.paused ? 'HOLD' : 'ACTIVE'}',
                      style: const TextStyle(
                        fontSize: 8,
                        color: muted,
                        height: 1.9,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 91,
                    width: leftWidth,
                    bottom: 105,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ALERT REGISTER',
                            style: TextStyle(
                              fontSize: 9,
                              color: muted,
                              letterSpacing: 1.7,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            number,
                            key: const Key('alert-register-count'),
                            style: TextStyle(
                              fontSize: 32,
                              color: active.isEmpty
                                  ? ink
                                  : alertInk(active.first),
                              letterSpacing: 5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (alert == null)
                            const Text(
                              'NO ACTIVE EXCEPTIONS',
                              style: TextStyle(
                                fontSize: 8,
                                color: accent,
                                height: 1.8,
                                letterSpacing: .6,
                              ),
                            )
                          else ...[
                            Text(
                              '${alert['state'] == 'RESOLVED' ? 'HISTORY / ' : ''}${alert['severity']}',
                              style: TextStyle(
                                fontSize: 10,
                                color: alertInk(alert),
                                letterSpacing: 1.7,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              (alert['condition'] as String).replaceAll(
                                '_',
                                ' ',
                              ),
                              style: TextStyle(
                                fontFamily: 'RobotoCondensed',
                                fontSize: wide ? 24 : 20,
                                color: alertInk(alert),
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 17),
                            Text(
                              'SOURCE / ${alert['node_id']}\nMODULE / ${node?.module ?? 'UNKNOWN'}\nTIME / ${alertTime(alert['created_at'])}\nSTATE / ${alert['state']}',
                              style: const TextStyle(
                                fontSize: 9,
                                height: 2,
                                color: muted,
                              ),
                            ),
                            if (alert['source'] == 'MOCK_HISTORY')
                              Text(
                                'MOCK HISTORY / ${alert['resolution']}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  height: 2,
                                  color: muted,
                                ),
                              ),
                            if (alert['state'] != 'RESOLVED')
                              SizedBox(
                                height: 180,
                                child: CustomPaint(
                                  painter: _FaultPath(
                                    store: store,
                                    nodeId: alert['node_id'] as String,
                                  ),
                                ),
                              ),
                            if (detail) ...[
                              Text(
                                'OPERATOR / ${alert['acknowledged_by'] ?? 'UNASSIGNED'}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: muted,
                                ),
                              ),
                              SoftKey(
                                label: 'OPEN AUDIT LOG',
                                onPressed: () =>
                                    widget.logs(alert['node_id'] as String),
                              ),
                            ],
                            const SizedBox(height: 9),
                            const Text(
                              'ACK ≠ RESOLVE\nCONDITION-DRIVEN RECOVERY',
                              style: TextStyle(
                                fontSize: 7,
                                color: muted,
                                height: 1.8,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 30,
                    width: matrixWidth,
                    child: Text(
                      'QUEUE / $number\nUNACK / ${active.where((a) => a['state'] == 'ACTIVE').length.toString().padLeft(3, '0')}\nLAST EVENT / ${alertTime(events.firstOrNull?['created_at'])}',
                      style: const TextStyle(
                        fontSize: 8,
                        height: 2.2,
                        color: muted,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 145,
                    width: matrixWidth,
                    bottom: 105,
                    child: AnomalyMatrix(
                      store: store,
                      events: visibleEvents,
                      selected: alert?['id'] as String?,
                      onSelect: (id) {
                        setState(() => history = true);
                        choose(id);
                      },
                    ),
                  ),
                  Positioned(
                    left: 18,
                    bottom: 18,
                    child: Text(
                      'MONITORING / ${store.nodes.length} NODES\nWATCH CHANNELS\nPWR BUS / ENVIRONMENT\nNETWORK / CAM ARRAY / SECURITY',
                      style: const TextStyle(
                        fontSize: 8,
                        height: 1.9,
                        letterSpacing: .5,
                        color: muted,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 22,
                    width: matrixWidth,
                    child: Text(
                      active.isEmpty
                          ? 'SYS > CHANNEL\nSTANDBY'
                          : 'SYS > EXCEPTION\nWATCH / ACTIVE',
                      style: TextStyle(
                        fontSize: 8,
                        height: 1.8,
                        color: active.isEmpty ? muted : alertInk(active.first),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class AnomalyMatrix extends StatelessWidget {
  final SystemStore store;
  final List<Map<String, dynamic>> events;
  final String? selected;
  final ValueChanged<String> onSelect;
  const AnomalyMatrix({
    super.key,
    required this.store,
    required this.events,
    required this.selected,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final contentHeight = math.max(box.maxHeight, events.length * 26.0 + 64);
      return SingleChildScrollView(child: SizedBox(
        height: contentHeight,
        child: GestureDetector(
      key: const Key('anomaly-matrix'),
      behavior: HitTestBehavior.opaque,
      onTapUp: (e) {
        final height = math.max(1.0, contentHeight - 64);
        final row =
            ((e.localPosition.dy - 48) / (height / math.max(1, events.length)))
                .round();
        if (row >= 0 && row < events.length)
          onSelect(events[row]['id'] as String);
      },
      child: CustomPaint(
        size: Size(box.maxWidth, contentHeight),
        painter: _AnomalyMatrixPainter(store, events, selected),
      ),
    )));
    },
  );
}

class _AnomalyMatrixPainter extends CustomPainter {
  final SystemStore store;
  final List<Map<String, dynamic>> events;
  final String? selected;
  _AnomalyMatrixPainter(this.store, this.events, this.selected);
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..strokeWidth = .6
      ..style = PaintingStyle.stroke;
    drawLabel(canvas, 'TIME × MODULE / HISTORY', Offset.zero, muted, size: 7);
    const origin = 35.0;
    final step = (size.width - origin - 6) / 4;
    for (var i = 0; i < 4; i++) {
      final x = origin + (i + .5) * step;
      drawLabel(canvas, 'MOD\n0${i + 1}', Offset(x - 7, 17), muted, size: 6);
      canvas.drawLine(
        Offset(x, 39),
        Offset(x, size.height - 6),
        pen..color = accent.withValues(alpha: .12),
      );
    }
    if (events.isEmpty)
      drawLabel(canvas, 'NO RECORDS', const Offset(0, 54), muted, size: 7);
    for (var i = 0; i < events.length; i++) {
      final a = events[i], active = a['id'] == selected;
      final y =
          48 + i * math.max(1.0, size.height - 64) / math.max(1, events.length);
      final module = store.nodes[a['node_id']]?.module;
      final index = int.tryParse(module?.split('-').last ?? '') ?? 1;
      final point = Offset(origin + (index - .5) * step, y);
      final color = alertInk(a).withValues(
        alpha: active
            ? .95
            : a['state'] == 'RESOLVED'
            ? .55
            : .8,
      );
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        pen..color = color.withValues(alpha: active ? .3 : .1),
      );
      drawLabel(
        canvas,
        alertTime(a['created_at']).substring(0, 5),
        Offset(0, y - 4),
        color,
        size: 6,
      );
      pen.color = color;
      if (a['severity'] == 'CRITICAL') {
        canvas.drawPath(
          Path()
            ..moveTo(point.dx, y - 4)
            ..lineTo(point.dx - 4, y + 3)
            ..lineTo(point.dx + 4, y + 3)
            ..close(),
          pen,
        );
      } else if (a['condition'].toString().contains('SIGNAL')) {
        canvas.drawRect(
          Rect.fromCenter(center: point, width: 5, height: 5),
          pen,
        );
      } else
        canvas.drawCircle(point, 2, Paint()..color = color);
      if (active) canvas.drawCircle(point, 7, pen);
    }
  }

  @override
  bool shouldRepaint(covariant _AnomalyMatrixPainter old) => true;
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
