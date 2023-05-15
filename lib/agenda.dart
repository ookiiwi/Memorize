import 'dart:io';

import 'package:binarize/binarize.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/memo_list.dart';
import 'package:memorize/sm.dart';
import 'package:timezone/timezone.dart' as tz;

extension DateTimeDayOnly on DateTime {
  DateTime get dayOnly => DateTime(year, month, day);
  int get secondsSinceEpoch =>
      millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
}

class Agenda {
  static const maxRemindersPerDay = 4;

  Agenda({Map<DateTime, Map<String, Set<MemoListItem>>>? agenda})
      : _agenda = agenda ?? {};
  Agenda.decode(List<int> bytes) : _agenda = {} {
    _decode(bytes);
  }

  /// Stores items to play at specific day
  final Map<DateTime, Map<String, Set<MemoListItem>>> _agenda;
  // TODO: store list count
  final _smWordData = <int, SM2>{};
  final _smKanjiData = <int, SM2>{};

  Map<String, Set<MemoListItem>> operator [](DateTime date) {
    final dayOnly = date.dayOnly;

    return Map.of(_agenda[dayOnly] ?? {});
  }

  @override
  String toString() => _agenda.toString();

  void forEach(
      void Function(DateTime date, Map<String, Set<MemoListItem>> items)
          action) {
    _agenda.forEach(action);
  }

  void clear() {
    _agenda.clear();
    _smKanjiData.clear();
    _smWordData.clear();
    flutterLocalNotificationsPlugin.cancelAll();
  }

  DateTime? getTime(MapEntry<String, MemoListItem> item) {
    for (var e in _agenda.entries) {
      if (e.value[item.key]?.contains(item.value) == true) return e.key;
    }

    return null;
  }

  SM2? getSMData(MemoListItem item) {
    return item.isKanji ? _smKanjiData[item.id] : _smWordData[item.id];
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

  DateTime schedule(MapEntry<String, MemoListItem> item, int quality) {
    final smData = item.value.isKanji ? _smKanjiData : _smWordData;
    final sm2 = (smData[item.value] ?? const SM2()).compute(quality);
    final date = DateTime.now().add(Duration(days: sm2.interval));
    final dayOnly = date.dayOnly;

    smData[item.value.id] = sm2;

    for (var e in _agenda.keys) {
      if (_agenda[e]![item.key]?.remove(item) == true) {
        break;
      }
    }

    _setReminders(date);

    _agenda[dayOnly] ??= {};
    _agenda[dayOnly]![item.key] ??= {};
    _agenda[dayOnly]![item.key]!.add(item.value);

    return dayOnly;
  }

  DateTime? unschedule(int entryId, [DateTime? date]) {
    DateTime? scheduledDate;

    if (date != null) {
      final dayOnly = date.dayOnly;

      for (var e in _agenda[dayOnly]?.entries.toList() ?? []) {
        if (e.value.remove(entryId >> 1) == true) {
          scheduledDate = dayOnly;

          break;
        }
      }
    }

    if (scheduledDate == null) {
      for (var e in _agenda.entries) {
        for (var ee in e.value.entries) {
          if (ee.value.remove(entryId >> 1)) {
            scheduledDate = e.key;

            break;
          }
        }

        if (scheduledDate != null) {
          break;
        }
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
      final items = <String, Set<MemoListItem>>{};

      for (int j = 0; j < itemCount; ++j) {
        final key = reader.get(string32);
        final itemCount = reader.get(uint16);

        items[key] ??= {};

        for (int i = 0; i < itemCount; ++i) {
          final data = reader.get(uint64);

          items[key]!.add(MemoListItem(data >> 1, (1 & data) == 1));
        }
      }

      _agenda[key] = items;

      void readSMData(Map<int, SM2> data) {
        final count = reader.get(uint32);

        for (int i = 0; i < count; ++i) {
          final key = reader.get(uint64);
          final sm = SM2(
            repetitions: reader.get(uint16),
            interval: reader.get(uint16),
            easeFactor: reader.get(float64),
          );

          data[key] = sm;
        }
      }

      readSMData(_smKanjiData);
      readSMData(_smWordData);
    }
  }

  List<int> encode() {
    final writer = Payload.write();

    writer.set(uint16, _agenda.length);

    _agenda.forEach((key, value) {
      writer.set(uint32, key.secondsSinceEpoch);
      writer.set(uint32, value.length);

      value.forEach((key, value) {
        writer.set(string32, key);
        writer.set(uint16, value.length);

        for (var e in value) {
          writer.set(uint64, (e.id << 1) | (e.isKanji ? 1 : 0));
        }
      });
    });

    void writeSMData(Map<int, SM2> data) {
      writer.set(uint32, data.length);

      data.forEach((key, value) {
        writer.set(uint64, key);
        writer.set(uint16, value.repetitions);
        writer.set(uint16, value.interval);
        writer.set(float64, value.easeFactor);
      });
    }

    writeSMData(_smKanjiData);
    writeSMData(_smWordData);

    return gzip.encode(binarize(writer));
  }
}
