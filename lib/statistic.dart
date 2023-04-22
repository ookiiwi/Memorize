import 'dart:convert';
import 'dart:io';

import 'package:memorize/app_constants.dart';
import 'package:memorize/list.dart';
import 'package:quiver/collection.dart';

extension DateTimeExtension on DateTime {
  int get weekOfMonth {
    var date = this;
    final firstDayOfTheMonth = DateTime(date.year, date.month, 1);
    int sum = firstDayOfTheMonth.weekday - 1 + date.day;
    if (sum % 7 == 0) {
      return sum ~/ 7;
    } else {
      return sum ~/ 7 + 1;
    }
  }
}

class GlobalStats {
  static final filepath = '$applicationDocumentDirectory/stats/global';

  GlobalStats()
      : _newEntriesWeek = 0,
        _newEntriesMonth = 0,
        _newEntriesYear = 0,
        _newEntriesAllTime = 0,
        _time = DateTime.now(),
        progressWatcher = ProgressWatcher.tryLoad();

  GlobalStats.fromJson(Map<String, dynamic> json)
      : _newEntriesWeek = json['neWeek'],
        _newEntriesMonth = json['neMonth'],
        _newEntriesYear = json['neYear'],
        _newEntriesAllTime = json['neAllTime'],
        progressWatcher = ProgressWatcher.tryLoad(),
        _time = DateTime.fromMillisecondsSinceEpoch(json['time']) {
    adjustCounts();
  }

  factory GlobalStats.load() {
    final file = File(filepath);
    final content = jsonDecode(file.readAsStringSync());

    return GlobalStats.fromJson(content);
  }

  int _newEntriesWeek;
  int _newEntriesMonth;
  int _newEntriesYear;
  int _newEntriesAllTime;
  ProgressWatcher progressWatcher;
  DateTime _time;

  void incrementEntries(int value) {
    adjustCounts();

    _newEntriesWeek += value;
    _newEntriesMonth += value;
    _newEntriesYear += value;
    _newEntriesAllTime += value;
  }

  int get newEntriesWeek => _newEntriesWeek;
  int get newEntriesMonth => _newEntriesMonth;
  int get newEntriesYear => _newEntriesYear;
  int get newEntriesAllTime => _newEntriesAllTime;

  double get normalizedScore => progressWatcher.isEmpty
      ? 0
      : progressWatcher.score / (progressWatcher.length * 100);

  double get percentage => progressWatcher.isEmpty
      ? 0
      : progressWatcher.score / progressWatcher.length;

  Map<String, dynamic> toJson() => {
        'neWeek': newEntriesWeek,
        'neMonth': newEntriesMonth,
        'neYear': newEntriesYear,
        'neAllTime': newEntriesAllTime,
        'time': DateTime.now().millisecondsSinceEpoch,
      };

  void save() {
    final file = File(filepath);

    if (!file.existsSync()) file.createSync(recursive: true);

    file.writeAsStringSync(jsonEncode(this));
    progressWatcher._save();
  }

  void adjustCounts() {
    final time = DateTime.now();

    if (time.year != _time.year) {
      _newEntriesWeek = 0;
      _newEntriesMonth = 0;
      _newEntriesYear = 0;
    } else if (time.month != _time.month) {
      _newEntriesWeek = 0;
      _newEntriesMonth = 0;
    } else if (time.weekOfMonth != _time.weekOfMonth) {
      _newEntriesWeek = 0;
    }

    _time = time;
  }
}

class ProgressWatcher extends DelegatingMap<String, ListProgressInfo> {
  static final filepath = '$applicationDocumentDirectory/stats/progress';

  ProgressWatcher() : progressInfo = {} {
    MemoList.addListener(_listener);
  }

  ProgressWatcher.fromJson(Map<String, dynamic> json)
      : progressInfo =
            json.map((e, v) => MapEntry(e, ListProgressInfo.fromJson(v))) {
    MemoList.addListener(_listener);
  }

  factory ProgressWatcher.tryLoad() {
    final file = File(filepath);

    if (file.existsSync()) {
      final content = jsonDecode(file.readAsStringSync());
      return ProgressWatcher.fromJson(content);
    }

    return ProgressWatcher();
  }

  final Map<String, ListProgressInfo> progressInfo;

  @override
  Map<String, ListProgressInfo> get delegate => progressInfo;

  @override
  Iterable<MapEntry<String, ListProgressInfo>> get entries =>
      progressInfo.entries;

  double get score {
    double score = 0;

    progressInfo.forEach((key, value) => score += value.score);

    return score;
  }

  void dispose() {
    MemoList.removeListener(_listener);
  }

  void _listener(MemoList list, MemoListEvent event, [dynamic data]) {
    ListProgressInfo? info;

    switch (event) {
      case MemoListEvent.rename:
        if (progressInfo.containsKey(data)) {
          info = progressInfo.remove(data)!;
          _save();
        }
        break;
      case MemoListEvent.newScore:
        info = ListProgressInfo(list.score);
        break;
    }

    if (info != null) {
      progressInfo[list.filename] = info;
    }
  }

  Map<String, dynamic> toJson() =>
      progressInfo.map((key, value) => MapEntry(key, value.toJson()));

  void _save() {
    final file = File(filepath);

    if (!file.existsSync()) file.createSync(recursive: true);

    file.writeAsStringSync(jsonEncode(this));
  }
}

class ListProgressInfo {
  ListProgressInfo(this.score);
  ListProgressInfo.fromJson(List json) : score = json[0];

  double score;

  List toJson() => [score];
}
