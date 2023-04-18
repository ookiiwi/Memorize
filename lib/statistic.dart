import 'dart:convert';
import 'dart:io';

import 'package:memorize/app_constants.dart';

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

  GlobalStats({
    this.overallScore = 0,
    this.scoreCount = 0,
  })  : _newEntriesWeek = 0,
        _newEntriesMonth = 0,
        _newEntriesYear = 0,
        _newEntriesAllTime = 0,
        _time = DateTime.now();

  GlobalStats.fromJson(Map<String, dynamic> json)
      : _newEntriesWeek = json['neWeek'],
        _newEntriesMonth = json['neMonth'],
        _newEntriesYear = json['neYear'],
        _newEntriesAllTime = json['neAllTime'],
        overallScore = json['overallScore'],
        scoreCount = json['scoreCount'],
        _time = DateTime.fromMillisecondsSinceEpoch(json['time']) {
    adjustCounts();
  }

  factory GlobalStats.load() {
    final file = File(filepath);
    final content = jsonDecode(file.readAsStringSync());

    return GlobalStats.fromJson(content);
    //return GlobalStats();
  }

  int _newEntriesWeek;
  int _newEntriesMonth;
  int _newEntriesYear;
  int _newEntriesAllTime;
  double overallScore;
  int scoreCount;
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

  double get normalizedScore =>
      scoreCount == 0 ? 0 : overallScore / (scoreCount * 100);

  double get percentage => scoreCount == 0 ? 0 : overallScore / scoreCount;

  Map<String, dynamic> toJson() => {
        'neWeek': newEntriesWeek,
        'neMonth': newEntriesMonth,
        'neYear': newEntriesYear,
        'neAllTime': newEntriesAllTime,
        'overallScore': overallScore,
        'scoreCount': scoreCount,
        'time': DateTime.now().millisecondsSinceEpoch,
      };

  void save() {
    final file = File(filepath);

    if (!file.existsSync()) file.createSync(recursive: true);

    file.writeAsStringSync(jsonEncode(this));
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
