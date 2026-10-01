import 'package:flutter/material.dart';
import 'instruments.dart';
import 'theme.dart';

// The visible display binds its own operations. This strip routes intentions;
// device authorization and commands remain in SystemStore and the server.
class TerminalActions {
  final Map<String, VoidCallback?> _actions = {};
  void reset(Map<String, VoidCallback?> actions) {
    _actions
      ..clear()
      ..addAll(actions);
  }

  void bind(Map<String, VoidCallback?> actions) => _actions.addAll(actions);
  void invoke(String action) {
    final callback = _actions[action];
    if (callback != null)
      callback();
    else
      SystemMessages.shared.emit('$action / NO AVAILABLE TARGET', error: true);
  }
}

Future<String?> terminalSelect(
  BuildContext context,
  String title,
  Iterable<String> choices,
) => showDialog<String>(
  context: context,
  builder: (c) => Dialog(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                color: muted,
                letterSpacing: 2,
              ),
            ),
            const Divider(height: 24),
            for (final choice in choices)
              SoftKey(label: choice, onPressed: () => Navigator.pop(c, choice)),
            SoftKey(label: 'CANCEL <', onPressed: () => Navigator.pop(c)),
          ],
        ),
      ),
    ),
  ),
);
