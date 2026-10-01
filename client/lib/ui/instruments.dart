import 'package:flutter/material.dart';
import 'theme.dart';
import 'errors.dart';

class Panel extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;
  const Panel({super.key, required this.title, required this.child, this.trailing, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: surface, border: Border.all(color: line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: line))),
        child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 11, letterSpacing: 1.5, color: accent))), if (trailing != null) trailing!])),
      Padding(padding: padding, child: child),
    ]),
  );
}

class Reading extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const Reading(this.label, this.value, {super.key, this.color = ink});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Text(label, style: const TextStyle(color: muted, fontSize: 11))),
      Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: color, fontSize: 12))),
    ]));
}

class StatusLamp extends StatelessWidget {
  final String status;
  const StatusLamp(this.status, {super.key});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 5, height: 5, color: statusColor(status)), const SizedBox(width: 7),
    Text(status, style: TextStyle(color: statusColor(status), fontSize: 10, letterSpacing: 1)),
  ]);
}

Future<void> report(BuildContext context, Future<void> Function() action) async {
  try { await action(); }
  catch (error) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(explainError(error, Localizations.localeOf(context).languageCode == 'zh')), backgroundColor: const Color(0xff442726)));
  }
}
