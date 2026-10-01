import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'instruments.dart';
import 'theme.dart';

typedef DeviceCommand = Future<void> Function(String action, Object? value);

class DeviceInterface extends StatelessWidget {
  final SystemStore store;
  final bool allowed;
  final DeviceCommand command;
  const DeviceInterface({
    super.key,
    required this.store,
    required this.allowed,
    required this.command,
  });
  @override
  Widget build(BuildContext context) {
    final n = store.selected!;
    final color = switch (n.subtype) {
      'POWER' => SamTokens.amber,
      'SENSOR' => const Color(0xffb3cda4),
      'SERVER' || 'NETWORK' => SamTokens.blue,
      _ => accent,
    };
    final title = switch (n.subtype) {
      'POWER' => 'POWER DISTRIBUTION / BUS.04',
      'DOOR' => 'HATCH CONTROL / INTERLOCK',
      'CAMERA' => 'OPTICAL ARRAY / AXIS CONTROL',
      'LIGHT' => 'ILLUMINATION / DRIVER',
      'SENSOR' => 'ENVIRONMENT / THERMAL PROBE',
      'SERVER' => 'COMPUTE NODE / SERVICE TERMINAL',
      'NETWORK' => 'NETWORK / ROUTE MANAGEMENT',
      'ROBOT' => 'ROBOTICS / SERVICE BUS',
      _ => 'MODULE / STATUS CHANNEL',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'RobotoCondensed',
            color: color,
            fontSize: 15,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: n.subtype == 'POWER' ? 215 : 160,
          child: CustomPaint(
            painter: DeviceSchematic(
              type: n.subtype,
              color: color,
              powered: n.controls['power'] == true,
              open: n.controls['door'] == 'open',
              level: (n.controls['brightness'] as num? ?? 0).toDouble(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (n.subtype == 'POWER') ...[
          Reading('POWER RESERVE', '${n.telemetry['power']} %', color: color),
          Reading(
            'OUTPUT',
            n.status == 'OFFLINE' ? 'INHIBITED' : 'ACTIVE',
            color: color,
          ),
          Reading(
            'BREAKER',
            n.controls['power'] == true
                ? 'CLOSED / BUS ACTIVE'
                : 'OPEN / ISOLATED',
            color: color,
          ),
          Reading(
            'PROTECTION',
            n.fault ?? 'NOMINAL',
            color: n.fault == null ? color : critical,
          ),
          const Text(
            'VOLTAGE / CURRENT PROBES : NOT INSTRUMENTED',
            style: TextStyle(fontSize: 8, color: muted),
          ),
          if (store.canControl)
            Wrap(
              children: [
                SoftKey(
                  key: const Key('power-on'),
                  label: 'BUS RESTORE / 恢复供电',
                  color: color,
                  onPressed: allowed ? () => command('power', true) : null,
                ),
                SoftKey(
                  key: const Key('power-off'),
                  label: 'ISOLATE BUS / 隔离供电',
                  color: color,
                  onPressed: allowed ? () => command('power', false) : null,
                ),
              ],
            ),
        ] else if (n.subtype == 'DOOR') ...[
          Reading(
            'HATCH',
            n.controls['door'].toString().toUpperCase(),
            color: color,
          ),
          Reading(
            'INTERLOCK',
            n.controls['door'] == 'open' ? 'RELEASED' : 'ENGAGED',
            color: color,
          ),
          const Text(
            'PRESSURE / SEAL PROBES : NOT INSTRUMENTED',
            style: TextStyle(fontSize: 8, color: muted),
          ),
          if (store.canControl)
            Wrap(
              children: [
                SoftKey(
                  label: 'OPEN HATCH',
                  onPressed: allowed ? () => command('door', 'open') : null,
                ),
                SoftKey(
                  label: 'CLOSE / LOCK',
                  onPressed: allowed ? () => command('door', 'closed') : null,
                ),
              ],
            ),
        ] else if (n.subtype == 'CAMERA') ...[
          Reading(
            'SIGNAL',
            '${n.telemetry['signal']} / ${n.telemetry['fps']} FPS',
            color: color,
          ),
          for (final axis in ['pan', 'tilt', 'zoom'])
            ControlSlider(
              key: ValueKey('${n.id}-$axis'),
              label: axis.toUpperCase(),
              min: axis == 'pan'
                  ? -90
                  : axis == 'tilt'
                  ? -45
                  : 1,
              max: axis == 'pan'
                  ? 90
                  : axis == 'tilt'
                  ? 45
                  : 4,
              value: (n.controls[axis] as num).toDouble(),
              enabled: allowed,
              onSubmit: (v) => command(axis, v),
            ),
        ] else if (n.subtype == 'LIGHT') ...[
          Reading('DRIVER', '${n.controls['brightness']} %', color: color),
          ControlSlider(
            key: ValueKey('${n.id}-brightness'),
            label: 'LIGHT OUTPUT',
            min: 0,
            max: 100,
            value: (n.controls['brightness'] as num).toDouble(),
            enabled: allowed,
            onSubmit: (v) => command('brightness', v),
          ),
        ] else if (n.subtype == 'SENSOR') ...[
          Reading(
            'TEMPERATURE',
            '${n.telemetry['temperature']} °C',
            color: color,
          ),
          Reading('CONDITION', n.fault ?? 'NOMINAL', color: color),
          const Text(
            'O₂ / CO₂ / PRESSURE : NO PROBE\nFAN : NO ACTUATOR',
            style: TextStyle(fontSize: 9, color: muted, height: 1.7),
          ),
        ] else if (n.subtype == 'SERVER' || n.subtype == 'NETWORK') ...[
          Reading(
            'LINK',
            n.controls['connected'] == true ? 'ACTIVE' : 'ISOLATED',
            color: color,
          ),
          Reading('LATENCY', '${n.telemetry['latency']} MS', color: color),
          Reading('UPTIME', '${n.telemetry['uptime']} SEC', color: color),
          if (n.subtype == 'SERVER')
            const Text(
              'PROCESS / MEMORY METRICS : NOT INSTRUMENTED',
              style: TextStyle(fontSize: 8, color: muted),
            ),
        ] else ...[
          Reading('THERMAL', '${n.telemetry['temperature']} °C', color: color),
          Reading('LINK', n.status, color: color),
        ],
        const Divider(height: 28),
        if (store.canControl)
          Wrap(
            spacing: 8,
            children: [
              if (n.capabilities.contains('diagnostic'))
                SoftKey(
                  label: n.subtype == 'POWER'
                      ? 'BUS DIAGNOSTIC'
                      : 'RUN DIAGNOSTIC',
                  color: color,
                  onPressed: allowed ? () => command('diagnostic', null) : null,
                ),
              if (n.capabilities.contains('recover'))
                SoftKey(
                  key: const Key('recover-device'),
                  label: n.subtype == 'POWER'
                      ? 'RESET PROTECTION'
                      : 'FAULT RECOVERY',
                  color: color,
                  onPressed: allowed ? () => command('recover', null) : null,
                ),
              if (n.capabilities.contains('restart'))
                SoftKey(
                  label: n.subtype == 'SERVER'
                      ? 'RESTART PROCESS NODE'
                      : 'RESTART INTERFACE',
                  color: color,
                  onPressed: allowed ? () => command('restart', null) : null,
                ),
              if (n.capabilities.contains('disconnect'))
                SoftKey(
                  label: 'ISOLATE NETWORK LINK',
                  color: color,
                  onPressed: allowed ? () => command('disconnect', null) : null,
                ),
            ],
          ),
      ],
    );
  }
}

class ControlSlider extends StatefulWidget {
  final String label;
  final double min, max, value;
  final bool enabled;
  final ValueChanged<double> onSubmit;
  const ControlSlider({
    super.key,
    required this.label,
    required this.min,
    required this.max,
    required this.value,
    required this.enabled,
    required this.onSubmit,
  });
  @override
  State<ControlSlider> createState() => _ControlSliderState();
}

class _ControlSliderState extends State<ControlSlider> {
  double? draft;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Reading(widget.label, (draft ?? widget.value).toStringAsFixed(1)),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 1,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
          overlayShape: SliderComponentShape.noOverlay,
        ),
        child: Slider(
          min: widget.min,
          max: widget.max,
          value: (draft ?? widget.value)
              .clamp(widget.min, widget.max)
              .toDouble(),
          onChanged: widget.enabled ? (v) => setState(() => draft = v) : null,
          onChangeEnd: widget.enabled
              ? (v) {
                  widget.onSubmit(v);
                  setState(() => draft = null);
                }
              : null,
        ),
      ),
    ],
  );
}

class DeviceSchematic extends CustomPainter {
  final String type;
  final Color color;
  final bool powered, open;
  final double level;
  DeviceSchematic({
    required this.type,
    required this.color,
    required this.powered,
    required this.open,
    required this.level,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke;
    final w = size.width, h = size.height;
    void label(String text, Offset p, {double fontSize = 9}) {
      final t = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: fontSize,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(canvas, p);
    }

    if (type == 'POWER') {
      canvas.drawLine(Offset(10, h * .35), Offset(w * .43, h * .35), pen);
      canvas.drawLine(Offset(w * .58, h * .35), Offset(w - 16, h * .35), pen);
      canvas.drawCircle(Offset(w * .43, h * .35), 3, pen);
      canvas.drawCircle(Offset(w * .58, h * .35), 3, pen);
      canvas.drawLine(
        Offset(w * .43, h * .35),
        Offset(w * .58, h * (powered ? .35 : .2)),
        pen..strokeWidth = 1.5,
      );
      for (var i = 0; i < 3; i++) {
        final x = w * (.28 + i * .27);
        canvas.drawLine(
          Offset(x, h * .35),
          Offset(x, h * .75),
          pen..strokeWidth = .8,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, h * .6), width: 12, height: 30),
          pen,
        );
        canvas.drawLine(Offset(x - 8, h * .75), Offset(x + 8, h * .75), pen);
        canvas.drawLine(Offset(x - 5, h * .78), Offset(x + 5, h * .78), pen);
        label('BUS ${i + 1}', Offset(x - 20, h * .88));
      }
      label('SOURCE / PWR', const Offset(8, 10));
      label('CB / 01', Offset(w * .44, h * .43));
      label(
        powered ? 'OUTPUT ENABLED' : 'OUTPUT ISOLATED',
        Offset(w * .45, 10),
      );
    } else if (type == 'DOOR') {
      final rect = Rect.fromCenter(
        center: Offset(w / 2, h / 2),
        width: w * .45,
        height: h * .8,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(30)),
        pen,
      );
      canvas.drawLine(
        Offset(w / 2 + (open ? w * .16 : 0), rect.top + 12),
        Offset(w / 2 + (open ? w * .16 : 0), rect.bottom - 12),
        pen,
      );
      canvas.drawCircle(Offset(w / 2, h / 2), 24, pen);
      label(open ? 'UNSEALED' : 'INTERLOCK', Offset(4, h / 2));
    } else if (type == 'CAMERA') {
      final center = Offset(w / 2, h / 2);
      canvas.drawCircle(center, 52, pen);
      canvas.drawCircle(center, 36, pen);
      canvas.drawLine(
        Offset(10, h / 2),
        Offset(w - 10, h / 2),
        pen..color = color.withValues(alpha: .4),
      );
      canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), pen);
      label('PAN', Offset(w - 44, h / 2 + 8));
      label('TILT', Offset(w / 2 + 8, 0));
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        canvas.drawLine(
          center + Offset(math.cos(a), math.sin(a)) * 53,
          center + Offset(math.cos(a), math.sin(a)) * 58,
          pen,
        );
      }
    } else if (type == 'LIGHT') {
      final center = Offset(w / 2, h * .2);
      canvas.drawCircle(center, 8, pen);
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(w * .15, h * .9)
        ..lineTo(w * .85, h * .9)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: level / 100 * .16),
      );
      canvas.drawPath(path, pen);
      label('LUMEN DRIVER', const Offset(4, 4));
    } else if (type == 'SENSOR') {
      final path = Path()..moveTo(0, h * .75);
      for (double x = 0; x < w; x += 4)
        path.lineTo(x, h * .6 + math.sin(x / w * 10) * h * .16);
      canvas.drawPath(path, pen);
      canvas.drawLine(Offset(0, h * .9), Offset(w, h * .9), pen..color = line);
      label('SENSOR PATH / SCHEMATIC', const Offset(4, 4));
    } else {
      label('SERVICE BUS / $type', const Offset(4, 4));
      for (var i = 0; i < 4; i++) {
        final x = w * (.13 + i * .24);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(x, h * .52),
            width: w * .12,
            height: 40,
          ),
          pen,
        );
        if (i > 0)
          canvas.drawLine(
            Offset(x - w * .18, h * .52),
            Offset(x - w * .06, h * .52),
            pen,
          );
        label('${i + 1}'.padLeft(2, '0'), Offset(x - 8, h * .52 - 6));
      }
      label('RX ───── TX ───── CONTROL', Offset(4, h * .85));
    }
  }

  @override
  bool shouldRepaint(covariant DeviceSchematic oldDelegate) =>
      powered != oldDelegate.powered ||
      open != oldDelegate.open ||
      level != oldDelegate.level ||
      type != oldDelegate.type;
}
