import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    await _configureLocalTimeZone();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification tapped: ${response.payload}");
      },
    );
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  }

  Future<bool> requestPermissions() async {
    // Android
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      // Request POST_NOTIFICATIONS (Android 13+).
      // On Android 12 and below, this returns null because the permission
      // doesn't exist — notifications are implicitly allowed.
      final bool? result =
          await androidImplementation.requestNotificationsPermission();
      // null means pre-Android 13 => implicitly granted
      debugPrint("requestNotificationsPermission() returned: $result");
      return result ?? true;
    }

    // iOS
    final iosImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (iosImplementation != null) {
      final bool? result = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return result ?? false;
    }

    return true;
  }

  Future<bool> hasExactAlarmPermission() async {
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation != null) {
      return await androidImplementation.canScheduleExactNotifications() ??
          false;
    }
    return true; // Non-Android platforms don't have this restriction
  }

  Future<void> openExactAlarmSettings() async {
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation != null) {
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'instant_test_channel',
          'Test Notifications',
          channelDescription: 'Channel for testing notifications',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.show(
      999, // Unique ID for test
      title,
      body,
      notificationDetails,
    );
  }

  Future<void> scheduleReminder({
    required String frequency,
    TimeOfDay? time,
  }) async {
    // 1. Cancel existing notifications first to avoid duplicates
    await flutterLocalNotificationsPlugin.cancelAll();

    if (frequency == 'None') {
      debugPrint("Reminders disabled — all notifications cancelled.");
      return;
    }

    // Default to 9:00 AM if no time provided
    final reminderTime = time ?? const TimeOfDay(hour: 9, minute: 0);

    // 2. Define schedule details
    var scheduledDate = _nextInstanceOfTime(reminderTime);

    // 3. Configure recurrence
    DateTimeComponents? matchComponents;

    if (frequency == 'Daily') {
      matchComponents = DateTimeComponents.time;
    } else if (frequency == 'Weekly') {
      matchComponents = DateTimeComponents.dayOfWeekAndTime;
    } else if (frequency == 'Monthly') {
      matchComponents = DateTimeComponents.dayOfMonthAndTime;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'expense_reminder_channel',
          'Expense Reminders',
          channelDescription: 'Reminders to check your expenses',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    // Check for exact alarm permission to avoid PlatformException on Android 14+
    bool canScheduleExact = await hasExactAlarmPermission();
    AndroidScheduleMode scheduleMode = canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    if (!canScheduleExact) {
      debugPrint(
        "Scheduling using INEXACT mode because exact alarm permission is missing.",
      );
    }

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'Time to check Spendr!',
        'Don\'t forget to log your expenses for the day.',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
      );
      debugPrint(
        "✅ Scheduled $frequency notification for $scheduledDate using $scheduleMode",
      );
    } catch (e) {
      debugPrint("❌ Failed to schedule with $scheduleMode: $e");
      // Fallback: try inexact mode if exact failed
      if (scheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
        try {
          await flutterLocalNotificationsPlugin.zonedSchedule(
            0,
            'Time to check Spendr!',
            'Don\'t forget to log your expenses for the day.',
            scheduledDate,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: matchComponents,
          );
          debugPrint(
            "✅ Fallback: scheduled $frequency notification using inexact mode",
          );
        } catch (e2) {
          debugPrint("❌ Fallback also failed: $e2");
        }
      }
    }
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
