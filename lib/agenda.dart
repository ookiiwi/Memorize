import 'package:memorize/lexicon.dart';

extension DateTimeDayOnly on DateTime {
  DateTime get dayOnly => DateTime(year, month, day);
}

class Agenda {
  Agenda({Map<DateTime, Set<LexiconItem>>? agenda}) : _agenda = agenda ?? {};

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

  DateTime schedule(LexiconItem item) {
    final date = DateTime.now().add(Duration(days: item.sm2.interval));
    final dayOnly = date.dayOnly;

    for (var e in _agenda.keys) {
      if (_agenda[e]!.remove(item)) {
        break;
      }
    }

    _agenda[dayOnly] ??= {};
    _agenda[dayOnly]!.add(item);

    return dayOnly;
  }

  DateTime? unschedule(LexiconItem item, [DateTime? date]) {
    if (date != null) {
      final dayOnly = date.dayOnly;
      final isRemoved = _agenda[dayOnly]?.remove(item);

      if (isRemoved == true) {
        return dayOnly;
      }
    }

    for (var e in _agenda.entries) {
      if (e.value.remove(item)) return e.key;
    }

    return null;
  }

  /// Moves entries with date older than today
  void adjustSchedule([DateTime? date]) {
    date ??= DateTime.now();
    final dayOnly = date.dayOnly;
    final pastDates = _agenda.keys
        .where((e) => e.millisecondsSinceEpoch < dayOnly.millisecondsSinceEpoch)
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
}
