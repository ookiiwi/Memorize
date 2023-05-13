import 'dart:io';

import 'package:binarize/binarize.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/lexicon.dart';
import 'package:timezone/timezone.dart' as tz;

extension DateTimeDayOnly on DateTime {
  DateTime get dayOnly => DateTime(year, month, day);
  int get secondsSinceEpoch =>
      millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
}

class Agenda {
  static const maxRemindersPerDay = 4;

  Agenda({Map<DateTime, Set<LexiconItem>>? agenda}) : _agenda = agenda ?? {};
  Agenda.decode(List<int> bytes) : _agenda = {} {
    _decode(bytes);
  }

  /// Stores items to play at specific day
  final Map<DateTime, Set<LexiconItem>> _agenda;

  Set<LexiconItem>? operator [](DateTime date) {
    final dayOnly = date.dayOnly;

    return _agenda[dayOnly]?.toSet();
  }

  @override
  String toString() => _agenda.toString();

  DateTime? getTime(LexiconItem item) {
    for (var e in _agenda.entries) {
      if (e.value.contains(item)) return e.key;
    }

    return null;
  }

  /// [date] must not be dayOnly
  Future<MapEntry<int, Iterable<PendingNotificationRequest>>>
      _getPendingReminders(DateTime date) async {
    final minId = date.dayOnly.secondsSinceEpoch;
    final reminders =
        (await flutterLocalNotificationsPlugin.pendingNotificationRequests())
            .where((e) => e.id >= minId && e.id < minId + maxRemindersPerDay);

    return MapEntry(minId, reminders);
  }

  /// [date] must not be dayOnly
  Future<void> _setReminders(DateTime date) async {
    final tmp = await _getPendingReminders(date);
    final minId = tmp.key;
    final reminders = tmp.value;

    // Reminders already set
    if (reminders.isNotEmpty) return;

    const reminderInterval = 24 ~/ maxRemindersPerDay;

    for (int i = 0; i < maxRemindersPerDay; ++i) {
      final now = DateTime.now();
      final time = now.dayOnly.add(Duration(hours: reminderInterval * (i + 1)));

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

  DateTime schedule(LexiconItem item) {
    final date = DateTime.now().add(Duration(days: item.sm2.interval));
    final dayOnly = date.dayOnly;

    for (var e in _agenda.keys) {
      if (_agenda[e]!.remove(item)) {
        break;
      }
    }

    _setReminders(date);

    _agenda[dayOnly] ??= {};
    _agenda[dayOnly]!.add(item);

    return dayOnly;
  }

  DateTime? unschedule(LexiconItem item, [DateTime? date]) {
    DateTime? scheduledDate;

    if (date != null) {
      final dayOnly = date.dayOnly;
      final isRemoved = _agenda[dayOnly]?.remove(item);

      if (isRemoved == true) {
        scheduledDate = dayOnly;
      }
    }

    if (scheduledDate == null) {
      for (var e in _agenda.entries) {
        if (e.value.remove(item)) return e.key;
      }
    }

    // Cancel reminders if scheduledDate's agenda is empty
    if (scheduledDate != null && _agenda[scheduledDate]?.isEmpty == true) {
      _clearReminders(scheduledDate);
    }

    return scheduledDate;
  }

  /// Moves entries with date older than today
  void adjustSchedule([DateTime? date]) {
    date ??= DateTime.now();
    final dayOnly = date.dayOnly;
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
  }

  void _decode(List<int> bytes) {
    final reader = Payload.read(gzip.decode(bytes));
    final agendaLength = reader.get(uint16);

    for (int i = 0; i < agendaLength; ++i) {
      final key = DateTime.fromMillisecondsSinceEpoch(
          reader.get(uint32) * Duration.millisecondsPerSecond);
      final itemCount = reader.get(uint32);
      final items = <LexiconItem>{};

      for (int j = 0; j < itemCount; ++j) {
        items.add(
          LexiconItem(
            reader.get(uint64),
            isKanji: reader.get(boolean),
          ),
        );
      }
      _agenda[key] = items;
    }
  }

  List<int> encode() {
    final writer = Payload.write();

    writer.set(uint16, _agenda.length);

    _agenda.forEach((key, value) {
      writer.set(uint32, key.secondsSinceEpoch);
      writer.set(uint32, value.length);

      for (var e in value) {
        writer.set(uint64, e.id);
        writer.set(boolean, e.isKanji);
      }
    });

    return gzip.encode(binarize(writer));
  }
}
