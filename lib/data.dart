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
        _tags = {};

  AList.from(AList list)
      : schemasMapping = Map.from(list.schemasMapping),
        _entries = List.from(list._entries),
        _tags = Set.from(list._tags),
        super.from(list);

  AList.fromJson(Map<String, dynamic> json)
      : schemasMapping = Map.from(json['file']['schemasMapping']),
        _entries = List.from(json['file']['entries']),
        _tags = Set.from(json['file']['tags']),
        super.fromJson(json);

  @override
  Map<String, dynamic> toJsonEncodable() => {
        'schemasMapping': schemasMapping,
        "entries": _entries,
        "tags": _tags.toList(),
      };

  final Map<String, String> schemasMapping;
  final List<AListEntry> _entries;
  final Set<String> _tags;

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
    print('isFirstRun? $isFirstRun');

    await Auth.init();
    await fs.init(isFirstRun == null || isFirstRun);
    SchemaAddon.init();
    //if (!kIsWeb) await ReminderNotification.init();

    if (isFirstRun == null || isFirstRun) {
      ListExplorer.init();
      print('firstrun');
      pref.setBool('isFirstRun', false);
    } else {
      print('not firstrun');
    }

    _isDataLoaded = true;
  }
}
