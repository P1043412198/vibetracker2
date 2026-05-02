import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Wrapper around `flutter_local_notifications` that owns:
///   * timezone init
///   * Android channel + boot-receiver setup
///   * runtime permission request flow
///   * scheduling primitives (daily-on-weekday and one-shot)
///
/// Notification IDs are derived from the (entity-id, weekday) pair so we can
/// cancel + reschedule deterministically when a habit's reminder changes.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const AndroidNotificationChannel _habitsChannel =
      AndroidNotificationChannel(
    'habits_channel',
    'Привычки',
    description: 'Напоминания о привычках',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _tasksChannel =
      AndroidNotificationChannel(
    'tasks_channel',
    'Задачи',
    description: 'Напоминания о задачах',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e, st) {
      // Fall back to UTC if the platform refuses to surface a tz name.
      debugPrint('NotificationService: failed to read local tz: $e\n$st');
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(initSettings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(_habitsChannel);
      await android.createNotificationChannel(_tasksChannel);
    }
    _initialized = true;
  }

  /// Best-effort runtime permission ask. Returns `true` when notifications
  /// can be displayed.
  Future<bool> requestPermissions() async {
    await init();
    // Android 13+
    final notif = await Permission.notification.status;
    bool granted = notif.isGranted;
    if (!granted) {
      final res = await Permission.notification.request();
      granted = res.isGranted;
    }
    // Exact-alarm permission is only relevant for `zonedSchedule` on
    // Android 12+. Best-effort — failure does not block inexact reminders.
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
    return granted;
  }

  /// Returns a deterministic notification ID for a given key.
  /// Stable across schedules so `cancel(_idFor(...))` matches the original.
  int _idFor(String key) {
    // Hash to a 31-bit positive int (Android requires Int).
    int h = 0;
    for (final c in key.codeUnits) {
      h = (0x1FFFFFFF & (h * 31 + c));
    }
    return h;
  }

  /// Schedule a daily reminder repeating on given weekdays
  /// ([weekdays] uses ISO Mon=1..Sun=7). Cancels any prior reminders for
  /// [habitId] before re-scheduling.
  Future<void> scheduleHabitDaily({
    required String habitId,
    required String habitTitle,
    required int hour,
    required int minute,
    required Set<int> weekdays,
  }) async {
    await init();
    await cancelHabit(habitId);
    if (weekdays.isEmpty) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'habits_channel',
        'Привычки',
        channelDescription: 'Напоминания о привычках',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    for (final wd in weekdays) {
      final id = _idFor('habit:$habitId:$wd');
      final tzTime = _nextInstanceOfWeekday(hour, minute, wd);
      try {
        await _plugin.zonedSchedule(
          id,
          'Привычка: $habitTitle',
          'Не забудь отметить сегодняшний день',
          tzTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'habit:$habitId',
        );
      } catch (e) {
        // Some Android builds reject exact alarms — fall back to inexact.
        debugPrint('NotificationService: exact schedule failed → inexact: $e');
        await _plugin.zonedSchedule(
          id,
          'Привычка: $habitTitle',
          'Не забудь отметить сегодняшний день',
          tzTime,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'habit:$habitId',
        );
      }
    }
  }

  Future<void> cancelHabit(String habitId) async {
    await init();
    for (var wd = 1; wd <= 7; wd++) {
      await _plugin.cancel(_idFor('habit:$habitId:$wd'));
    }
  }

  /// One-shot task reminder. [when] is local time; if it's in the past the
  /// reminder is silently skipped.
  Future<void> scheduleTaskOnce({
    required String taskId,
    required String taskTitle,
    required DateTime when,
  }) async {
    await init();
    await cancelTask(taskId);
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    if (tzWhen.isBefore(tz.TZDateTime.now(tz.local))) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'tasks_channel',
        'Задачи',
        channelDescription: 'Напоминания о задачах',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final id = _idFor('task:$taskId');
    try {
      await _plugin.zonedSchedule(
        id,
        'Задача: $taskTitle',
        'Время выполнить эту задачу',
        tzWhen,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'task:$taskId',
      );
    } catch (e) {
      debugPrint('NotificationService: exact task alarm failed → inexact: $e');
      await _plugin.zonedSchedule(
        id,
        'Задача: $taskTitle',
        'Время выполнить эту задачу',
        tzWhen,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'task:$taskId',
      );
    }
  }

  Future<void> cancelTask(String taskId) async {
    await init();
    await _plugin.cancel(_idFor('task:$taskId'));
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfWeekday(int hour, int minute, int weekday) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
