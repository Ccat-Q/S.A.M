import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sam_client/main.dart';
import 'package:sam_client/data/api.dart';
import 'package:sam_client/state/system_store.dart';
import 'package:sam_client/ui/memory_core.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      // Display data exists before the 280ms scan redraw exposes its hitbox.
      await tester.pump(const Duration(milliseconds: 400));
      return;
    }
  }
  expect(finder, findsWidgets);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Paint the continuously running displays between explicit test operations.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'live service: alert → locate → camera → scan → link → recover → audit',
    (tester) async {
      final store = SystemStore(
        api: SamApi('http://localhost:8000'),
        persist: false,
      );
      await tester.pumpWidget(SamApp(store: store));
      await waitFor(tester, find.byKey(const Key('login')));
      await tester.enterText(find.byKey(const Key('username')), 'admin');
      await tester.enterText(
        find.byKey(const Key('password')),
        'Testing-Only-1234',
      );
      await tester.tap(find.byKey(const Key('login')));
      await waitFor(tester, find.byKey(const Key('tab-3')));
      for (var i = 0; i < 100 && !store.connected; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(store.connected, isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      await binding.takeScreenshot('01-overview');
      await tester.tap(find.byKey(const Key('tab-3')));
      await waitFor(tester, find.text('ACTIVE ALERTS'));
      await binding.takeScreenshot('01a-alert-standby');
      await store.simulate('scenario');
      await tester.tap(find.byKey(const Key('tab-3')));
      await waitFor(tester, find.byKey(const Key('soft-LOCATE')));
      await binding.takeScreenshot('02-alerts');
      await tester.ensureVisible(find.byKey(const Key('soft-LOCATE')));
      await tester.tap(find.byKey(const Key('soft-LOCATE')));
      await waitFor(tester, find.byKey(const Key('relocate-camera')));
      expect(store.selectedId, 'DEV-01');
      await binding.takeScreenshot('03-facility-map');
      // Select the other camera in this module; the power outage affects both.
      // Camera still provides explicit no-signal telemetry, without fake vision.
      await tester.tap(find.byKey(const Key('soft-CAMERA')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('NO SIGNAL'), findsWidgets);
      await binding.takeScreenshot('04-camera-offline');
      await tester.tap(find.byKey(const Key('soft-LINK')));
      await waitFor(tester, find.byKey(const Key('scan-device')));
      await tester.ensureVisible(find.byKey(const Key('scan-device')));
      await tester.tap(find.byKey(const Key('scan-device')));
      await waitFor(tester, find.byKey(const Key('link-device')));
      await tester.ensureVisible(find.byKey(const Key('link-device')));
      await tester.tap(find.byKey(const Key('link-device')));
      await waitFor(tester, find.byKey(const Key('pair-sequence')));
      await tester.pump(const Duration(milliseconds: 400));
      await binding.takeScreenshot('05a-pair-sequence');
      final sequence = tester
          .widget<Text>(find.byKey(const Key('pair-sequence')))
          .data!
          .split(' / ')
          .last
          .split(' ');
      for (final glyph in sequence) {
        await tester.ensureVisible(find.byKey(ValueKey('pair-$glyph')));
        await tester.tap(find.byKey(ValueKey('pair-$glyph')));
        await tester.pump(const Duration(milliseconds: 150));
      }
      await waitFor(tester, find.byKey(const Key('recover-device')));
      await binding.takeScreenshot('05-control-inspector');
      await tester.ensureVisible(find.byKey(const Key('recover-device')));
      await tester.tap(find.byKey(const Key('recover-device')));
      await waitFor(tester, find.byKey(const Key('confirm-command')));
      await tester.pump(const Duration(milliseconds: 400));
      await binding.takeScreenshot('06-impact-confirmation');
      await tester.tap(find.byKey(const Key('confirm-command')));
      for (var i = 0; i < 100 && store.nodes['DEV-01']!.fault != null; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(store.nodes['DEV-01']!.fault, isNull);
      final records =
          await store.api.call('GET', '/api/logs', query: {'node_id': 'DEV-01'})
              as List;
      expect(
        records.any((x) => x['category'] == 'COMMAND' && x['actor'] == 'admin'),
        isTrue,
      );
      final snapshot = await store.api.call('GET', '/api/snapshot') as Map;
      expect(
        (snapshot['alerts'] as List).any(
          (a) => a['node_id'] == 'DEV-01' && a['state'] == 'RESOLVED',
        ),
        isTrue,
      );
      await tester.tap(find.byKey(const Key('close-system-link')));
      store.setCamera('CAM-01');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('tab-1')));
      await waitFor(tester, find.byKey(const Key('soft-CAMERA')));
      await tester.tap(find.byKey(const Key('soft-CAMERA')));
      await waitFor(tester, find.byKey(const ValueKey('target-DEV-02')));
      await binding.takeScreenshot('07-camera-online');
      await tester.tap(find.byKey(const ValueKey('target-DEV-02')));
      await waitFor(tester, find.byKey(const Key('soft-SCAN')));
      expect(store.scannedId, isNull);
      await tester.tap(find.byKey(const Key('soft-SCAN')));
      await waitFor(tester, find.byKey(const Key('link-device')));
      expect(store.selectedId, 'DEV-02');
      expect(store.scannedId, 'DEV-02');
      await tester.tap(find.byKey(const Key('close-system-link')));
      await tester.tap(find.byKey(const Key('tab-7')));
      await tester.pump(const Duration(milliseconds: 500));
      await binding.takeScreenshot('08-network');
      await tester.ensureVisible(find.byKey(const Key('tab-8')));
      await tester.tap(find.byKey(const Key('tab-8')));
      await tester.pump(const Duration(milliseconds: 500));
      final ring = tester.getRect(find.byKey(const Key('memory-ring')));
      final memories = memoryRecords(store);
      final index = memories.indexWhere((r) => r.id == 'SYS.DEV-01');
      final angle = index / memories.length * math.pi * 2 - math.pi / 2;
      final radius = math.min(ring.width * .4, ring.height * .4);
      await tester.tapAt(
        ring.center + Offset(math.cos(angle), math.sin(angle)) * radius,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('MEMORY / SYS.DEV-01'), findsOneWidget);
      await binding.takeScreenshot('09-memory-ring');
      await tester.tap(find.byKey(const Key('tab-1')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('soft-TRACE')));
      await tester.pump(const Duration(milliseconds: 400));
      await binding.takeScreenshot('10-module-interior');
      expect(store.linked, isFalse);
      await store.suspend();
      expect(store.linked, isFalse);
      await store.setLanguage('en');
      await store.effects('crt', false);
      expect(store.tr('OVERVIEW', '概览'), 'OVERVIEW');
      await tester.pumpWidget(const SizedBox.shrink());
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
