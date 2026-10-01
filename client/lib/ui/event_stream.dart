import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'theme.dart';

class EventStream extends StatelessWidget {
  final SystemStore store;
  const EventStream({super.key, required this.store});
  @override
  Widget build(BuildContext context) {
    final events =
        (store.displayEvents.isEmpty ? store.logs : store.displayEvents)
            .take(3)
            .toList();
    return ClipRect(
      child: SizedBox(
        height: 74,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, .12),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Column(
            key: ValueKey(events.isEmpty ? 'standby' : events.first['cursor']),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (events.isEmpty)
                const Text(
                  'SYS > MONITOR CHANNEL READY',
                  style: TextStyle(fontSize: 9, color: muted),
                ),
              for (var i = 0; i < events.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${_time(events[i]['time'])}  ${events[i]['category']} / ${events[i]['node_id'] ?? 'CORE'}\n${events[i]['message']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8,
                        height: 1.35,
                        color: accent.withValues(alpha: 1 - i * .26),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _time(Object? value) {
    final time = DateTime.tryParse(value?.toString() ?? '')?.toUtc();
    if (time == null) return '--:--:--.---';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}.${time.millisecond.toString().padLeft(3, '0')}';
  }
}
