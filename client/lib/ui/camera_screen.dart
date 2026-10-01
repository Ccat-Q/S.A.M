import 'dart:async';
import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'camera_display.dart';
import 'instruments.dart';
import 'terminal_actions.dart';
import 'theme.dart';

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
  String? candidate, identified, lockedTarget, opticalCamera, signal;
  bool scanning = false, reticle = false;
  Timer? touchExpiry;
  int channelEpoch = 0;
  @override
  void dispose() {
    channelEpoch++;
    touchExpiry?.cancel();
    super.dispose();
  }

  void aim(String id) {
    if (lockedTarget != null || scanning || signal != null) return;
    widget.store.selectNode(id);
    setState(() {
      if (candidate != id) identified = null;
      candidate = id;
      reticle = true;
    });
    touchExpiry?.cancel();
    touchExpiry = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => reticle = false);
    });
    SystemMessages.shared.emit('TARGET CANDIDATE / REQUEST SCAN');
  }

  Future<void> scan() async {
    final id = candidate, camera = opticalCamera;
    if (id == null || scanning || signal != null) return;
    widget.store.selectNode(id);
    setState(() {
      scanning = true;
      identified = null;
    });
    SystemMessages.shared.emit('SCANNING / OPTICAL SIGNATURE');
    try {
      await Future.wait([
        widget.store.scan(),
        Future<void>.delayed(const Duration(milliseconds: 260)),
      ]);
      if (!mounted || opticalCamera != camera || candidate != id) return;
      if (widget.store.scannedId == id) {
        setState(() => identified = id);
        SystemMessages.shared.emit('SIGNATURE FOUND / TARGET IDENTIFIED / $id');
      }
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> switchChannel(String id) async {
    if (id == opticalCamera || signal != null || scanning) return;
    final epoch = ++channelEpoch;
    touchExpiry?.cancel();
    setState(() {
      candidate = identified = lockedTarget = null;
      reticle = false;
      signal = 'SIGNAL DROP';
    });
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (!reduced) {
      for (final phase in ['STATIC', 'SYNC', 'LOCK']) {
        await Future<void>.delayed(const Duration(milliseconds: 65));
        if (!mounted || channelEpoch != epoch) return;
        setState(() => signal = phase);
      }
    }
    widget.store.setCamera(id);
    if (!reduced) await Future<void>.delayed(const Duration(milliseconds: 65));
    if (!mounted || channelEpoch != epoch) return;
    setState(() => signal = null);
    SystemMessages.shared.emit('VIDEO RESTORE / $id');
  }

  Future<void> channels() async {
    final store = widget.store;
    final all = store.nodes.values.where((n) => n.type == 'CAMERA').toList();
    final camera = store.nodes[store.cameraId] ?? all.first;
    final angles = all.where((n) => n.module == camera.module).toList();
    await showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OPTICAL CHANNEL / SELECT',
                  style: TextStyle(fontSize: 10, letterSpacing: 2),
                ),
                for (var i = 0; i < 3; i++)
                  SoftKey(
                    label:
                        '${String.fromCharCode(65 + i)}    ${i >= angles.length
                            ? 'N/A'
                            : angles[i].id == camera.id
                            ? 'ACTIVE'
                            : angles[i].status == 'OFFLINE'
                            ? 'NO SIGNAL'
                            : 'STANDBY'}',
                    selected: i < angles.length && angles[i].id == camera.id,
                    onPressed: i >= angles.length
                        ? null
                        : () {
                            Navigator.pop(c);
                            switchChannel(angles[i].id);
                          },
                  ),
                const Divider(height: 24),
                SoftKey(
                  label: 'AXIS / NATIVE INTERFACE',
                  onPressed: () {
                    Navigator.pop(c);
                    widget.inspect(camera.id);
                  },
                ),
                for (final cam in all.where((n) => n.module != camera.module))
                  SoftKey(
                    label: '${cam.module} / ${cam.id} / ${cam.status}',
                    onPressed: () {
                      Navigator.pop(c);
                      switchChannel(cam.id);
                    },
                  ),
                SoftKey(label: 'RETURN <', onPressed: () => Navigator.pop(c)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final all = store.nodes.values.where((n) => n.type == 'CAMERA').toList();
    if (all.isEmpty)
      return const Center(child: Text('OPTICAL CHANNEL / UNAVAILABLE'));
    final camera = store.nodes[store.cameraId] ?? all.first;
    if (opticalCamera != camera.id) {
      opticalCamera = camera.id;
      candidate = identified = lockedTarget = null;
      reticle = false;
    }
    final angles = all.where((n) => n.module == camera.module).toList();
    final target = store.nodes[candidate];
    final visible = camera.status != 'OFFLINE' && signal == null;
    final knownFault =
        store.selected?.fault != null &&
        store.selected?.module == camera.module;
    final verified =
        identified != null &&
        identified == store.scannedId &&
        candidate == store.selectedId;
    widget.actions?.bind({
      'ANGLE': channels,
      'SCAN': candidate != null && visible && store.connected && !scanning
          ? () => report(context, scan)
          : null,
      'LINK': verified || knownFault
          ? () {
              SystemMessages.shared.emit(
                'LINK REQUEST / ${verified ? candidate : store.selectedId}',
              );
              widget.inspect(verified ? candidate! : store.selectedId!);
            }
          : null,
      'TRACK': candidate != null && visible && !scanning
          ? () {
              setState(
                () => lockedTarget = lockedTarget == null ? candidate : null,
              );
              SystemMessages.shared.emit(
                lockedTarget == null
                    ? 'TARGET RELEASED'
                    : 'TARGET LOCK / $candidate / MANUAL',
              );
            }
          : null,
    });
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: CameraDisplay(
                  key: const Key('optical-feed'),
                  store: store,
                  cameraId: camera.id,
                  onTarget: aim,
                  candidateId: candidate,
                  identifiedId: verified ? identified : null,
                  showReticle: reticle || scanning || lockedTarget != null,
                  scanning: scanning,
                ),
              ),
              Positioned(
                left: 14,
                top: 76,
                child: SizedBox(
                  height: 44,
                  child: SoftKey(
                    key: const Key('optical-channel-selector'),
                    label:
                        'CH ${String.fromCharCode(65 + angles.indexOf(camera))} / ${camera.status == 'OFFLINE' ? 'NO SIGNAL' : 'ACTIVE'}',
                    color: ink,
                    onPressed: channels,
                  ),
                ),
              ),
              if (signal != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: background.withValues(alpha: .94),
                    child: Center(
                      child: Text(
                        'OPTICAL / $signal',
                        key: const Key('optical-sync'),
                        style: const TextStyle(fontSize: 10, letterSpacing: 3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: verified ? 46 : 28,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                scanning
                    ? 'SCANNING / SIGNATURE ACQUISITION'
                    : verified
                    ? 'TARGET ${candidate!.split('-').last} / CLASS ${target?.subtype}\nDEVICE / $candidate   CONF / NOT SCORED'
                    : lockedTarget != null
                    ? 'TARGET LOCK / $candidate / MANUAL'
                    : candidate != null
                    ? 'TARGET CANDIDATE / SCAN REQUIRED'
                    : 'OBSERVE / ACQUIRE TARGET',
                key: const Key('optical-target-state'),
                style: const TextStyle(
                  fontSize: 9,
                  color: accent,
                  height: 1.6,
                  letterSpacing: .7,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
