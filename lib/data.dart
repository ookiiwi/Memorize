import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:memorize/addon.dart';
import 'package:memorize/auth.dart';
import 'package:memorize/file_explorer.dart';
import 'package:memorize/reminder.dart';

final FileExplorer fe = kIsWeb ? CloudFileExplorer() : MobileFileExplorer();

int daysBetween(DateTime from, DateTime to) {
  from = DateTime(from.year, from.month, from.day);
  to = DateTime(to.year, to.month, to.day);
  return (to.difference(from).inHours / 24).round();
}

typedef AListEntry = Map<String, dynamic>;

class AList {
  AList(this.name, {String? serverId})
      : schemasMapping = {},
        _serverId = serverId,
        _entries = [],
        _tags = {},
        _stats = AListStats();

  AList.from(AList list)
      : name = list.name,
        schemasMapping = Map.from(list.schemasMapping),
        _serverId = list.serverId,
        status = list.status,
        _entries = List.from(list._entries),
        _tags = Set.from(list._tags),
        _stats = AListStats();

  AList.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        schemasMapping = Map.from(json['schemasMapping']),
        _serverId = json['serverId'],
        status = json['status'],
        _entries = List.from(json['entries']),
        _tags = Set.from(json['tags']),
        _stats = AListStats.fromJson(json["listStats"]);

  Map<String, dynamic> toJson() => {
        'name': name,
        'schemasMapping': schemasMapping,
        'serverId': _serverId,
        "entries": _entries,
        "status": status,
        "tags": _tags.toList(),
        "listStats": _stats.toJson()
      };

  String? _serverId;
  String? get serverId => _serverId;
  set serverId(id) {
    assert(_serverId == null);
    _serverId = id;
  }

  String name = '';
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

    Auth.init();
    SchemaAddon.init();
    if (!kIsWeb) await ReminderNotification.init();

    _isDataLoaded = true;
  }
}
