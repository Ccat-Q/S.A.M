import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'state/system_store.dart';
import 'ui/instruments.dart';
import 'ui/system_shell.dart';
import 'ui/theme.dart';
import 'ui/errors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SamApp(store: SystemStore()));
}

class SamApp extends StatefulWidget {
  final SystemStore store;
  const SamApp({super.key, required this.store});
  @override
  State<SamApp> createState() => _SamAppState();
}

class _SamAppState extends State<SamApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.store.user != null) {
      widget.store.synchronize().catchError((_) {});
    } else if (state == AppLifecycleState.paused) {
      widget.store.suspend();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'S.A.M.',
      theme: samTheme(),
      locale: Locale(widget.store.language),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: !widget.store.initialized
          ? const Scaffold(body: Center(child: Text('INITIALIZING CORE…')))
          : widget.store.user == null
          ? LoginScreen(store: widget.store)
          : SystemShell(store: widget.store),
    ),
  );
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
  void initState() {
    super.initState();
    server = TextEditingController(text: widget.store.api.base.toString());
  }

  @override
  void dispose() {
    server.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'SAM.OS / AUTH',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      letterSpacing: 3,
                    ),
                  ),
                  const Text(
                    'SYSTEMS ADMINISTRATION & MAINTENANCE',
                    style: TextStyle(
                      color: muted,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Panel(
                    title: 'AUTH CHANNEL // OPERATOR LOGIN',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          key: const Key('server-address'),
                          controller: server,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: store.tr(
                              'HTTPS SERVER ADDRESS',
                              'HTTPS 服务地址',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('username'),
                          controller: username,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: store.tr('MEMBER ID', '成员账号'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('password'),
                          controller: password,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: store.tr('PASSWORD', '密码'),
                          ),
                          onSubmitted: (_) => _login(context),
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton(
                          key: const Key('login'),
                          onPressed: store.busy ? null : () => _login(context),
                          child: Text(
                            store.busy
                                ? 'AUTHENTICATING…'
                                : store.tr('ENTER SYSTEM', '进入系统'),
                          ),
                        ),
                        if (store.busy && !skipBoot) ...[
                          Reading(
                            'AUTH CHANNEL',
                            store.user == null ? 'AUTHENTICATING' : 'OK',
                          ),
                          Reading(
                            'NETWORK',
                            store.nodes.isEmpty
                                ? 'LOADING'
                                : '${store.nodes.length} NODES',
                          ),
                          Reading(
                            'CORE LINK',
                            store.connected ? 'ESTABLISHED' : 'CONNECTING',
                          ),
                          TextButton(
                            onPressed: () => setState(() => skipBoot = true),
                            child: const Text('SKIP BOOT'),
                          ),
                        ],
                        if (store.error != null)
                          Text(
                            explainError(store.error!, store.language == 'zh'),
                            style: const TextStyle(
                              color: critical,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    store.tr(
                      'Authorized operators only. Hardware and vision are simulated.',
                      '仅限授权成员。当前硬件与视觉均为模拟。',
                    ),
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                  TextButton(
                    onPressed: () =>
                        store.setLanguage(store.language == 'zh' ? 'en' : 'zh'),
                    child: Text(store.language == 'zh' ? 'ENGLISH' : '简体中文'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _login(BuildContext context) {
    FocusScope.of(context).unfocus();
    if (!widget.store.busy)
      report(
        context,
        () => widget.store.login(
          server.text.trim(),
          username.text.trim(),
          password.text,
        ),
      );
  }
}
