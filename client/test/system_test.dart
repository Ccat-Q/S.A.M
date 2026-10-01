import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sam_client/data/api.dart';
import 'package:sam_client/state/system_store.dart';
import 'package:sam_client/ui/inspector.dart';
import 'package:sam_client/ui/map_display.dart';
import 'package:sam_client/ui/theme.dart';

Map<String, dynamic> fixture() => {'nodes': [
  {'id': 'DEV-01', 'name': 'Power', 'type': 'DEVICE', 'subtype': 'POWER', 'module_id': 'MOD-01', 'status': 'ONLINE', 'version': 2,
   'fault': null, 'position': {'x': .3, 'y': .4}, 'capabilities': ['power', 'diagnostic'],
   'controls': {'power': true}, 'telemetry': {'power': 96.2, 'temperature': 32, 'uptime': 10, 'latency': 18},
   'metadata': {'firmware': '1.0.0'}, 'last_command': null},
], 'edges': [], 'alerts': [], 'camera_targets': {}, 'generation': 1, 'cursor': 2, 'tick': 0, 'paused': false};

void main() {
  test('reset invalidates grants and both maps reference the same identity', () {
    final store = SystemStore(persist: false);
    store.loadSnapshot(fixture());
    store.selectNode('DEV-01'); store.scannedId = 'DEV-01'; store.linkId = 'old-grant';
    final data = fixture()..['generation'] = 2;
    store.loadSnapshot(data);
    expect(store.linkId, isNull);
    expect(nodePositions(store.nodes.values, false).containsKey('DEV-01'), isTrue);
    expect(nodePositions(store.nodes.values, true).containsKey('DEV-01'), isTrue);
    store.dispose();
  });
  test('offline control is rejected before transport and login enforces HTTPS', () async {
    var requests = 0;
    final api = SamApi('https://example.com', client: MockClient((r) async { requests++; return http.Response('{}', 200); }));
    final store = SystemStore(api: api, persist: false);
    expect(() => store.commandRequest('power', false), throwsA(isA<ApiError>()));
    await expectLater(store.login('http://example.com', 'admin', 'password'), throwsA(isA<ApiError>()));
    expect(requests, 0);
    store.dispose();
  });
  testWidgets('control is gated by scan/link and observer sees read-only inspector', (tester) async {
    final store = SystemStore(persist: false)..loadSnapshot(fixture())..selectNode('DEV-01');
    store.user = {'role': 'observer'}; store.connected = true;
    await tester.pumpWidget(MaterialApp(theme: samTheme(), home: Scaffold(body: SingleChildScrollView(child: Inspector(store: store)))));
    expect(find.byKey(const Key('scan-device')), findsOneWidget);
    expect(find.text('隔离供电'), findsNothing);
    expect(find.byKey(const Key('link-device')), findsNothing);
    store.user = {'role': 'operator'}; store.scannedId = 'DEV-01';
    await tester.pumpWidget(MaterialApp(theme: samTheme(), home: Scaffold(body: SingleChildScrollView(child: Inspector(store: store)))));
    expect(find.byKey(const Key('link-device')), findsOneWidget);
    expect(find.text('隔离供电'), findsNothing);
    store.dispose();
  });
  test('typed transport preserves error codes and request identity', () async {
    final api = SamApi('https://example.com', client: MockClient((r) async {
      expect(jsonDecode(r.body)['key'], 'request-123');
      return http.Response('{"detail":"STALE_NODE_VERSION"}', 409);
    }));
    await expectLater(api.call('POST', '/api/commands', body: {'key': 'request-123'}), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'STALE_NODE_VERSION')));
    api.close();
  });
}
