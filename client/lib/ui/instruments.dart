import 'dart:async';
import 'package:flutter/material.dart';
import 'theme.dart';
import 'errors.dart';

// Legacy screens retain their content while sharing the open instrument layout.
class Panel extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;
  const Panel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Container(width: 3, height: 12, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'RobotoCondensed',
                fontSize: 11,
                letterSpacing: 1.7,
                color: accent,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
      const Divider(height: 12),
      Padding(padding: padding, child: child),
    ],
  );
}

class Reading extends StatelessWidget {
  final String label, value;
  final Color color;
  const Reading(this.label, this.value, {super.key, this.color = ink});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: muted, fontSize: 10, letterSpacing: .8),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _Leader(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: TextStyle(color: color, fontSize: 11, letterSpacing: .5),
          ),
        ),
      ],
    ),
  );
}

class _Leader extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = line
      ..strokeWidth = .5;
    for (double x = 0; x < size.width; x += 4) {
      canvas.drawLine(Offset(x, 0), Offset(x + 1, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StatusLamp extends StatelessWidget {
  final String status;
  const StatusLamp(this.status, {super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 3, height: 3, color: statusColor(status)),
      const SizedBox(width: 6),
      Text(
        status,
        style: TextStyle(
          color: statusColor(status),
          fontSize: 9,
          letterSpacing: 1.2,
        ),
      ),
    ],
  );
}

class SystemMessages extends ChangeNotifier {
  static final shared = SystemMessages();
  String? message;
  bool fault = false;
  Timer? _expiry;
  void emit(String text, {bool error = false}) {
    message = text;
    fault = error;
    _expiry?.cancel();
    notifyListeners();
    _expiry = Timer(const Duration(seconds: 5), () {
      message = null;
      notifyListeners();
    });
  }
}

class SystemMessageLine extends StatelessWidget {
  const SystemMessageLine({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: SystemMessages.shared,
    builder: (_, __) {
      final messages = SystemMessages.shared;
      return SizedBox(
        height: 32,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              messages.message == null
                  ? 'SYS > EVENT CHANNEL / STANDBY'
                  : 'SYS > ${messages.message}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                letterSpacing: .6,
                color: messages.fault ? critical : accent,
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> report(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted)
      SystemMessages.shared.emit(
        'FAULT / ${explainError(error, Localizations.localeOf(context).languageCode == 'zh')}',
        error: true,
      );
  }
}

class SoftKey extends StatelessWidget {
  final String code, label;
  final VoidCallback? onPressed;
  final bool selected;
  final Color color;
  const SoftKey({
    super.key,
    this.code = '',
    required this.label,
    this.onPressed,
    this.selected = false,
    this.color = accent,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onPressed,
      mouseCursor: SystemMouseCursors.precise,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 1,
                width: selected ? 24 : 8,
                color: selected ? color : line,
              ),
              const SizedBox(height: 6),
              Text(
                '${code.isEmpty ? '' : '$code / '}$label',
                maxLines: 1,
                style: TextStyle(
                  color: onPressed == null
                      ? muted.withValues(alpha: .5)
                      : selected
                      ? ink
                      : color,
                  fontFamily: 'RobotoCondensed',
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class TerminalToggle extends StatelessWidget {
  final Widget title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const TerminalToggle({
    super.key,
    required this.title,
    required this.value,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: DefaultTextStyle(
          style: const TextStyle(color: ink, fontSize: 11, letterSpacing: .7),
          child: title,
        ),
      ),
      SoftKey(
        label: 'ON',
        selected: value,
        onPressed: onChanged == null ? null : () => onChanged!(true),
      ),
      SoftKey(
        label: 'OFF',
        selected: !value,
        onPressed: onChanged == null ? null : () => onChanged!(false),
      ),
    ],
  );
}
