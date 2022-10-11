import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:memorize/addon.dart';
import 'package:memorize/auth.dart';
import 'package:memorize/file_system.dart' as fs;
import 'package:memorize/tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

int daysBetween(DateTime from, DateTime to) {
  from = DateTime(from.year, from.month, from.day);
  to = DateTime(to.year, to.month, to.day);
  return (to.difference(from).inHours / 24).round();
}

typedef AListEntry = Map<String, dynamic>;

class AList extends fs.MemoFile {
  AList(super.name)
      : schemasMapping = {},
        _entries = [],
        _tags = {},
        _stats = AListStats();

  AList.from(AList list)
      : schemasMapping = Map.from(list.schemasMapping),
        status = list.status,
        _entries = List.from(list._entries),
        _tags = Set.from(list._tags),
        _stats = AListStats(),
        super.from(list);

  AList._fromJson(Map<String, dynamic> json, {super.versions})
      : schemasMapping = Map.from(json['schemasMapping']),
        status = json['status'],
        _entries = List.from(json['entries']),
        _tags = Set.from(json['tags']),
        _stats = AListStats.fromJson(json["listStats"]),
        super.fromJson(json);

  factory AList.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('file')) {
      final data = jsonDecode(json['file']);
      data.remove('id');
      json.remove('file');
      json.addAll(data);
    }

    return AList._fromJson(json, versions: Set.from(json['versions'] ?? {}));
  }

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..addAll({
      'schemasMapping': schemasMapping,
      "entries": _entries,
      "status": status,
      "tags": _tags.toList(),
      "listStats": _stats.toJson()
    });

  @override
  get data => jsonEncode(toJson());

  String status = 'private';
  final Map<String, String> schemasMapping;
  final List<AListEntry> _entries;
  final Set<String> _tags;
  final AListStats _stats;

  AListStats get stats => _stats;

  String get uniqueName => name;

  List<AListEntry> get entries => List.unmodifiable(_entries);

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;
  bool get isNotEmpty => _entries.isNotEmpty;

  void addEntry(AListEntry entry) {
    _entries.add(entry);

    schemasMapping.putIfAbsent(entry['schema'], () => 'Language');
  }

  /// NOT IMPLEMENTED. Use fs instead
  @override
  write(String path, [fs.MemoFile? file]) {
    // TODO: implement write
    throw UnimplementedError();
  }

  /// NOT IMPLEMENTED. Use fs instead
  @override
  read(String path) {
    // TODO: implement read
    throw UnimplementedError();
  }

  /// NOT IMPLEMENTED. Use fs instead
  @override
  rm(String path) {
    // TODO: implement rm
    throw UnimplementedError();
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

    final pref = await SharedPreferences.getInstance();
    final isFirstRun = pref.getBool('isFirstRun');

    if (isFirstRun == null || !isFirstRun) {
      await fs.initFirstRun();
      ListExplorer.init();
      print('firstrun');
      pref.setBool('isFirstRun', false);
    } else {
      print('not firstrun');
    }

    await Auth.init();
    await fs.init();
    SchemaAddon.init();
    //if (!kIsWeb) await ReminderNotification.init();

    _isDataLoaded = true;
  }
}
