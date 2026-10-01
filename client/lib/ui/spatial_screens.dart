import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'instruments.dart';
import 'station.dart';
import 'map_display.dart';
import 'camera_display.dart';
import 'theme.dart';
import 'terminal_actions.dart';
import 'terminal_effects.dart';
import 'event_stream.dart';

class OverviewScreen extends StatelessWidget {
  final SystemStore store;
  final ValueChanged<String> locate;
  final VoidCallback openMap;
  const OverviewScreen({
    super.key,
    required this.store,
    required this.locate,
    required this.openMap,
  });
  @override
  Widget build(BuildContext context) {
    final nodes = store.nodes.values.toList();
    final cameras = nodes.where((n) => n.type == 'CAMERA').toList();
    final sensors = nodes.where((n) => n.type == 'SENSOR').toList();
    final environment = !store.connected || sensors.isEmpty ? 'UNKNOWN'
      : store.paused ? 'HOLD'
      : sensors.any((n) => n.status != 'ONLINE') ? 'EXCEPTION' : 'NOMINAL';
    final faults = store.alerts.where((a) => a['state'] != 'RESOLVED').toList();
    return LayoutBuilder(
      builder: (_, box) => Stack(
        children: [
          Positioned(
            left: 18,
            top: 26,
            child: DisplayLayer(delay: 20, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SYSTEM / OVERVIEW',
                  style: TextStyle(
                    fontFamily: 'RobotoCondensed',
                    fontSize: 16,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'SYS.NODE.00 / REV 02.0',
                  style: TextStyle(color: muted, fontSize: 9),
                ),
                const SizedBox(height: 22),
                Text(
                  'CORE  ${store.connected ? 'ONLINE' : 'OFFLINE'}',
                  style: const TextStyle(fontSize: 10, color: accent),
                ),
                Text(
                  'NET   ${nodes.where((n) => n.status != 'OFFLINE').length.toString().padLeft(3, '0')} / 042',
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
                const SizedBox(height: 13),
                const Text('SYS.AI / WATCH MODE', style: TextStyle(fontSize: 8, color: muted, letterSpacing: 1)),
              ],
            )),
          ),
          Positioned(
            top: 130,
            right: 18,
            child: DisplayLayer(delay: 70, child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'PWR BUS  ${store.nodes['DEV-01']?.telemetry['power'] ?? '---'}',
                  style: const TextStyle(fontSize: 11, color: ink),
                ),
                const SizedBox(height: 23),
                Text(
                  'CAM ARRAY / ${cameras.where((n) => n.status != 'OFFLINE').length.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
                const SizedBox(height: 9),
                Text(
                  'ALT  ${faults.length.toString().padLeft(3, '0')}',
                  style: TextStyle(
                    color: faults.isEmpty ? muted : critical,
                    fontSize: 10,
                  ),
                ),
              ],
            )),
          ),
          Positioned.fill(
            top: 160,
            bottom: 155,
            child: GestureDetector(
              onTap: openMap,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: stationSize.width,
                  height: stationSize.height,
                  child: DisplayLayer(delay: 110, child: StationDisplay(store: store)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 128,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACTIVE SYSTEMS / ${nodes.where((n)=>n.type=='MODULE').length.toString().padLeft(2,'0')}',
                  style: const TextStyle(
                    color: accent,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'SENSOR ARRAY    $environment\nCONTROL BUS     ${store.connected ? 'READY' : 'STALE'}',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 9,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 118,
            child: SoftKey(label: 'RELOCATION >', onPressed: openMap),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                  Text(
                    'EVENT STREAM / ${!store.connected ? 'STALE' : store.paused ? 'HOLD' : 'LIVE'}',
                    style: const TextStyle(
                    color: muted,
                    fontSize: 8,
                    letterSpacing: 1.5,
                  ),
                ),
                EventStream(store: store),
              ],
            ),
          ),
          Positioned(left: 18, top: box.maxHeight * .46,
            child: DisplayLayer(delay: 40, child: Text('TEMP / ${store.nodes['SEN-01']?.telemetry['temperature'] ?? '--'} C',
              style: const TextStyle(fontSize: 8, color: muted)))),
          Positioned(right: 18, bottom: 203, child: Text(
            'UPLINK / ${store.nodes['NET-01']?.status ?? 'UNKNOWN'}\nENV / $environment',
            style: const TextStyle(fontSize: 8, color: muted, height: 2))),
        ],
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  final TerminalActions? actions;
  final SystemStore store;
  final ValueChanged<String> inspect, camera;
  const MapScreen({
    super.key,
    required this.store,
    required this.inspect,
    required this.camera,
    this.actions,
  });
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final transform = TransformationController();
  String? interior, selectedModule;
  bool initialized = false;
  bool faultOnly = false;
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  String? get activeModule => selectedModule ?? widget.store.selected?.module;
  void focus(String id) {
    setState(() => selectedModule = id);
  }

  void fit(Size size) {
    transform.value =
        Matrix4.diagonal3Values(
          size.width / stationSize.width * .95,
          size.width / stationSize.width * .95,
          1,
        )..setTranslationRaw(
          size.width * .025,
          (size.height -
                      stationSize.height *
                          size.width /
                          stationSize.width *
                          .95) /
                  2 -
              30,
          0,
        );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final module = activeModule;
    final cameras = store.nodes.values
        .where((n) => n.module == module && n.type == 'CAMERA')
        .toList();
    final members = store.nodes.values
        .where((n) => n.module == module && n.type != 'MODULE')
        .toList();
    widget.actions?.bind({
      'SELECT': () async {
        final id = await terminalSelect(context, 'MODULE SELECT', moduleCenters.keys);
        if (id != null && mounted) focus(id);
      },
      'CAMERA': cameras.isEmpty ? null : () => widget.camera(
        store.selected?.module == module ? store.selectedId! : cameras.first.id),
      'TRACE': module == null ? null : () => setState(() => interior = interior == null ? module : null),
      'FILTER': () => setState(() => faultOnly = !faultOnly),
    });
    return LayoutBuilder(
      builder: (context, box) {
        if (!initialized) {
          initialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) fit(Size(box.maxWidth, box.maxHeight));
          });
        }
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: InteractiveViewer(
                  transformationController: transform,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(300),
                  minScale: .15,
                  maxScale: 2.2,
                  child: MouseRegion(
                    onHover: (e) {
                      if (interior == null) {
                        for (final entry in moduleCenters.entries) {
                          if ((e.localPosition - entry.value).distance < 120 &&
                              selectedModule != entry.key) {
                            focus(entry.key);
                            break;
                          }
                        }
                      }
                    },
                    child: GestureDetector(
                      onTapUp: (e) {
                        if (interior != null) {
                          String? nearest;
                          var best = math.max(80.0, 22 / transform.value.getMaxScaleOnAxis());
                          for (final n in members) {
                            final distance = (e.localPosition - interiorPosition(n)).distance;
                            if (distance < best) {
                              nearest = n.id;
                              best = distance;
                            }
                          }
                          if (nearest != null) widget.inspect(nearest);
                        } else {
                          for (final entry in moduleCenters.entries) {
                            if ((e.localPosition - entry.value).distance <
                                145) {
                              focus(entry.key);
                              break;
                            }
                          }
                        }
                      },
                      child: SizedBox(
                        width: stationSize.width,
                        height: stationSize.height,
                        child: StationDisplay(store: store, selected: module,
                          interior: interior, faultOnly: faultOnly),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RELOCATION',
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontSize: 16,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    interior == null
                        ? 'NAV.RELOC.01 / ${faultOnly ? 'FAULT CHANNELS' : 'GRID 042.17'}'
                        : '$interior / INTERNAL VOLUME',
                    style: const TextStyle(
                      fontSize: 8,
                      color: muted,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: SoftKey(
                label: interior == null ? 'FIT' : 'STATION <',
                onPressed: () {
                  setState(() => interior = null);
                  fit(Size(box.maxWidth, box.maxHeight));
                },
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: module == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MODULE SELECT / AWAITING TARGET',
                          style: TextStyle(
                            fontSize: 10,
                            color: accent,
                            letterSpacing: 1,
                          ),
                        ),
                        Wrap(
                          children: [
                            for (final id in moduleCenters.keys)
                              SoftKey(
                                key: ValueKey('module-$id'),
                                label: id,
                                onPressed: () => focus(id),
                              ),
                          ],
                        ),
                      ],
                    )
                  : Container(
                      color: background.withValues(alpha: .88),
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      module,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                    Text(
                                      moduleNames[module] ?? 'MODULE',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: muted,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    for (final cam in cameras)
                                      Text(
                                        '${cam.id} / ${cam.status == 'OFFLINE' ? 'NO SIGNAL' : 'AVAILABLE'}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: statusColor(cam.status),
                                          height: 1.7,
                                        ),
                                      ),
                                    if (store.selected?.type != 'MODULE' &&
                                        store.selected?.module == module)
                                      Text(
                                        'TARGET / ${store.selectedId}',
                                        style: const TextStyle(
                                          color: warning,
                                          fontSize: 9,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 105,
                                height: 74,
                                child:
                                    cameras.isEmpty ||
                                        cameras.every(
                                          (n) => n.status == 'OFFLINE',
                                        )
                                    ? const Center(
                                        child: Text(
                                          'NO SIGNAL',
                                          style: TextStyle(
                                            color: muted,
                                            fontSize: 8,
                                          ),
                                        ),
                                      )
                                    : Image.asset(
                                        cameraAsset(
                                          cameras.firstWhere(
                                            (n) => n.status != 'OFFLINE',
                                            orElse: () => cameras.first,
                                          ),
                                        ),
                                        fit: BoxFit.cover,
                                        alignment: Alignment.center,
                                      ),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 6,
                            children: [
                              SoftKey(
                                key: const Key('relocate-camera'),
                                label: 'RELOCATE / CAM',
                                onPressed: cameras.isEmpty
                                    ? null
                                    : () => widget.camera(
                                        store.selected?.module == module &&
                                                store.selectedId != null
                                            ? store.selectedId!
                                            : module,
                                      ),
                              ),
                              SoftKey(
                                key: const Key('module-systems'),
                                label: interior == null
                                    ? 'MODULE SYSTEMS'
                                    : 'STATION VIEW',
                                onPressed: () {
                                  setState(
                                    () => interior = interior == null
                                        ? module
                                        : null,
                                  );
                                  fit(Size(box.maxWidth, box.maxHeight));
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class NetworkScreen extends StatefulWidget {
  final TerminalActions? actions;
  final SystemStore store;
  final ValueChanged<String> inspect;
  const NetworkScreen({super.key, required this.store, required this.inspect, this.actions});
  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  final transform = TransformationController();
  String search = '', filter = 'ALL';
  bool initialized = false;
  bool traced = false;
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    widget.actions?.bind({
      'SELECT': () async {
        final id = await terminalSelect(context, 'NET NODE SELECT', store.nodes.keys);
        if (id != null && mounted) store.selectNode(id);
      },
      'TRACE': store.selectedId == null ? null : () => setState(() => traced = !traced),
      'FILTER': () async {
        final type = await terminalSelect(context, 'NODE TYPE', ['ALL','CAMERA','DEVICE','SENSOR','SERVER','NETWORK','ROBOT','MODULE']);
        if (type != null && mounted) setState(() { filter = type; traced = false; });
      },
      'INSPECT': store.selectedId == null ? null : () => widget.inspect(store.selectedId!),
    });
    final matches = store.nodes.values
        .where(
          (n) =>
              (filter == 'ALL' || n.type == filter) &&
              '${n.id} ${n.subtype}'.toLowerCase().contains(
                search.toLowerCase(),
              ),
        )
        .map((n) => n.id)
        .toSet();
    final traceNodes = <String>{if (store.selectedId != null) store.selectedId!,
      for (final edge in store.edges) ...[
        if (edge['source'] == store.selectedId) edge['target'] as String,
        if (edge['target'] == store.selectedId) edge['source'] as String,
      ],
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              const Text(
                'NET.CORE.00 / BUS A',
                style: TextStyle(fontSize: 11, letterSpacing: 1.5),
              ),
              SizedBox(
                width: 170,
                child: TextField(
                  key: const Key('node-search'),
                  decoration: const InputDecoration(labelText: 'NODE QUERY'),
                  onChanged: (s) => setState(() { search = s; traced = false; }),
                ),
              ),
              DropdownButton<String>(
                value: filter,
                items:
                    [
                          'ALL',
                          'CAMERA',
                          'DEVICE',
                          'SENSOR',
                          'SERVER',
                          'ROBOT',
                          'NETWORK',
                          'MODULE',
                        ]
                        .map(
                          (x) => DropdownMenuItem(
                            value: x,
                            child: Text(
                              x,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (s) => setState(() { filter = s!; traced = false; }),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (_, box) {
              if (!initialized) {
                initialized = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted)
                    transform.value = Matrix4.diagonal3Values(
                      box.maxWidth / mapSize.width,
                      box.maxWidth / mapSize.width,
                      1,
                    );
                });
              }
              return MapDisplay(
                store: store,
                network: true,
                onSelect: widget.inspect,
                controller: transform,
                visible: traced ? traceNodes : filter == 'ALL' && search.isEmpty ? null : matches,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'CYAN / DATA    AMBER / POWER    RED / FAULT\n${traced ? 'TRACE / DIRECT DEPENDENCIES / ' : ''}${store.selectedId ?? 'NODE SELECT / STANDBY'}',
            style: const TextStyle(color: muted, fontSize: 9, height: 1.8),
          ),
        ),
      ],
    );
  }
}
