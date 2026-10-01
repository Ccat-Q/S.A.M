import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sam_client/main.dart';
import 'package:sam_client/data/api.dart';
import 'package:sam_client/state/system_store.dart';
import 'package:sam_client/ui/inspector.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('live service: alert → locate → camera → scan → link → recover → audit', (tester) async {
    final store = SystemStore(api: SamApi('http://localhost:8000'), persist: false);
    await tester.pumpWidget(SamApp(store: store));
    await waitFor(tester, find.byKey(const Key('login')));
    await tester.enterText(find.byKey(const Key('username')), 'admin');
    await tester.enterText(find.byKey(const Key('password')), 'Testing-Only-1234');
    await tester.tap(find.byKey(const Key('login')));
    await waitFor(tester, find.byKey(const Key('nav-3')));
    for (var i = 0; i < 100 && !store.connected; i++) { await tester.pump(const Duration(milliseconds: 100)); }
    expect(store.connected, isTrue);
    await binding.takeScreenshot('01-overview');
    await store.simulate('scenario');
    await tester.tap(find.byKey(const Key('nav-3')));
    await waitFor(tester, find.byKey(const ValueKey('locate-DEV-01')));
    await binding.takeScreenshot('02-alerts');
    await tester.ensureVisible(find.byKey(const ValueKey('locate-DEV-01')));
    await tester.tap(find.byKey(const ValueKey('locate-DEV-01')));
    await waitFor(tester, find.text('DEV-01 // POWER'));
    expect(store.selectedId, 'DEV-01');
    await binding.takeScreenshot('03-facility-map');
    // Select the other camera in this module; the power outage affects both.
    // Camera still provides explicit no-signal telemetry, without fake vision.
    await tester.tap(find.byKey(const Key('nav-2')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('NO SIGNAL'), findsWidgets);
    await binding.takeScreenshot('04-camera-offline');
    await tester.tap(find.byKey(const Key('nav-1')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('检查'));
    await waitFor(tester, find.byKey(const Key('scan-device')));
    await tester.ensureVisible(find.byKey(const Key('scan-device')));
    await tester.tap(find.byKey(const Key('scan-device')));
    await waitFor(tester, find.byKey(const Key('link-device')));
    await tester.ensureVisible(find.byKey(const Key('link-device')));
    await tester.tap(find.byKey(const Key('link-device')));
    await waitFor(tester, find.byKey(const Key('recover-device')));
    await binding.takeScreenshot('05-control-inspector');
    await tester.ensureVisible(find.byKey(const Key('recover-device')));
    await tester.tap(find.byKey(const Key('recover-device')));
    await waitFor(tester, find.byKey(const Key('confirm-command')));
    await binding.takeScreenshot('06-impact-confirmation');
    await tester.tap(find.byKey(const Key('confirm-command')));
    for (var i = 0; i < 100 && store.nodes['DEV-01']!.fault != null; i++) { await tester.pump(const Duration(milliseconds: 100)); }
    expect(store.nodes['DEV-01']!.fault, isNull);
    final records = await store.api.call('GET', '/api/logs', query: {'node_id': 'DEV-01'}) as List;
    expect(records.any((x) => x['category'] == 'COMMAND' && x['actor'] == 'admin'), isTrue);
    final snapshot = await store.api.call('GET', '/api/snapshot') as Map;
    expect((snapshot['alerts'] as List).any((a) => a['node_id'] == 'DEV-01' && a['state'] == 'RESOLVED'), isTrue);
    Navigator.of(tester.element(find.byType(Inspector))).pop();
    store.setCamera('CAM-01');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('nav-2')));
    await waitFor(tester, find.byKey(const ValueKey('target-DEV-02')));
    await binding.takeScreenshot('07-camera-online');
    await tester.tap(find.byKey(const ValueKey('target-DEV-02')));
    await waitFor(tester, find.byKey(const Key('scan-device')));
    expect(store.selectedId, 'DEV-02');
    expect(store.linked, isFalse);
    await store.suspend();
    expect(store.linked, isFalse);
    await store.setLanguage('en'); await store.effects('crt', false);
    expect(store.tr('OVERVIEW', '概览'), 'OVERVIEW');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
