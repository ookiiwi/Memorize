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

  static const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails('your channel id', 'your channel name',
          channelDescription: 'your channel description',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker');

  static const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

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
    //TODO: Uncomment for release
    //tz.TZDateTime time = tz.TZDateTime.now(tz.local);
    //assert(time.hour + time.minute >= 0 && time.hour + time.minute <= 15);

    for (Reminder reminder in _reminders) {
      computeReminder(reminder);
    }
  }

  static init() async {
    if (_isInit) return;
    _isInit = true;
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: (value) {
      runApp(MyApp(
        listToOpen: value,
      ));
    });

    DateTime now = DateTime.now();
    DateTime midnight = DateTime(now.year, now.month, now.day + 1);
    //TODO: uncomment for release
    int duration = 900; //midnight.difference(now).inSeconds;

    Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
    Workmanager().cancelAll();
    Workmanager().registerPeriodicTask('Reminder', 'computeReminders',
        initialDelay: Duration(seconds: duration),
        frequency: const Duration(days: 1));

    tz.initializeTimeZones();
    String timezone = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone));

    flutterLocalNotificationsPlugin.cancelAll();

    print('init reminder');
  }

  static int _computeNotifInterval(int daysFromStart, double factor) {
    int n = daysFromStart;
    double a = factor; //10000;
    double mini = (a * n - (pi / 2)) / (2 * pi);
    double maxi = (a * n + a - (pi / 2)) / (2 * pi);
    return (maxi - mini).toInt();
  }

  static void computeReminder(Reminder reminder, {bool fromNow = true}) async {
    int n = daysBetween(reminder.start, DateTime.now());
    DateTime now = DateTime.now();
    DateTime minTime =
        fromNow ? now : DateTime(now.year, now.month, now.day, 8);
    DateTime maxTime = DateTime(now.year, now.month, now.day, 23, 10);
    int time = maxTime.difference(minTime).inSeconds;
    int maxNotif = _computeNotifInterval(n, reminder.freqFactor);

    //int stop = 0;

    for (int i = 1; i <= maxNotif; ++i) {
      int reminderTime = (time / maxNotif * i).toInt();
      int hour = (reminderTime / 3600).floor() + minTime.hour % 60;
      int minute = (reminderTime % 3600 / 60).floor() + minTime.minute % 60;
      int second = (reminderTime % 3600 % 60) + minTime.second % 60;

      tz.TZDateTime date = tz.TZDateTime.now(tz.local);
      tz.TZDateTime schedule = tz.TZDateTime(
          tz.local, date.year, date.month, date.day, hour, minute, second);

      if (date.millisecondsSinceEpoch > schedule.millisecondsSinceEpoch) {
        continue;
      }
      //if (stop > 1) return;
//
      //stop += 1;

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

    int id = data.firstWhere((e) {
      return e.payload! == path;
    }, orElse: () => const PendingNotificationRequest(-1, '', '', '')).id;
    if (id >= 0) {
      await flutterLocalNotificationsPlugin.cancel(id);
    }

    pendingNotificationRequests =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }
}
