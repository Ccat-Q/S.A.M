import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'device_interfaces.dart';
import 'instruments.dart';
import 'theme.dart';

class Inspector extends StatefulWidget {
  final SystemStore store;
  final VoidCallback? openCamera, openLogs;
  const Inspector({
    super.key,
    required this.store,
    this.openCamera,
    this.openLogs,
  });
  @override
  State<Inspector> createState() => _InspectorState();
}

class _InspectorState extends State<Inspector> {
  static final knownInterfaces = <String>{};
  List<String>? sequence;
  int progress = 0;
  String? pairingNode;
  int? pairingGeneration;
  Map<String, dynamic>? diagnostic;
  String get identity =>
      '${identityHashCode(widget.store)}:${widget.store.user?['id']}:${widget.store.generation}:${widget.store.selectedId}';
  Future<void> connect() async {
    await report(context, () async {
      await widget.store.link();
      if (widget.store.linked) {
        if (knownInterfaces.length > 128) knownInterfaces.clear();
        knownInterfaces.add(identity);
        SystemMessages.shared.emit(
          'SYSTEM LINK / ${widget.store.selectedId} / ESTABLISHED',
        );
      }
    });
    if (mounted) setState(() => sequence = null);
  }

  void pair() {
    if (knownInterfaces.contains(identity)) {
      connect();
      return;
    }
    final glyphs = ['△', '○', '□']..shuffle(math.Random.secure());
    setState(() {
      sequence = glyphs;
      progress = 0;
      pairingNode = widget.store.selectedId;
      pairingGeneration = widget.store.generation;
    });
  }

  void press(String glyph) {
    if (sequence == null ||
        progress >= 3 ||
        widget.store.selectedId != pairingNode ||
        widget.store.generation != pairingGeneration ||
        !widget.store.connected)
      return;
    if (glyph != sequence![progress]) {
      setState(() => progress = 0);
      SystemMessages.shared.emit('SIGNAL ALIGNMENT / RETRY');
      return;
    }
    setState(() => progress++);
    if (progress == 3) connect();
  }

  Future<void> control(String action, Object? value) async {
    final store = widget.store;
    await report(context, () async {
      final request = store.commandRequest(action, value);
      final high =
          ['restart', 'recover', 'disconnect'].contains(action) ||
          action == 'power' && value == false;
      if (high) {
        final prepared = await store.prepare(request);
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COMMAND / IMPACT CONFIRMATION',
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: 1.5,
                        color: warning,
                      ),
                    ),
                    const Divider(height: 24),
                    Text(
                      '${action.toUpperCase()} / ${request['node_id']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'DEPENDENCY SET',
                      style: TextStyle(color: muted, fontSize: 9),
                    ),
                    Text(
                      (prepared['affected_nodes'] as List).join('\n'),
                      style: const TextStyle(fontSize: 10, height: 1.8),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      store.tr(
                        '60 SEC VALIDITY / SIMULATED CONTROL',
                        '60 秒有效 / 模拟设备控制',
                      ),
                      style: const TextStyle(fontSize: 9, color: muted),
                    ),
                    Wrap(
                      children: [
                        SoftKey(
                          label: 'CANCEL / 取消',
                          onPressed: () => Navigator.pop(c, false),
                        ),
                        SoftKey(
                          key: const Key('confirm-command'),
                          label: 'CONFIRM / 确认执行',
                          color: warning,
                          onPressed: () => Navigator.pop(c, true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        if (confirmed != true) return;
        request['confirmation_id'] = prepared['confirmation_id'];
      }
      final result = await store.execute(request);
      if (!mounted) return;
      if (result['diagnostic'] is Map)
        setState(
          () => diagnostic = Map<String, dynamic>.from(
            result['diagnostic'] as Map,
          ),
        );
      SystemMessages.shared.emit(
        '${action.toUpperCase()} / ${request['node_id']} / ${result['error'] ?? result['state']}',
        error: result['state'] == 'FAILED',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store, n = store.selected;
    if (n == null)
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'SYSTEM LINK / NO TARGET',
          style: TextStyle(fontSize: 11, color: muted),
        ),
      );
    if (pairingNode != n.id ||
        pairingGeneration != store.generation ||
        !store.connected) {
      sequence = null;
      progress = 0;
    }
    final identified = store.scannedId == n.id;
    final allowed = store.linked && store.canControl && !store.busy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'DEVICE / SYSTEM LINK',
            style: TextStyle(
              fontFamily: 'RobotoCondensed',
              fontSize: 13,
              letterSpacing: 2.6,
              color: accent,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  identified
                      ? '${n.subtype} INTERFACE'
                      : 'TARGET / UNIDENTIFIED',
                  style: const TextStyle(fontSize: 17, letterSpacing: 1.3),
                ),
              ),
              StatusLamp(n.status),
            ],
          ),
          const SizedBox(height: 16),
          Reading('DEVICE', n.id),
          Reading('LOCATION', n.module),
          Reading(
            'CHANNEL',
            store.connected ? store.stage : 'OFFLINE',
            color: store.linked ? accent : warning,
          ),
          const Divider(height: 28),
          if (!store.connected)
            const Text(
              'SIGNAL LOST / CONTROL INHIBITED',
              style: TextStyle(color: warning, fontSize: 10),
            ),
          if (!identified)
            SoftKey(
              key: const Key('scan-device'),
              label: store.stage == 'SCANNING'
                  ? 'IDENTIFYING / SCANNING'
                  : 'SCAN / 扫描设备',
              onPressed: store.connected && store.stage != 'SCANNING'
                  ? () => report(context, store.scan)
                  : null,
            ),
          if (identified && !store.linked) ...[
            Text(
              '${n.subtype} / DEVICE IDENTIFIED',
              style: const TextStyle(
                color: ink,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            if (!store.canControl)
              const Text(
                'OBSERVER / READ-ONLY CHANNEL',
                style: TextStyle(color: muted, fontSize: 10),
              )
            else if (sequence == null)
              SoftKey(
                key: const Key('link-device'),
                label: knownInterfaces.contains(identity)
                    ? 'QUICK PAIR / REQUEST LINK'
                    : 'PAIR / REQUEST SYSTEM LINK',
                onPressed: store.connected && store.stage != 'AUTHENTICATING'
                    ? pair
                    : null,
              )
            else ...[
              const Text(
                'LINK SEQUENCE / ALIGN SIGNAL',
                style: TextStyle(color: muted, fontSize: 9),
              ),
              const SizedBox(height: 12),
              Text(
                'SEQUENCE / ${sequence!.join(' ')}',
                key: const Key('pair-sequence'),
                style: const TextStyle(fontSize: 20, letterSpacing: 5),
              ),
              const SizedBox(height: 8),
              Text(
                '${List.filled(progress, '■').join()}${List.filled(3 - progress, '░').join()} / ${progress == 3 ? 'AUTH CHANNEL / WAIT' : 'TOUCH IN ORDER'}',
                style: const TextStyle(fontSize: 10, color: accent),
              ),
              Wrap(
                children: [
                  for (final glyph in ['△', '○', '□'])
                    SoftKey(
                      key: ValueKey('pair-$glyph'),
                      label: glyph,
                      onPressed: progress < 3 && store.connected
                          ? () => press(glyph)
                          : null,
                    ),
                ],
              ),
            ],
          ],
          if (store.linked || identified && !store.canControl) ...[
            const SizedBox(height: 14),
            DeviceInterface(store: store, allowed: allowed, command: control),
          ],
          if (diagnostic != null) ...[
            const Divider(height: 20),
            const Text(
              'DIAGNOSTIC / RESPONSE',
              style: TextStyle(color: muted, fontSize: 9),
            ),
            for (final entry in diagnostic!.entries)
              Reading(entry.key.toUpperCase(), entry.value.toString()),
          ],
          const SizedBox(height: 18),
          Wrap(
            children: [
              if (widget.openCamera != null)
                SoftKey(
                  label: 'OPTICAL CHANNEL >',
                  onPressed: widget.openCamera,
                ),
              if (widget.openLogs != null)
                SoftKey(label: 'EVENT HISTORY >', onPressed: widget.openLogs),
            ],
          ),
        ],
      ),
    );
  }
}
