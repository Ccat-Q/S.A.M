import 'package:flutter/material.dart';
import 'state/system_store.dart';
import 'ui/inspector.dart';
import 'ui/instruments.dart';
import 'ui/screens.dart';
import 'ui/settings.dart';
import 'ui/theme.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(SamApp(store: SystemStore())); }

class SamApp extends StatefulWidget {
  final SystemStore store;
  const SamApp({super.key, required this.store});
  @override
  State<SamApp> createState() => _SamAppState();
}
class _SamAppState extends State<SamApp> with WidgetsBindingObserver {
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); widget.store.initialize(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); widget.store.dispose(); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.store.user != null) {
      widget.store.synchronize().catchError((_) {});
    } else if (state == AppLifecycleState.paused) { widget.store.suspend(); }
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: widget.store, builder: (_, __) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'S.A.M.', theme: samTheme(),
    home: !widget.store.initialized ? const Scaffold(body: Center(child: Text('INITIALIZING CORE…')))
      : widget.store.user == null ? LoginScreen(store: widget.store) : SystemShell(store: widget.store),
  ));
}

class LoginScreen extends StatefulWidget {
  final SystemStore store;
  const LoginScreen({super.key, required this.store});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController server;
  final username = TextEditingController(), password = TextEditingController();
  bool skipBoot = false;
  @override
  void initState() { super.initState(); server = TextEditingController(text: widget.store.api.base.toString()); }
  @override
  void dispose() { server.dispose(); username.dispose(); password.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('S.A.M.', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 46, letterSpacing: 8)),
      const Text('SYSTEMS ADMINISTRATION & MAINTENANCE', style: TextStyle(color: muted, fontSize: 9, letterSpacing: 1)),
      const SizedBox(height: 36),
      Panel(title: 'AUTH CHANNEL // OPERATOR LOGIN', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(key: const Key('server-address'), controller: server, keyboardType: TextInputType.url, autocorrect: false, decoration: InputDecoration(labelText: store.tr('HTTPS SERVER ADDRESS', 'HTTPS 服务地址'))),
        const SizedBox(height: 12), TextField(key: const Key('username'), controller: username, autocorrect: false, decoration: InputDecoration(labelText: store.tr('MEMBER ID', '成员账号'))),
        const SizedBox(height: 12), TextField(key: const Key('password'), controller: password, obscureText: true, decoration: InputDecoration(labelText: store.tr('PASSWORD', '密码')), onSubmitted: (_) => _login(context)),
        const SizedBox(height: 20), OutlinedButton(key: const Key('login'), onPressed: store.busy ? null : () => _login(context), child: Text(store.busy ? 'AUTHENTICATING…' : store.tr('ENTER SYSTEM', '进入系统'))),
        if (store.busy && !skipBoot) ...[
          Reading('AUTH CHANNEL', store.user == null ? 'AUTHENTICATING' : 'OK'),
          Reading('NETWORK', store.nodes.isEmpty ? 'LOADING' : '${store.nodes.length} NODES'),
          Reading('CORE LINK', store.connected ? 'ESTABLISHED' : 'CONNECTING'),
          TextButton(onPressed: () => setState(() => skipBoot = true), child: const Text('SKIP BOOT')),
        ],
        if (store.error != null) Text(store.error!, style: const TextStyle(color: critical, fontSize: 11)),
      ])),
      const SizedBox(height: 20), Text(store.tr('Authorized operators only. Hardware and vision are simulated.', '仅限授权成员。当前硬件与视觉均为模拟。'), style: const TextStyle(color: muted, fontSize: 10)),
      TextButton(onPressed: () => store.setLanguage(store.language == 'zh' ? 'en' : 'zh'), child: Text(store.language == 'zh' ? 'ENGLISH' : '简体中文')),
    ]))))));
  }
  void _login(BuildContext context) {
    FocusScope.of(context).unfocus();
    if (!widget.store.busy) report(context, () => widget.store.login(server.text.trim(), username.text.trim(), password.text));
  }
}

class SystemShell extends StatefulWidget {
  final SystemStore store;
  const SystemShell({super.key, required this.store});
  @override
  State<SystemShell> createState() => _SystemShellState();
}
class _SystemShellState extends State<SystemShell> {
  int page = 0;
  String? logNode;
  bool fullscreen = false;
  void locate(String id) { widget.store.selectNode(id); setState(() => page = 1); }
  void camera(String id) {
    final store = widget.store;
    final target = store.nodes[id];
    final cameras = store.nodes.values.where((n) => n.type == 'CAMERA' && n.module == target?.module).toList();
    if (target?.type == 'CAMERA') { store.cameraId = id; }
    else if (cameras.isNotEmpty) { store.cameraId = cameras.firstWhere((n) => n.status != 'OFFLINE', orElse: () => cameras.first).id; }
    store.selectNode(id); setState(() => page = 2);
  }
  void logs(String id) { widget.store.selectNode(id); setState(() { logNode = id; page = 5; }); }
  void inspect(String id) {
    final store = widget.store;
    store.selectNode(id);
    if (MediaQuery.sizeOf(context).width < 1000 || fullscreen) {
      showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: background,
        shape: const RoundedRectangleBorder(), builder: (sheetContext) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(sheetContext).height * .86,
          child: AnimatedBuilder(animation: store, builder: (_, __) => SingleChildScrollView(padding: const EdgeInsets.all(12), child: Inspector(store: store,
            openCamera: () { Navigator.pop(sheetContext); camera(id); }, openLogs: () { Navigator.pop(sheetContext); logs(id); }))))));
    }
  }
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final destinations = [store.tr('OVERVIEW', '概览'), store.tr('MAP', '地图'), store.tr('CAMERA', '摄像头'), store.tr('ALERTS', '告警'), store.tr('DEVICES', '设备'), store.tr('LOGS', '日志'), store.tr('SETTINGS', '设置')];
    final icons = [Icons.radar, Icons.hub_outlined, Icons.videocam_outlined, Icons.warning_amber, Icons.memory, Icons.terminal, Icons.tune];
    Widget content = switch (page) {
      0 => OverviewScreen(store: store, locate: locate, openMap: () => setState(() => page = 1)),
      1 => MapScreen(store: store, inspect: inspect),
      2 => CameraScreen(store: store, inspect: inspect),
      3 => AlertsScreen(store: store, locate: locate, camera: camera, inspect: inspect, logs: logs),
      4 => DevicesScreen(store: store, inspect: inspect, locate: locate),
      5 => LogsScreen(key: ValueKey(logNode), store: store, nodeId: logNode),
      _ => SettingsScreen(store: store),
    };
    return Scaffold(body: SafeArea(child: Column(children: [
      Container(height: 56, padding: const EdgeInsets.symmetric(horizontal: 16), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: line))),
        child: Row(children: [const Text('SAM //', style: TextStyle(color: accent, fontSize: 20, letterSpacing: 3)), const SizedBox(width: 12),
          Expanded(child: Text(destinations[page], style: const TextStyle(fontSize: 11, letterSpacing: 1))),
          StatusLamp(store.connected ? 'ONLINE' : 'OFFLINE'), const SizedBox(width: 8),
          if (page == 1 || page == 2) IconButton(tooltip: store.tr('Toggle fullscreen', '切换全屏'), onPressed: () => setState(() => fullscreen = !fullscreen), icon: Icon(fullscreen ? Icons.fullscreen_exit : Icons.fullscreen, size: 20)),
        ])),
      if (!store.connected) Container(width: double.infinity, padding: const EdgeInsets.all(8), color: const Color(0xff332b18),
        child: Text(store.tr('CONNECTION LOST / DATA STALE / CONTROL DISABLED', '连接中断 / 数据过期 / 控制已禁用'), style: const TextStyle(color: warning, fontSize: 10))),
      Expanded(child: Row(children: [
        if (wide && !fullscreen) Container(width: 170, decoration: const BoxDecoration(border: Border(right: BorderSide(color: line))), child: ListView(children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('SYSTEM MODULES', style: TextStyle(color: muted, fontSize: 9))),
          for (var i = 0; i < destinations.length; i++) ListTile(selected: page == i, selectedColor: accent, dense: true,
            leading: Icon(icons[i], size: 16), title: Text(destinations[i], style: const TextStyle(fontSize: 11)), onTap: () => setState(() => page = i)),
          const Padding(padding: EdgeInsets.all(16), child: Text('SIMULATED FACILITY\n42 NODES / 04 MODULES\nBUILD 0.1', style: TextStyle(color: muted, fontSize: 8, height: 2))),
        ])),
        Expanded(child: content),
        if (wide && !fullscreen) Container(width: 310, decoration: const BoxDecoration(border: Border(left: BorderSide(color: line))),
          child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Inspector(store: store, openCamera: store.selectedId == null ? null : () => camera(store.selectedId!), openLogs: store.selectedId == null ? null : () => logs(store.selectedId!)))),
      ])),
      if (wide && !fullscreen) Container(height: 95, width: double.infinity, decoration: const BoxDecoration(border: Border(top: BorderSide(color: line))), padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(child: LogLines(store.logs.take(2).toList()))),
    ])), bottomNavigationBar: wide || fullscreen ? null : Container(decoration: const BoxDecoration(border: Border(top: BorderSide(color: line))),
      child: SafeArea(top: false, child: Row(children: [for (var i = 0; i < 5; i++) Expanded(child: TextButton(
        key: ValueKey('nav-$i'), onPressed: () {
          if (i < 4) { setState(() => page = i); }
          else { showModalBottomSheet<void>(context: context, backgroundColor: surface, shape: const RoundedRectangleBorder(), builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var j = 4; j < 7; j++) ListTile(leading: Icon(icons[j]), title: Text(destinations[j]), onTap: () { Navigator.pop(sheetContext); setState(() => page = j); }),
          ]))); }
        }, child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(i == 4 ? Icons.more_horiz : icons[i], size: 18, color: page == i || i == 4 && page >= 4 ? accent : muted),
          const SizedBox(height: 4), Text(i == 4 ? store.tr('MORE', '更多') : destinations[i], style: TextStyle(fontSize: 9, color: page == i ? accent : muted))]))]))));
  }
}
