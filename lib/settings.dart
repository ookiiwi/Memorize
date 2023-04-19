import 'dart:convert';
import 'dart:io';

import 'package:memorize/app_constants.dart';

class AppSettings {
  static final path = '$applicationDocumentDirectory/settings/app';

  AppSettings({this.language = 'eng', this.quizStepMinutes = 60});
  AppSettings.fromJson(Map<String, dynamic> json)
      : language = json['lang'],
        quizStepMinutes = json['qsm'];

  factory AppSettings.load() {
    final file = File(path);
    final content = jsonDecode(file.readAsStringSync());

    return AppSettings.fromJson(content);
  }

  String language;
  int quizStepMinutes;

  Map<String, dynamic> toJson() => {
        'lang': language,
        'qsm': quizStepMinutes,
      };

  void save() {
    final file = File(path);

    if (!file.existsSync()) file.createSync(recursive: true);

    file.writeAsStringSync(jsonEncode(this));
  }
}
