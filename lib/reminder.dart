import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:memorize/data.dart';
import 'package:memorize/main.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) {
    ReminderNotification._callbackDispatcher(taskName, inputData);

    return Future.value(true);
  });
}

class Reminder {
  Reminder(this.start, this.path) {
    freqFactor = initFreq;
  }

  final double initFreq = 20;
  final double freqStep = 1;
  final DateTime start;

  String path;
  late double freqFactor;
}

class ReminderNotification {
  static FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('app_icon');
  static const InitializationSettings initializationSettings =
      InitializationSettings(
    android: initializationSettingsAndroid,
  );

  static List<Reminder> _reminders = [];
  static void add(Reminder reminder) async {
    if (update(reminder)) return;

    _reminders.add(reminder);
    computeReminder(reminder);
  }

  static bool update(Reminder reminder) {
    int i = _reminders.indexWhere((e) => e.path == reminder.path);
    if (i >= 0) _reminders[i] = reminder;

    return i >= 0;
  }

  static bool _isInit = false;

  static void _callbackDispatcher(
      String task, Map<String, dynamic>? inputData) async {
    print('compute');
    for (Reminder reminder in _reminders) {
      computeReminder(reminder);
    }
  }

  static init() async {
    if (_isInit) return;
    _isInit = true;
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: (value) {
      print('tap $value');
      runApp(MyApp(
        listToGoTo: value,
      ));
    });

    DateTime now = DateTime.now();
    DateTime midnight = DateTime(now.year, now.month, now.day + 1);
    int duration = 900; //midnight.difference(now).inSeconds;

    print(duration);

    Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
    Workmanager().cancelAll();
    Workmanager().registerPeriodicTask('Reminder', 'computeReminders',
        initialDelay: Duration(seconds: duration),
        frequency: const Duration(days: 1));

    tz.initializeTimeZones();
    String timezone = await FlutterNativeTimezone.getLocalTimezone();
    print(timezone);
    tz.setLocalLocation(tz.getLocation(timezone));
    print(tz.local);
  }

  static void computeReminder(Reminder reminder) async {
    int n = daysBetween(reminder.start, DateTime.now());
    double a = reminder.freqFactor; //10000;
    double mini = (a * n - (pi / 2)) / (2 * pi);
    double maxi = (a * n + a - (pi / 2)) / (2 * pi);
    int time = (24 - 8) * 3600;

    print('now: ${DateTime.now()}');

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    int stop = 0;

    for (int i = 0; i < maxi - mini; ++i) {
      int reminderTime = (time / (maxi - mini) * i).toInt();
      int hour = (reminderTime / 3600).floor() + 8;
      int minute = (reminderTime % 3600 / 60).floor();
      int second = (reminderTime % 3600 % 60);

      tz.TZDateTime date = tz.TZDateTime.now(tz.local);
      //tz.TZDateTime date = tz.TZDateTime.from(DateTime.now(), tz.local);
      tz.TZDateTime schedule = tz.TZDateTime(
          tz.local, date.year, date.month, date.day, hour, minute, second);

      if (date.millisecondsSinceEpoch > schedule.millisecondsSinceEpoch) {
        continue;
      }
      if (stop > 1) return;
      print(
          '$date $schedule ${date.millisecondsSinceEpoch > schedule.millisecondsSinceEpoch}');

      print(
          'i=$i time: $schedule for n=$n, a=$a, min=$mini, max=$maxi, range=${maxi - mini}\n');

      stop += 1;

      await flutterLocalNotificationsPlugin.zonedSchedule(i, 'scheduled title',
          'scheduled body', schedule, platformChannelSpecifics,
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: reminder.path);
    }
  }

  static void removeFirst(String path) async {
    List<PendingNotificationRequest> pendingNotificationRequests =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    List data = pendingNotificationRequests.map((e) {
      if (e.payload != null) return e;
    }).toList();

    print(
        'notif before rm: ${pendingNotificationRequests.map((e) => e.id).toList()}');

    int id = data.firstWhere((e) {
      print('${e.id}');
      return e.payload! == path;
    }, orElse: () => const PendingNotificationRequest(-1, '', '', '')).id;
    if (id >= 0) {
      print('rm $id');
      await flutterLocalNotificationsPlugin.cancel(id);
    }

    pendingNotificationRequests =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    print(
        'notif after rm: ${pendingNotificationRequests.map((e) => e.id).toList()}');
  }
}
