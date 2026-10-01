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

Map<String, dynamic> fixture() => {
  'nodes': [
    {
      'id': 'DEV-01',
      'name': 'Power',
      'type': 'DEVICE',
      'subtype': 'POWER',
      'module_id': 'MOD-01',
      'status': 'ONLINE',
      'version': 2,
      'fault': null,
      'position': {'x': .3, 'y': .4},
      'capabilities': ['power', 'diagnostic'],
      'controls': {'power': true},
      'telemetry': {
        'power': 96.2,
        'temperature': 32,
        'uptime': 10,
        'latency': 18,
      },
      'metadata': {'firmware': '1.0.0'},
      'last_command': null,
    },
  ],
  'edges': [],
  'alerts': [],
  'camera_targets': {},
  'generation': 1,
  'cursor': 2,
  'tick': 0,
  'paused': false,
};

void main() {
  test(
    'queued stream events cannot roll back an HTTP snapshot or duplicate logs',
    () {
      final store = SystemStore(persist: false)..loadSnapshot(fixture());
      final oldNode =
          Map<String, dynamic>.from((fixture()['nodes'] as List).first as Map)
            ..['version'] = 1
            ..['status'] = 'OFFLINE';
      final packet = <String, dynamic>{
        'type': 'events',
        'cursor': 1,
        'events': [
          {
            'cursor': 1,
            'category': 'DEVICE',
            'message': 'OLD EVENT',
            'data': {
              'generation': 1,
              'nodes': [oldNode],
              'tick': 99,
              'paused': true,
            },
          },
        ],
      };
      store.receivePacket(packet);
      store.receivePacket(packet);
      expect(store.nodes['DEV-01']!.status, 'ONLINE');
      expect(store.cursor, 2);
      expect(store.tick, 0);
      expect(store.paused, isFalse);
      expect(store.logs.length, 1);
      // A newer stream cursor can still carry an older control version if an
      // HTTP command result has arrived ahead of its corresponding stream event.
      store.receivePacket({
        'type': 'events',
        'cursor': 3,
        'events': [
          {
            'cursor': 3,
            'category': 'TELEMETRY',
            'data': {
              'generation': 1,
              'nodes': [oldNode],
            },
          },
        ],
      });
      expect(store.nodes['DEV-01']!.version, 2);
      store.loadSnapshot(
        fixture()
          ..['cursor'] = 1
          ..['tick'] = 50,
      );
      expect(store.cursor, 3);
      expect(store.tick, 0);
      store.linkId = 'old-grant';
      store.receivePacket({
        'type': 'events',
        'cursor': 4,
        'events': [
          {
            'cursor': 4,
            'category': 'SYSTEM',
            'data': {
              'generation': 2,
              'nodes': [oldNode],
            },
          },
        ],
      });
      expect(store.generation, 2);
      expect(store.nodes['DEV-01']!.version, 1);
      expect(store.linkId, isNull);
      store.dispose();
    },
  );
  test(
    'reset invalidates grants and both maps reference the same identity',
    () {
      final store = SystemStore(persist: false);
      store.loadSnapshot(fixture());
      store.selectNode('DEV-01');
      store.scannedId = 'DEV-01';
      store.linkId = 'old-grant';
      final data = fixture()..['generation'] = 2;
      store.loadSnapshot(data);
      expect(store.linkId, isNull);
      expect(
        nodePositions(store.nodes.values, false).containsKey('DEV-01'),
        isTrue,
      );
      expect(
        nodePositions(store.nodes.values, true).containsKey('DEV-01'),
        isTrue,
      );
      store.dispose();
    },
  );
  test(
    'offline control is rejected before transport and login enforces HTTPS',
    () async {
      var requests = 0;
      final api = SamApi(
        'https://example.com',
        client: MockClient((r) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      final store = SystemStore(api: api, persist: false);
      expect(
        () => store.commandRequest('power', false),
        throwsA(isA<ApiError>()),
      );
      await expectLater(
        store.login('http://example.com', 'admin', 'password'),
        throwsA(isA<ApiError>()),
      );
      expect(requests, 0);
      store.dispose();
    },
  );
  testWidgets(
    'control is gated by scan/link and observer sees read-only inspector',
    (tester) async {
      final store = SystemStore(persist: false)
        ..loadSnapshot(fixture())
        ..selectNode('DEV-01');
      store.user = {'role': 'observer'};
      store.connected = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: samTheme(),
          home: Scaffold(
            body: SingleChildScrollView(child: Inspector(store: store)),
          ),
        ),
      );
      expect(find.byKey(const Key('scan-device')), findsOneWidget);
      expect(find.text('隔离供电'), findsNothing);
      expect(find.byKey(const Key('link-device')), findsNothing);
      store.user = {'role': 'operator'};
      store.scannedId = 'DEV-01';
      await tester.pumpWidget(
        MaterialApp(
          theme: samTheme(),
          home: Scaffold(
            body: SingleChildScrollView(child: Inspector(store: store)),
          ),
        ),
      );
      expect(find.byKey(const Key('link-device')), findsOneWidget);
      expect(find.text('隔离供电'), findsNothing);
      store.dispose();
    },
  );
  testWidgets('pair sequence gates transport; a wrong symbol cannot establish a link', (tester) async {
    var linkRequests = 0;
    final api = SamApi('https://example.com', client: MockClient((request) async {
      expect(request.url.path, '/api/links');
      linkRequests++;
      return http.Response('{"id":"verified-link"}', 200);
    }));
    final store = SystemStore(api: api, persist: false)
      ..loadSnapshot(fixture())..selectNode('DEV-01');
    store.user = {'id': 'test-member', 'role': 'operator'};
    store.connected = true;
    store.scannedId = 'DEV-01';
    store.scanReceipt = 'verified-scan';
    await tester.pumpWidget(MaterialApp(theme: samTheme(), home: Scaffold(
      body: SingleChildScrollView(child: Inspector(store: store)))));
    await tester.tap(find.byKey(const Key('link-device')));
    await tester.pump();
    final sequence = tester.widget<Text>(find.byKey(const Key('pair-sequence')))
      .data!.split(' / ').last.split(' ');
    final wrong = ['△','○','□'].firstWhere((symbol) => symbol != sequence.first);
    await tester.tap(find.byKey(ValueKey('pair-$wrong')));
    await tester.pump();
    expect(linkRequests, 0);
    expect(store.linked, isFalse);
    for (var i = 0; i < sequence.length; i++) {
      await tester.tap(find.byKey(ValueKey('pair-${sequence[i]}')));
      await tester.pump();
      if (i < 2) expect(linkRequests, 0);
    }
    await tester.pump();
    expect(linkRequests, 1);
    expect(store.linked, isTrue);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
  test('typed transport preserves error codes and request identity', () async {
    final api = SamApi(
      'https://example.com',
      client: MockClient((r) async {
        expect(jsonDecode(r.body)['key'], 'request-123');
        return http.Response('{"detail":"STALE_NODE_VERSION"}', 409);
      }),
    );
    await expectLater(
      api.call('POST', '/api/commands', body: {'key': 'request-123'}),
      throwsA(
        isA<ApiError>().having((e) => e.code, 'code', 'STALE_NODE_VERSION'),
      ),
    );
    api.close();
  });
}
