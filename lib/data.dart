import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:memorize/reminder.dart';
import 'package:nanoid/nanoid.dart';

int daysBetween(DateTime from, DateTime to) {
  from = DateTime(from.year, from.month, from.day);
  to = DateTime(to.year, to.month, to.day);
  return (to.difference(from).inHours / 24).round();
}

class AList {
  AList(this.name)
      : _entries = [],
        _tags = {},
        _stats = AListStats() {
    genId();
    _initReminder();
  }

  AList.from(AList list)
      : name = list.name,
        _dirPath = list._dirPath,
        _entries = List.from(list._entries),
        _tags = Set.from(list._tags),
        _stats = AListStats() {
    genId();
    _initReminder();
  }

  AList._(List<Map> entries, Set<String> tags, String path, AListStats stats)
      : _entries = List.from(entries),
        _tags = Set.from(tags),
        _stats = stats {
    _readPath(path);

    _initReminder();
  }

  factory AList.fromJson(String id, String name, String rawData, String path) {
    Map data = jsonDecode(rawData);
    AList list = AList._(List.from(data['entries']), Set.from(data['tags']),
        path, AListStats.fromJson(data["listStats"]));

    //ReminderNotification.add(list._reminder);
    return list;
  }

  Map<String, dynamic> toJson() => {
        "entries": _entries,
        "tags": _tags.toList(),
        "listStats": _stats.toJson()
      };

  String _id = '';
  String name = '';
  final List<Map> _entries;
  final Set<String> _tags;
  final AListStats _stats;
  String _dirPath = '';
  String addon = "JpnAddon";
  late final Reminder _reminder;

  AListStats get stats => _stats;

  String get uniqueName => name; //"$_id?$name";

  String get path => "$_dirPath$uniqueName";
  set path(String p) => _readPath(p);

  List<Map> get entries => _entries;

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;
  bool get isNotEmpty => _entries.isNotEmpty;

  void _initReminder() {
    _reminder = Reminder(DateTime.now(), path);
  }

  void _readPath(String path) {
    String rawName = stripPath(path).last;
    var tmp = _splitName(rawName);
    _id = tmp.key;
    name = tmp.value;
    _dirPath = path.substring(0, path.length - rawName.length);
  }

  static MapEntry<String, String> _splitName(String name) {
    String id = name.replaceAll(RegExp(r"\?.*"), '');
    String rname = name.replaceFirst(id + '?', '');
    return MapEntry(id, rname);
  }

  static String extractName(String name) => _splitName(name).value;

  void genId() {
    _id = nanoid(10);
  }

  void newStats(QuizStats stats) => _stats.add(stats);
  void addStat(String word, bool isGood) {
    Map entry = _entries.firstWhere(
      (e) => e["word"] == word,
      orElse: () => {},
    );

    assert(entry.isNotEmpty);

    if (!entry.containsKey("freq")) entry["freq"] = _reminder.initFreq;

    entry["freq"] += isGood ? -_reminder.freqStep : _reminder.freqStep;

    _stats.lastScore += isGood ? 1 : 0;
  }
}

class QuizStats {
  QuizStats(this.time, this.mode, {this.score = 0});
  factory QuizStats.fromJson(Map<String, dynamic> data) {
    return QuizStats(
        DateTime.fromMillisecondsSinceEpoch(int.parse(data['data'][1])),
        data['data'][0],
        score: int.parse(data['data'][2]));
  }

  final DateTime time;
  final String mode;
  int score;

  Map<String, dynamic> toJson() => {
        'data': [mode, time.millisecondsSinceEpoch.toString(), score.toString()]
      };
}

class AListStats {
  AListStats();

  factory AListStats.fromJson(Map<String, dynamic> data) {
    AListStats stats = AListStats();
    stats._stats.addAll(
        (data['stats'] as List).map((e) => QuizStats.fromJson(e)).toList());
    return stats;
  }

  Map<String, dynamic> toJson() =>
      {"stats": _stats.map((e) => e.toJson()).toList()};

  final List<QuizStats> _stats = [];

  List<QuizStats> get stats => _stats;

  void add(QuizStats stats) => _stats.add(stats);
  int get lastScore => _stats.last.score;
  set lastScore(int n) => _stats.last.score = n.clamp(0, n.abs());
}

List<String> stripPath(String path) {
  return (path.split('/'))..removeWhere((e) => e.isEmpty);
}

enum SortType { rct, asc, dsc }

class AppData {
  static Map<String, Color> colors = {
    "bar": const Color(0xFFF3F3F3),
    "container": const Color(0xFFEBEAEA),
    "hintText": const Color(0xFF464646),
    "buttonSelected": const Color(0xFFB01919),
    "buttonIdle": const Color(0xFFBDBDBD),
    "border": const Color(0xFFBFBFBF)
  };
}

abstract class ATab {
  void reload();
}

class AppBarItem {
  AppBarItem(
      {required this.icon,
      required this.tab,
      bool isMain = false,
      this.onWillPop})
      : tabIcon = isMain ? const Icon(Icons.home) : icon,
        bMain = isMain;

  Icon icon = const Icon(Icons.abc);
  Icon tabIcon;
  final ATab Function() tab;
  final bool bMain;
  final bool Function()? onWillPop;
}

class DataLoader {
  static bool _isDataLoaded = false;

  static load({bool force = false}) async {
    if (_isDataLoaded && !force) return;
    // TODO: check if user logged here

    if (!kIsWeb) await ReminderNotification.init();
    _isDataLoaded = true;
  }
}
