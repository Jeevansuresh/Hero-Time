import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'store.dart';

/// Daily reminder. Instead of one repeating alarm we schedule the next 14 days as
/// individual notifications and re-plan them whenever data changes. That lets us
/// (a) skip today once everything is logged and (b) name what's still pending.
class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static Future<void> _queue = Future.value();
  static const _days = 14;
  static const _baseId = 100;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_reminder',
      'Daily reminder',
      channelDescription: 'A nudge to log your habits',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static const _lines = [
    'Two taps and your day is logged.',
    "Don't let the Omnitrix time out.",
    'Small days add up. Log this one.',
    'The Omnitrix is charged. Time to log.',
    'Quick check-in before bed?',
    'Every green square is a mission complete.',
    'Log it while you remember it.',
  ];

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Reminders.init failed: $e');
    }
  }

  static Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> showTest(String petName) async {
    if (!_ready) return;
    await _plugin.show(1, '⌚ Hero Time is online', 'Reminders are working, $petName. See you later.', _details);
  }

  /// Serialised so rapid edits don't interleave cancel/schedule calls.
  static void reschedule(AppStore s) {
    _queue = _queue.then((_) => _plan(s)).catchError((Object e) {
      debugPrint('Reminders.reschedule failed: $e');
    });
  }

  static Future<void> _plan(AppStore s) async {
    if (!_ready) return;
    for (var i = 0; i < _days; i++) {
      await _plugin.cancel(_baseId + i);
    }
    final st = s.settings;
    if (!st.reminderOn || s.habits.isEmpty) return;

    final now = DateTime.now();
    for (var i = 0; i < _days; i++) {
      final at = DateTime(now.year, now.month, now.day + i, st.hour, st.minute);
      if (!at.isAfter(now)) continue;

      String body;
      if (i == 0) {
        final pending = s.pendingToday;
        if (pending.isEmpty && st.skipIfLogged) continue;
        body = pending.isEmpty
            ? 'All missions done today. Hero work. 💚'
            : 'Still to log: ${pending.map((h) => h.name).join(', ')}';
      } else {
        body = _lines[(at.day + i) % _lines.length];
      }

      // The absolute instant is correct in UTC, so no timezone lookup is needed.
      await _plugin.zonedSchedule(
        _baseId + i,
        '⌚ It\'s hero time, ${st.petName}',
        body,
        tz.TZDateTime.from(at, tz.UTC),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
