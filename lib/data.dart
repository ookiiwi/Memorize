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

class AListEntry {
  const AListEntry(this.langCode, this.entryId, this.entry, this.word);
  AListEntry.fromJson(Map<String, dynamic> json)
      : langCode = json['langCode'],
        entryId = json['entryId'],
        entry = json['entry'],
        word = json['word'];

  Map<String, dynamic> toJson() =>
      {'langCode': langCode, 'entryId': entryId, 'entry': entry, 'word': word};

  final String langCode;
  final String entryId;
  final dynamic entry;
  final String word;
}

class AList extends fs.MemoFile {
  AList(super.name)
      : addonId = null,
        _entries = [],
        _tags = {};

  AList.from(AList list)
      : addonId = list.addonId,
        _entries = List.from(list._entries),
        _tags = Set.from(list._tags),
        super.from(list);

  AList.fromJson(Map<String, dynamic> json)
      : addonId = json['meta']['addonId'],
        _entries = List.from(
            json['file']['entries'].map((e) => AListEntry.fromJson(e))),
        _tags = Set.from(json['file']['tags']),
        super.fromJson(json);

  @override
  Map<String, dynamic> metaToJson() => {'addonId': addonId};

  @override
  Map<String, dynamic> toJsonEncodable() => {
        "entries": _entries,
        "tags": _tags.toList(),
      };

  final List<AListEntry> _entries;
  final Set<String> _tags;
  String langCode = 'jpn-eng';
  String? addonId;

  List<AListEntry> get entries => List.unmodifiable(_entries);

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;
  bool get isNotEmpty => _entries.isNotEmpty;

  void addEntry(AListEntry entry) {
    _entries.add(entry);
  }

  Future<String> buildEntry(int index) async {
    assert(addonId != null);
    final addon = await Addon.fromId(addonId!);
    return entryBuilder(addon.html, entries[index].entry);
  }
}

enum SortType { rct, asc, dsc }

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
