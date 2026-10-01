import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'camera_display.dart';
import 'instruments.dart';
import 'terminal_effects.dart';
import 'theme.dart';
import 'terminal_actions.dart';

class CameraScreen extends StatefulWidget {
  final SystemStore store;
  final ValueChanged<String> inspect;
  final TerminalActions? actions;
  const CameraScreen({
    super.key,
    required this.store,
    required this.inspect,
    this.actions,
  });
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  String? lockedTarget, lockedCamera;
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final inspect = widget.inspect;
    final all = store.nodes.values.where((n) => n.type == 'CAMERA').toList();
    if (all.isEmpty)
      return const Center(child: Text('OPTICAL CHANNEL / UNAVAILABLE'));
    final camera = store.nodes[store.cameraId] ?? all.first;
    if (lockedCamera != camera.id) {
      lockedTarget = null;
      lockedCamera = null;
    }
    final angles = all.where((n) => n.module == camera.module).toList();
    final ids = (store.cameraTargets[camera.id] as List? ?? [])
        .map((x) => x['node_id'])
        .toSet();
    final aimed = ids.contains(store.selectedId) && camera.status != 'OFFLINE';
    final locked =
        lockedTarget == store.selectedId && lockedCamera == camera.id && aimed;
    widget.actions?.bind({
      'ANGLE': () => store.setCamera(
        angles[(angles.indexOf(camera) + 1) % angles.length].id,
      ),
      'SCAN': aimed && store.connected
          ? () => report(context, () async {
              await store.scan();
              if (context.mounted) inspect(store.selectedId!);
            })
          : null,
      'LINK':
          (aimed && store.scannedId == store.selectedId) ||
              (store.selected?.fault != null &&
                  store.selected?.module == camera.module)
          ? () => inspect(store.selectedId!)
          : null,
      'TRACK': aimed
          ? () {
              setState(() {
                lockedTarget = locked ? null : store.selectedId;
                lockedCamera = camera.id;
              });
              SystemMessages.shared.emit(
                locked
                    ? 'TARGET RELEASED'
                    : 'TARGET LOCK / ${store.selectedId} / MANUAL',
              );
            }
          : null,
    });
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14, right: 6, top: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${camera.module} / CURRENT ANGLE',
                      style: const TextStyle(
                        fontSize: 9,
                        letterSpacing: 1,
                        color: muted,
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < angles.length; i++)
                          SoftKey(
                            label: '[${String.fromCharCode(65 + i)}]',
                            selected: angles[i].id == camera.id,
                            onPressed: () => store.setCamera(angles[i].id),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SoftKey(label: 'AXIS', onPressed: () => inspect(camera.id)),
              SoftKey(
                label: 'CHANNELS',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (c) => Dialog(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('OPTICAL ARRAY / SELECT'),
                            for (final cam in all)
                              SoftKey(
                                label:
                                    '${cam.module} / ${cam.id} / ${cam.status}',
                                onPressed: () {
                                  Navigator.pop(c);
                                  store.setCamera(cam.id);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: DisplayRedraw(
            key: ValueKey(camera.id),
            child: CameraDisplay(
              store: store,
              cameraId: camera.id,
              onTarget: (id) {
                if (locked) return;
                store.selectNode(id);
                SystemMessages.shared.emit(
                  'TARGET DETECTED / REQUEST IDENTIFICATION',
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              locked
                  ? 'TARGET LOCK / $lockedTarget / MANUAL OPTICAL FIX'
                  : !aimed
                  ? 'OBJECTIVE / ACQUIRE DEVICE TARGET'
                  : store.scannedId == store.selectedId
                  ? 'IDENTIFIED / ${store.selected?.subtype} / ${store.selectedId}'
                  : 'TARGET FOUND / UNIDENTIFIED',
              style: const TextStyle(
                fontSize: 9,
                color: accent,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
