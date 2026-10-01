import 'dart:async';
import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'screens.dart';
import 'inspector.dart';
import 'instruments.dart';
import 'memory_core.dart';
import 'settings.dart';
import 'terminal_effects.dart';
import 'theme.dart';
import 'terminal_actions.dart';

class SystemShell extends StatefulWidget {
  final SystemStore store;
  const SystemShell({super.key, required this.store});
  @override
  State<SystemShell> createState() => _SystemShellState();
}

class _SystemShellState extends State<SystemShell> {
  final actions = TerminalActions();
  int page = 0;
  String? logNode;
  bool fullscreen = false;
  bool operation = false;
  bool systemLink = false;
  final uptimeClock = Stopwatch()..start();
  Timer? clock;
  static const names = [
    'SYSTEM',
    'RELOCATION',
    'CAMERA',
    'SYSTEM ALERTS',
    'DEVICES',
    'EVENT LOG',
    'SETTINGS',
    'NETWORK',
    'MEMORY CORE',
  ];
  @override
  void initState() {
    super.initState();
    SystemMessages.shared.addListener(recordFeedback);
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    SystemMessages.shared.removeListener(recordFeedback);
    super.dispose();
  }

  void recordFeedback() {
    final messages = SystemMessages.shared;
    if (messages.message != null) widget.store.recordInterface(messages.message!, fault: messages.fault);
  }

  void navigate(int next) {
    setState(() { page = next; operation = false; if (![1,2,8].contains(next)) fullscreen = false; });
  }

  void operationDepth(bool active) {
    if (mounted && operation != active) setState(() => operation = active);
  }

  void locate(String id) {
    widget.store.selectNode(id);
    navigate(1);
  }

  void camera(String id) {
    final store = widget.store, target = store.nodes[id];
    final cameras = store.nodes.values
        .where((n) => n.type == 'CAMERA' && n.module == target?.module)
        .toList();
    if (target?.type == 'CAMERA')
      store.setCamera(id);
    else if (cameras.isNotEmpty)
      store.setCamera(
        cameras
            .firstWhere(
              (n) => n.status != 'OFFLINE',
              orElse: () => cameras.first,
            )
            .id,
      );
    store.selectNode(id);
    navigate(2);
  }

  void logs(String id) {
    widget.store.selectNode(id);
    logNode = id;
    navigate(5);
  }

  Future<void> inspect(String id) async {
    final store = widget.store;
    store.selectNode(id);
    setState(() => systemLink = true);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CLOSE SYSTEM LINK',
      barrierColor: Colors.black.withValues(alpha: .7),
      transitionDuration: Duration.zero,
      pageBuilder: (c, _, __) {
        final wide = MediaQuery.sizeOf(c).width >= 1000;
        return SafeArea(
          child: Align(
            alignment: wide ? Alignment.centerRight : Alignment.bottomCenter,
            child: Material(
              color: background,
              child: SizedBox(
                width: wide ? 420 : double.infinity,
                height: MediaQuery.sizeOf(c).height,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: line),
                      left: BorderSide(color: line),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 18),
                          const Expanded(
                            child: Text(
                              'SAM.LINK / NATIVE CONTROL / LEVEL 03',
                              style: TextStyle(
                                color: muted,
                                fontSize: 8,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          SoftKey(
                            key: const Key('close-system-link'),
                            label: 'CLOSE ×',
                            onPressed: () => Navigator.pop(c),
                          ),
                        ],
                      ),
                      Expanded(
                        child: AnimatedBuilder(
                          animation: store,
                          builder: (_, __) => SingleChildScrollView(
                            child: Inspector(
                              store: store,
                              openCamera: () {
                                Navigator.pop(c);
                                camera(id);
                              },
                              openLogs: () {
                                Navigator.pop(c);
                                logs(id);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SystemMessageLine(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (mounted) setState(() => systemLink = false);
  }

  void modules() => showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'CLOSE MODULE INDEX',
    barrierColor: Colors.black.withValues(alpha: .8),
    transitionDuration: Duration.zero,
    pageBuilder: (c, _, __) => SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Material(
          color: background,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SYSTEM MODULE INDEX',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
                const Divider(height: 22),
                for (final i in [4, 7, 8, 5, 6])
                  SoftKey(
                    key: ValueKey('menu-$i'),
                    code: i.toString().padLeft(2, '0'),
                    label: names[i],
                    onPressed: () {
                      Navigator.pop(c);
                      navigate(i);
                    },
                  ),
                SoftKey(label: 'RETURN <', onPressed: () => Navigator.pop(c)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final target = store.selectedId ?? 'NET-01';
    actions.reset({
      'DETAIL': () => inspect(target),
      'LOG': () { logNode = store.selectedId; navigate(5); },
      'DIAG': () { SystemMessages.shared.emit('DIAGNOSTIC / $target / SYSTEM LINK REQUIRED'); inspect(target); },
      'RELOC': () => navigate(1),
      'COMMAND': modules,
      'RETURN': () => navigate(0),
      'EXIT': () => navigate(1),
      'SETTINGS': () => navigate(6),
    });
    final softKeys = switch(page) {
      0 => ['DETAIL','LOG','DIAG','RELOC','COMMAND'],
      1 => ['SELECT','CAMERA','TRACE','FILTER','RETURN'],
      2 => ['ANGLE','SCAN','LINK','TRACK','EXIT'],
      3 => ['LOCATE','CAMERA','LINK','ACK','HISTORY'],
      7 => ['SELECT','TRACE','FILTER','INSPECT','RETURN'],
      8 => ['OPEN','RELATE','FILTER','TRACE','RETURN'],
      _ => ['DETAIL','LOG','RELOC','SETTINGS','RETURN'],
    };
    final uptime = uptimeClock.elapsed
        .toString()
        .split('.')
        .first
        .padLeft(8, '0');
    final content = switch (page) {
      0 => OverviewScreen(
        store: store,
        locate: locate,
        openMap: () => navigate(1),
      ),
      1 => MapScreen(store: store, inspect: inspect, camera: camera, actions: actions),
      2 => CameraScreen(store: store, inspect: inspect, actions: actions),
      3 => AlertsScreen(
        store: store,
        locate: locate,
        camera: camera,
        inspect: inspect,
        logs: logs,
        actions: actions,
        onOperation: operationDepth,
      ),
      4 => DevicesScreen(store: store, inspect: inspect, locate: locate),
      5 => LogsScreen(key: ValueKey(logNode), store: store, nodeId: logNode),
      6 => SettingsScreen(store: store),
      7 => NetworkScreen(store: store, inspect: inspect, actions: actions),
      _ => MemoryCoreScreen(store: store, locate: locate, actions: actions, onOperation: operationDepth),
    };
    return Scaffold(
      body: SafeArea(
        child: TerminalSurface(
          store: store,
          child: Column(
            children: [
              SizedBox(
                height: page == 2 || operation ? 28 : 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Text(
                        page == 2 ? 'SAM.OS / OPTICAL CHANNEL' : operation ? 'SAM.OS / OPERATION 02' : 'SAM.OS / REV 02.0',
                        style: const TextStyle(
                          fontSize: 8,
                          color: muted,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'SYS $uptime',
                        key: const Key('system-uptime'),
                        style: const TextStyle(fontSize: 8, color: muted),
                      ),
                      const SizedBox(width: 14),
                      StatusLamp(store.connected ? 'ONLINE' : 'OFFLINE'),
                      if ([1, 8].contains(page) && !operation)
                        SizedBox(
                          width: 48,
                          child: SoftKey(
                            label: fullscreen ? 'EXIT' : 'MAX',
                            onPressed: () =>
                                setState(() => fullscreen = !fullscreen),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!fullscreen && page != 2 && !operation && !systemLink)
                Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: line, width: .6)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final i in [0, 1, 7, 3, 8])
                          SoftKey(
                            key: ValueKey('tab-$i'),
                            label: const {
                              0: 'SYSTEM',
                              1: 'RELOC',
                              7: 'NETWORK',
                              3: 'ALERT',
                              8: 'MEMORY',
                            }[i]!,
                            selected: page == i,
                            onPressed: () => navigate(i),
                          ),
                      ],
                    ),
                  ),
                ),
              if (!store.connected)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'FAULT / DATA STALE / CONTROL INHIBITED',
                      style: TextStyle(
                        fontSize: 8,
                        color: warning,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: DisplayRedraw(
                  key: ValueKey('display-$page'),
                  child: content,
                ),
              ),
              const SystemMessageLine(),
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: line, width: .6)),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < 5; i++)
                      Expanded(
                        child: SoftKey(
                          key: ValueKey('soft-${softKeys[i]}'),
                          code: (i + 1).toString().padLeft(2, '0'),
                          label: softKeys[i],
                          onPressed: () => actions.invoke(softKeys[i]),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
