import 'dart:convert';
import 'dart:io';

import 'package:memorize/app_constants.dart';

class GlobalStats {
  static final filepath = '$applicationDocumentDirectory/stats/global';

  GlobalStats({
    this.newEntriesWeek = 0,
    this.newEntriesMonth = 0,
    this.newEntriesYear = 0,
    this.newEntriesAllTime = 0,
    this.overallScore = 0,
    this.scoreCount = 0,
  });

  GlobalStats.fromJson(Map<String, dynamic> json)
      : newEntriesWeek = json['neWeek'],
        newEntriesMonth = json['neMonth'],
        newEntriesYear = json['neYear'],
        newEntriesAllTime = json['neAllTime'],
        overallScore = json['overallScore'],
        scoreCount = json['scoreCount'];

  factory GlobalStats.load() {
    final file = File(filepath);
    final content = jsonDecode(file.readAsStringSync());

    return GlobalStats.fromJson(content);
    //return GlobalStats();
  }

  int newEntriesWeek;
  int newEntriesMonth;
  int newEntriesYear;
  int newEntriesAllTime;
  double overallScore;
  int scoreCount;

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
}
