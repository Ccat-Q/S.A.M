import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'instruments.dart';
import 'theme.dart';

class SettingsScreen extends StatefulWidget {
  final SystemStore store;
  const SettingsScreen({super.key, required this.store});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, dynamic>>? members;
  Future<void> loadMembers() async {
    await report(context, () async {
      final data = await widget.store.api.call('GET', '/api/members') as List;
      if (mounted) setState(() => members = data.map((x) => Map<String, dynamic>.from(x as Map)).toList());
    });
  }
  Future<void> createMember() async {
    final username = TextEditingController(), password = TextEditingController();
    String role = 'observer';
    final result = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, set) => AlertDialog(
      title: Text(widget.store.tr('CREATE MEMBER', '创建成员')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: username, decoration: InputDecoration(labelText: widget.store.tr('USERNAME', '用户名'))), const SizedBox(height: 12),
        TextField(controller: password, obscureText: true, decoration: InputDecoration(labelText: widget.store.tr('PASSWORD / 12+ characters', '密码 / 至少 12 位'))),
        DropdownButton<String>(value: role, items: ['admin', 'operator', 'observer'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => set(() => role = v!)),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(widget.store.tr('CANCEL', '取消'))),
        OutlinedButton(onPressed: () => Navigator.pop(context, true), child: Text(widget.store.tr('CREATE', '创建')))],
    )));
    if (result == true && mounted) await report(context, () async {
      await widget.store.api.call('POST', '/api/members', body: {'username': username.text, 'password': password.text, 'role': role});
      await loadMembers();
    });
    username.dispose(); password.dispose();
  }
  Future<void> updateMember(Map<String, dynamic> member) async {
    bool enabled = member['enabled'] as bool;
    String role = member['role'] as String;
    final result = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, set) => AlertDialog(
      title: Text(member['username'] as String), content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButton<String>(value: role, items: ['admin', 'operator', 'observer'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => set(() => role = v!)),
        SwitchListTile(title: Text(widget.store.tr('ENABLED', '启用')), value: enabled, onChanged: (v) => set(() => enabled = v)),
        Text(widget.store.tr('Changes revoke existing sessions and control links.', '更改将使该成员的现有登录和控制连接失效。'), style: const TextStyle(fontSize: 11, color: warning)),
      ]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(widget.store.tr('CANCEL', '取消'))),
        OutlinedButton(onPressed: () => Navigator.pop(context, true), child: Text(widget.store.tr('APPLY', '应用')))],
    )));
    if (result == true && mounted) await report(context, () async {
      await widget.store.api.call('PATCH', '/api/members/${member['id']}', body: {'role': role, 'enabled': enabled});
      await loadMembers();
    });
  }
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Panel(title: 'OPERATOR SESSION', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Reading('MEMBER', store.user?['username'] as String? ?? '—'), Reading('ACCESS', store.user?['role'] as String? ?? '—'),
        Reading('SERVER', store.api.base.toString()),
        Wrap(spacing: 8, children: [OutlinedButton(onPressed: () => report(context, store.synchronize), child: Text(store.tr('RECONNECT', '重新连接'))),
          TextButton(onPressed: () => report(context, store.logout), child: Text(store.tr('SIGN OUT / CHANGE SERVER', '退出 / 更换服务地址')))]),
      ])), const SizedBox(height: 12),
      Panel(title: 'DISPLAY / VISUAL EFFECTS', child: Column(children: [
        DropdownButton<String>(value: store.language, items: const [DropdownMenuItem(value: 'zh', child: Text('简体中文')), DropdownMenuItem(value: 'en', child: Text('English'))], onChanged: (v) => store.setLanguage(v!)),
        SwitchListTile(title: Text(store.tr('CRT / SCANLINE', 'CRT / 扫描线')), value: store.crt, onChanged: (v) => store.effects('crt', v)),
        SwitchListTile(title: Text(store.tr('VIDEO NOISE', '视频噪声')), value: store.noise, onChanged: (v) => store.effects('noise', v)),
        SwitchListTile(title: Text(store.tr('CHROMATIC SHIFT', '轻度色差')), value: store.chromatic, onChanged: (v) => store.effects('chromatic', v)),
        SwitchListTile(title: Text(store.tr('GLITCH', '轻度信号扰动')), value: store.glitch, onChanged: (v) => store.effects('glitch', v)),
        Text(store.tr('Effects never cover control text. Reduced motion is respected.', '效果不覆盖控制文字，并遵循系统的减少动态效果设置。'), style: const TextStyle(fontSize: 10, color: muted)),
      ])),
      if (store.isAdmin) ...[
        const SizedBox(height: 12), Panel(title: 'SIMULATION CONTROL', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(store.tr('Original 42-node scenario. All controls are simulated.', '原创 42 节点场景。所有控制均作用于模拟设备。')),
          Wrap(spacing: 8, children: [
            OutlinedButton(key: const Key('trigger-scenario'), onPressed: store.connected ? () => report(context, () => store.simulate('scenario')) : null, child: Text(store.tr('INJECT SCENARIO', '触发故障场景'))),
            OutlinedButton(onPressed: store.connected ? () => report(context, () => store.simulate(store.paused ? 'resume' : 'pause')) : null, child: Text(store.paused ? store.tr('RESUME', '继续') : store.tr('PAUSE', '暂停'))),
            OutlinedButton(onPressed: store.connected ? () => report(context, () async {
              final result = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(store.tr('RESET FACILITY?', '重置设施？')),
                content: Text(store.tr('Node state returns to initial conditions. Links expire; accounts and audit remain.', '节点恢复初始状态，现有连接失效；账号和审计保留。')),
                actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(store.tr('CANCEL', '取消'))), OutlinedButton(onPressed: () => Navigator.pop(context, true), child: Text(store.tr('RESET', '重置')))]));
              if (result == true) await store.simulate('reset');
            }) : null, child: Text(store.tr('RESET', '重置'))),
          ]),
        ])),
        const SizedBox(height: 12), Panel(title: 'TEAM MEMBERS', child: Column(children: [
          Wrap(spacing: 8, children: [OutlinedButton(onPressed: loadMembers, child: Text(store.tr('LOAD MEMBERS', '查看成员'))), OutlinedButton(onPressed: createMember, child: Text(store.tr('CREATE MEMBER', '创建成员')))]),
          for (final member in members ?? []) ListTile(onTap: () => updateMember(member), title: Text(member['username'] as String),
            subtitle: Text('${member['role']} / ${member['enabled'] == true ? 'ENABLED' : 'DISABLED'}'), trailing: const Icon(Icons.chevron_right)),
        ])),
      ],
    ]);
  }
}
