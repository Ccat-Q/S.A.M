import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    timeout: const Duration(minutes: 3),
    onScreenshot: (name, bytes, [args]) async {
      final folder = Directory('../artifacts/screenshots')
        ..createSync(recursive: true);
      File('${folder.path}/$name.png').writeAsBytesSync(bytes);
      return bytes.isNotEmpty;
    },
  );
}
