import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import '../data/api.dart';
import '../domain/node.dart';

class SystemStore extends ChangeNotifier {
  final SamApi api;
  final FlutterSecureStorage vault;
  final bool persist;
  SystemStore({SamApi? api, this.persist = true, FlutterSecureStorage? vault})
    : api = api ?? SamApi('https://sam.example.com'),
      vault = vault ?? const FlutterSecureStorage();
  Map<String, dynamic>? user;
  Map<String, Node> nodes = {};
  List<Map<String, dynamic>> edges = [], alerts = [], logs = [];
  // Bounded live display queue. These are received events, never command grants
  // or substitute audit records; telemetry stays out of the persistent log UI.
  List<Map<String, dynamic>> displayEvents = [];
  Map<String, dynamic> cameraTargets = {};
  int cursor = 0, generation = 1, tick = 0;
  bool connected = false, busy = false, initialized = false, paused = false;
  String? error, selectedId, cameraId, scannedId, scanReceipt, linkId;
  String stage = 'OBSERVE';
  String language = 'zh';
  bool crt = true, noise = true, chromatic = false, glitch = false;
  bool get canControl => user != null && user!['role'] != 'observer';
  bool get isAdmin => user?['role'] == 'admin';
  bool get linked => connected && linkId != null && scannedId == selectedId;
  Node? get selected => nodes[selectedId];
  IOWebSocketChannel? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  bool _disposed = false;
  int _epoch = 0;

  String tr(String en, String zh) => language == 'zh' ? zh : en;
  void setCamera(String? id) {
    cameraId = id;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (persist) {
      final address = await vault.read(key: 'server');
      if (address != null) api.base = Uri.parse(address);
      language = await vault.read(key: 'language') ?? 'zh';
      crt = await vault.read(key: 'crt') != 'false';
      noise = await vault.read(key: 'noise') != 'false';
      chromatic = await vault.read(key: 'chromatic') == 'true';
      glitch = await vault.read(key: 'glitch') == 'true';
      api.token = await vault.read(key: 'token');
      if (api.token != null) {
        try {
          user = Map<String, dynamic>.from(
            await api.call('GET', '/api/auth/me') as Map,
          );
          await synchronize();
        } catch (e) {
          error = e.toString();
          if (e is ApiError && e.status == 401) await logout();
        }
      }
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> login(String address, String username, String password) async {
    final url = Uri.tryParse(address);
    const ci = bool.fromEnvironment('SAM_CI');
    if (url == null ||
        url.host.isEmpty ||
        url.hasQuery ||
        url.hasFragment ||
        url.userInfo.isNotEmpty ||
        (url.scheme != 'https' &&
            !(ci && url.scheme == 'http' && url.host == 'localhost'))) {
      throw ApiError(422, 'HTTPS_ADDRESS_REQUIRED');
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      api.base = url;
      final response =
          await api.call(
                'POST',
                '/api/auth/login',
                body: {'username': username, 'password': password},
              )
              as Map;
      api.token = response['token'] as String;
      user = Map<String, dynamic>.from(response['user'] as Map);
      if (persist) {
        await vault.write(key: 'server', value: address);
        await vault.write(key: 'token', value: api.token);
      }
      await synchronize();
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void loadSnapshot(Map<String, dynamic> state, {bool authoritative = false}) {
    final nextGeneration = state['generation'] as int;
    final nextCursor = state['cursor'] as int;
    if (!authoritative &&
        (nextGeneration < generation ||
            nextGeneration == generation && nextCursor < cursor))
      return;
    final oldGeneration = generation;
    final previous = nodes;
    nodes = {
      for (final item in state['nodes'] as List)
        item['id'] as String: Node(Map<String, dynamic>.from(item as Map)),
    };
    if (!authoritative && oldGeneration == nextGeneration) {
      for (final n in previous.values) {
        if (nodes.containsKey(n.id) && n.version > nodes[n.id]!.version)
          nodes[n.id] = n;
      }
    }
    edges = (state['edges'] as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
    alerts = (state['alerts'] as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
    cameraTargets = Map<String, dynamic>.from(state['camera_targets'] as Map);
    generation = state['generation'] as int;
    cursor = state['cursor'] as int;
    tick = state['tick'] as int;
    paused = state['paused'] as bool;
    if (oldGeneration != generation) {
      clearLink();
      displayEvents.clear();
    }
  }

  Future<void> synchronize() async {
    final state = Map<String, dynamic>.from(
      await api.call('GET', '/api/snapshot') as Map,
    );
    loadSnapshot(state, authoritative: !connected);
    logs = (await api.call('GET', '/api/logs') as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
    await _connect();
    notifyListeners();
  }

  Future<void> _connect() async {
    if (_disposed || user == null) return;
    connected = false;
    clearLink();
    notifyListeners();
    _retry?.cancel();
    final epoch = ++_epoch;
    await _subscription?.cancel();
    await _socket?.sink.close();
    final uri = api
        .uri('/api/stream', {'after': '$cursor'})
        .replace(scheme: api.base.scheme == 'https' ? 'wss' : 'ws');
    final socket = IOWebSocketChannel.connect(
      uri,
      headers: {'Authorization': 'Bearer ${api.token}'},
      connectTimeout: const Duration(seconds: 10),
      pingInterval: const Duration(seconds: 15),
    );
    _socket = socket;
    try {
      await socket.ready;
      if (_disposed || epoch != _epoch) {
        await socket.sink.close();
        return;
      }
      connected = true;
      error = null;
      _subscription = socket.stream.listen(
        (raw) {
          if (epoch != _epoch) return;
          receivePacket(
            Map<String, dynamic>.from(jsonDecode(raw as String) as Map),
          );
        },
        onError: (Object e) => _lost(epoch),
        onDone: () => _lost(epoch),
      );
      notifyListeners();
    } catch (_) {
      _lost(epoch);
    }
  }

  void receivePacket(Map<String, dynamic> packet) {
    if (packet['type'] == 'snapshot') {
      loadSnapshot(
        Map<String, dynamic>.from(packet['snapshot'] as Map),
        authoritative: true,
      );
    } else {
      for (final raw in packet['events'] as List) {
        final event = Map<String, dynamic>.from(raw as Map);
        final eventCursor = event['cursor'] as int;
        final data = event['data'] as Map;
        final eventGeneration = data['generation'] as int? ?? generation;
        if (eventGeneration > generation) displayEvents.clear();
        if (eventGeneration >= generation &&
            !displayEvents.any((e) => e['cursor'] == eventCursor) &&
            (event['category'] != 'TELEMETRY' ||
                (data['tick'] as int? ?? 0) % 3 == 0)) {
          displayEvents.insert(0, event);
          if (displayEvents.length > 4) displayEvents.removeLast();
        }
        // An HTTP snapshot may already include these queued stream events.
        // Preserve their logs, but never roll back the snapshot or command state.
        if (eventCursor > cursor && eventGeneration >= generation) {
          final reset = eventGeneration != generation;
          if (reset) {
            generation = eventGeneration;
            clearLink();
          }
          if (data['nodes'] != null) {
            for (final rawNode in data['nodes'] as List) {
              final n = Node(Map<String, dynamic>.from(rawNode as Map));
              if (reset || n.version >= (nodes[n.id]?.version ?? 0))
                nodes[n.id] = n;
            }
          }
          if (data['alerts'] != null)
            alerts = (data['alerts'] as List)
                .map((x) => Map<String, dynamic>.from(x as Map))
                .toList();
          if (data['paused'] != null) paused = data['paused'] as bool;
          if (data['tick'] != null) tick = data['tick'] as int;
        }
        if (event['category'] != 'TELEMETRY' &&
            !logs.any((e) => e['cursor'] == eventCursor))
          logs.add(event);
        if (eventCursor > cursor) cursor = eventCursor;
      }
      if ((packet['cursor'] as int) > cursor) cursor = packet['cursor'] as int;
      logs.sort((a, b) => (b['cursor'] as int).compareTo(a['cursor'] as int));
      if (logs.length > 200) logs = logs.take(200).toList();
    }
    notifyListeners();
  }

  void _lost(int epoch) {
    if (_disposed || epoch != _epoch) return;
    connected = false;
    clearLink();
    notifyListeners();
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 3), () async {
      if (user == null || _disposed) return;
      try {
        // Re-check account revocation/expiration before any reconnect.
        user = Map<String, dynamic>.from(
          await api.call('GET', '/api/auth/me') as Map,
        );
        await synchronize();
      } catch (e) {
        if (e is ApiError && e.status == 401) {
          await logout();
        } else {
          _lost(epoch);
        }
      }
    });
  }

  void selectNode(String id) {
    if (selectedId != id) {
      final oldLink = linkId;
      if (oldLink != null)
        unawaited(
          api.call('DELETE', '/api/links/$oldLink').catchError((_) => null),
        );
      clearLink();
      selectedId = id;
    }
    notifyListeners();
  }

  void clearLink() {
    linkId = null;
    scannedId = null;
    scanReceipt = null;
    stage = 'OBSERVE';
  }

  void ensureConnected() {
    if (!connected) throw ApiError(409, 'CONNECTION_LOST');
  }

  Future<void> scan() async {
    ensureConnected();
    final id = selectedId;
    if (id == null) return;
    stage = 'SCANNING';
    notifyListeners();
    try {
      final result = await api.call('POST', '/api/nodes/$id/scan') as Map;
      if (selectedId != id || !connected) return;
      nodes[id] = Node(Map<String, dynamic>.from(result['node'] as Map));
      scannedId = id;
      scanReceipt = result['scan_id'] as String;
      stage = 'IDENTIFIED';
    } catch (_) {
      stage = 'OBSERVE';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> link() async {
    ensureConnected();
    final id = selectedId;
    if (scannedId != id || !canControl) throw ApiError(403, 'SCAN_REQUIRED');
    stage = 'AUTHENTICATING';
    notifyListeners();
    try {
      final result =
          await api.call(
                'POST',
                '/api/links',
                body: {
                  'node_id': id,
                  'generation': generation,
                  'scan_id': scanReceipt,
                },
              )
              as Map;
      if (selectedId != id || !connected) {
        await api.call('DELETE', '/api/links/${result['id']}');
        return;
      }
      linkId = result['id'] as String;
      stage = 'ESTABLISHED';
    } catch (e) {
      if (e is ApiError &&
          (e.code == 'SCAN_REQUIRED' || e.code == 'SCENE_CHANGED')) {
        clearLink();
      } else {
        stage = 'IDENTIFIED';
      }
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Map<String, dynamic> commandRequest(String action, Object? value) {
    ensureConnected();
    if (!linked) throw ApiError(409, 'LINK_REQUIRED');
    return {
      'node_id': selectedId,
      'link_id': linkId,
      'action': action,
      'value': value,
      'expected_version': selected!.version,
      'key': const Uuid().v4(),
    };
  }

  Future<Map<String, dynamic>> prepare(Map<String, dynamic> request) async {
    ensureConnected();
    return Map<String, dynamic>.from(
      await api.call('POST', '/api/commands/prepare', body: request) as Map,
    );
  }

  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    ensureConnected();
    busy = true;
    notifyListeners();
    try {
      Map result;
      try {
        result = await api.call('POST', '/api/commands', body: request) as Map;
      } catch (e) {
        if (e is ApiError) rethrow;
        try {
          result =
              await api.call('GET', '/api/commands/by-key/${request['key']}')
                  as Map;
        } catch (_) {
          throw ApiError(409, 'COMMAND_OUTCOME_UNKNOWN');
        }
      }
      final n = Map<String, dynamic>.from(result['node'] as Map);
      nodes[n['id'] as String] = Node(n);
      return Map<String, dynamic>.from(result);
    } on ApiError catch (e) {
      if (e.code.startsWith('LINK_')) clearLink();
      if (e.code == 'STALE_NODE_VERSION' || e.code == 'IMPACT_CHANGED') {
        loadSnapshot(
          Map<String, dynamic>.from(
            await api.call('GET', '/api/snapshot') as Map,
          ),
        );
      }
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> acknowledge(String id) async {
    ensureConnected();
    await api.call('POST', '/api/alerts/$id/acknowledge');
  }

  Future<void> simulate(String action) async {
    ensureConnected();
    loadSnapshot(
      Map<String, dynamic>.from(
        await api.call('POST', '/api/simulation', body: {'action': action})
            as Map,
      ),
    );
    if (action == 'reset') clearLink();
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    language = value;
    if (persist) await vault.write(key: 'language', value: value);
    notifyListeners();
  }

  Future<void> effects(String key, bool value) async {
    switch (key) {
      case 'crt':
        crt = value;
      case 'noise':
        noise = value;
      case 'chromatic':
        chromatic = value;
      case 'glitch':
        glitch = value;
    }
    if (persist) await vault.write(key: key, value: '$value');
    notifyListeners();
  }

  Future<void> suspend() async {
    ++_epoch;
    _retry?.cancel();
    connected = false;
    clearLink();
    await _subscription?.cancel();
    await _socket?.sink.close();
    notifyListeners();
  }

  Future<void> logout() async {
    ++_epoch;
    _retry?.cancel();
    if (api.token != null) {
      try {
        await api.call('POST', '/api/auth/logout');
      } catch (_) {}
    }
    await _subscription?.cancel();
    await _socket?.sink.close();
    api.token = null;
    user = null;
    connected = false;
    nodes = {};
    alerts = [];
    logs = [];
    displayEvents = [];
    clearLink();
    if (persist) await vault.delete(key: 'token');
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _retry?.cancel();
    _subscription?.cancel();
    _socket?.sink.close();
    api.close();
    super.dispose();
  }
}
