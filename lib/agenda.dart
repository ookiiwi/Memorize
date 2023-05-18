import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:isar/isar.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/data.dart';
import 'package:memorize/memo_list.dart';
import 'package:timezone/timezone.dart' as tz;

extension DateTimeDayOnly on DateTime {
  DateTime get dayOnly => DateTime(year, month, day);
  int get secondsSinceEpoch =>
      millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
}

class AgendaItem {
  AgendaItem(this.path, [Set<MemoListItem>? items]) : items = {};

  final String path;
  final Set<MemoListItem> items;
}

class Agenda {
  static const maxRemindersPerDay = 4;

  Future<void> clear() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// [date] must not be dayOnly
  static Future<MapEntry<int, Iterable<PendingNotificationRequest>>>
      _getPendingReminders(DateTime date) async {
    final minId = date.dayOnly.secondsSinceEpoch;
    final reminders =
        (await flutterLocalNotificationsPlugin.pendingNotificationRequests())
            .where((e) => e.id >= minId && e.id < minId + maxRemindersPerDay);

    return MapEntry(minId, reminders);
  }

  /// [date] must not be dayOnly
  static Future<void> _setReminders(DateTime date) async {
    final tmp = await _getPendingReminders(date);
    final minId = tmp.key;
    final reminders = tmp.value;

    // Reminders already set
    if (reminders.isNotEmpty) return;

    const reminderInterval = 24 ~/ maxRemindersPerDay;

    for (int i = 0; i < maxRemindersPerDay; ++i) {
      final now = DateTime.now();
      final time = now.dayOnly
          .add(Duration(hours: (reminderInterval * (i + 1)).clamp(0, 23)));

      if (time.secondsSinceEpoch < now.secondsSinceEpoch) {
        continue;
      }

      assert(
          (await flutterLocalNotificationsPlugin.pendingNotificationRequests())
                  .any((e) => e.id == minId + i) ==
              false);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        minId + i,
        'Quiz time',
        'There is still items to review',
        tz.TZDateTime.from(time, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my channel id',
            'my channel name',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> _clearReminders(DateTime date) async {
    final reminders = (await _getPendingReminders(date)).value;

    for (var e in reminders) {
      await flutterLocalNotificationsPlugin.cancel(e.id);
    }
  }

  static Future<DateTime> schedule(
    MapEntry<String, MemoListItem> item,
    int quality, {
    void Function(int? prevQuality)? onGetItem,
  }) async {
    final tmpMeta = (await MemoItemMeta.filter()
            .entryIdEqualTo(item.value.id)
            .isKanjiEqualTo(item.value.isKanji)
            .findAll())
        .firstOrNull;

    final meta = tmpMeta ??
        MemoItemMeta(
          entryId: item.value.id,
          isKanji: item.value.isKanji,
        );

    final sm2 = meta.sm2.compute(quality);
    final date = DateTime.now().add(Duration(days: sm2.interval));

    if (onGetItem != null) {
      onGetItem(tmpMeta != null ? meta.sm2.quality : null);
    }

    assert(date.dayOnly.difference(DateTime.now().dayOnly).inDays > 0);

    meta
      ..sm2 = sm2
      ..quizDate = date.dayOnly
      ..quizListPath = item.key;

    await meta.save();
    await _setReminders(date);

    print('saved meta: $meta');

    return date.dayOnly;
  }

  /// Moves entries with date older than today
  static void adjustSchedule([DateTime? date]) {
    throw UnimplementedError();

    date ??= DateTime.now();
    //final dayOnly = date.dayOnly;
    /*
    final pastDates = _agenda.keys
        .where((e) => e.secondsSinceEpoch < dayOnly.secondsSinceEpoch)
        .toList();

    if (pastDates.isEmpty) return;

    for (var e in pastDates) {
      final items = _agenda.remove(e);

      if (items != null) {
        _agenda[dayOnly] ??= {};
        _agenda[dayOnly]!.addAll(items);
      }
    }
    */
  }
}
