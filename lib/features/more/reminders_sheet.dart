import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_prefs.dart';
import '../../core/notifications.dart';

Future<void> showRemindersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _RemindersSheet(),
  );
}

class _RemindersSheet extends ConsumerStatefulWidget {
  const _RemindersSheet();

  @override
  ConsumerState<_RemindersSheet> createState() => _RemindersSheetState();
}

class _RemindersSheetState extends ConsumerState<_RemindersSheet> {
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    _enabled = prefs.getBool('reminder_enabled') ?? false;
    _time = TimeOfDay(
        hour: prefs.getInt('reminder_hour') ?? 20,
        minute: prefs.getInt('reminder_minute') ?? 0);
  }

  Future<void> _apply() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setInt('reminder_hour', _time.hour);
    await prefs.setInt('reminder_minute', _time.minute);
    if (_enabled) {
      final ok = await NotificationService.requestPermission();
      if (ok) {
        await NotificationService.scheduleDaily(_time.hour, _time.minute);
        await prefs.setBool('reminder_enabled', true);
      } else {
        await prefs.setBool('reminder_enabled', false);
        if (mounted) {
          setState(() => _enabled = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Turn on notifications in system settings first.')));
        }
      }
    } else {
      await prefs.setBool('reminder_enabled', false);
      await NotificationService.cancelDaily();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Daily reminder'),
              subtitle: const Text('A nudge to log your expenses'),
              value: _enabled,
              onChanged: (v) {
                setState(() => _enabled = v);
                _apply();
              },
            ),
            if (_enabled)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Time'),
                trailing: Text(_time.format(context)),
                onTap: () async {
                  final t =
                      await showTimePicker(context: context, initialTime: _time);
                  if (t != null) {
                    setState(() => _time = t);
                    _apply();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
