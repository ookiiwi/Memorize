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

class ItemQualityStatistics {
  ItemQualityStatistics(this.label,
      {Map<String, int>? stat, this.itemCount = 0})
      : stat = stat ?? {};

  final String label;
  final Map<String, int> stat;
  int itemCount;

  void clear() {
    stat.clear();
    itemCount = 0;
  }

  int? operator [](int quality) {
    return stat['$quality'];
  }

  void update(int? prevQuality, int quality) {
    if (prevQuality == quality) return;

    final prevQ = '$prevQuality';

    if (prevQuality == null) ++itemCount;

    if (prevQuality != null && stat.containsKey(prevQ) && stat[prevQ] != 0) {
      stat[prevQ] = stat[prevQ]! - 1;
    }

    stat['$quality'] = (stat[quality] ?? 0) + 1;
  }

  static ItemQualityStatistics? load(String label) {
    final str = prefs.getString(label);

    if (str != null) {
      final data = List.from(jsonDecode(str));
      print('load: ${data[0]} ${data[1]}');

      return ItemQualityStatistics(label,
          stat: Map.from(data[0]), itemCount: data[1]);
    }

    return null;
  }

  Future<void> save() async {
    print('save: $stat $itemCount');
    await prefs.setString(label, jsonEncode([stat, itemCount]));
  }

  /// 0.0 - 1.0
  double? normalized(int key) => stat.containsKey('$key') && itemCount != 0
      ? stat['$key']! / itemCount
      : null;
}

class JlptStatistics extends ItemQualityStatistics {
  JlptStatistics(super.label, {super.stat, super.itemCount});

  static JlptStatistics? load(String label) {
    final stat = ItemQualityStatistics.load(label);

    return stat != null
        ? JlptStatistics(label, stat: stat.stat, itemCount: stat.itemCount)
        : null;
  }

  @override
  void update(int? prevQuality, int quality, [int level = 1]) {
    if (prevQuality == quality) return;

    int value = 0;
    if (prevQuality == null) ++itemCount;

    // (p? || p < 4) && q >= 4 == +1
    // p >= 4 && q < 4 == -1

    if ((prevQuality == null || prevQuality < 4) && quality >= 4) {
      value = 1;
    } else if (prevQuality != null && prevQuality >= 4 && quality < 4) {
      value = -1;
    }

    print('update jlpt: $prevQuality $quality : $value : $itemCount');

    stat['$level'] =
        ((stat['$level'] ?? 0) + value).clamp(0, double.infinity).toInt();
  }
}
