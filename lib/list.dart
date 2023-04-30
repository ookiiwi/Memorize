import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:memorize/app_constants.dart';
import 'package:memorize/widgets/entry/parser.dart';
import 'package:path/path.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:diffutil_dart/diffutil.dart' as diffutil;
import 'package:quiver/collection.dart' as quiver;

enum MemoListEvent { rename, newScore }

typedef MemoListEventListener = void
    Function(MemoList list, MemoListEvent event, [dynamic data]);

class ListEntry extends Equatable {
  const ListEntry(this.id, {this.subTarget, this.data, this.isWrong = false});
  ListEntry.fromJson(Map<String, dynamic> json, {this.data})
      : id = json['id'],
        subTarget = json['s'],
        isWrong = json['w'] ?? false;

  ListEntry copyWith({
    int? id,
    String? source,
    String? subTarget,
    ParsedEntry? data,
    bool? isWrong,
  }) {
    return ListEntry(
      id ?? this.id,
      subTarget: subTarget ?? this.subTarget,
      data: data ?? this.data,
      isWrong: isWrong ?? this.isWrong,
    );
  }

  final int id;
  final String? subTarget;
  final ParsedEntry? data;
  final bool isWrong;

  String get target =>
      'jpn-${appSettings.language}${subTarget != null ? "-$subTarget" : ""}';

  Map<String, dynamic> toJson() => {
        'id': id,
        if (subTarget != null) 's': subTarget,
        if (isWrong) 'w': isWrong
      };

  @override
  List<Object?> get props => [id, subTarget];
}

class MemoList {
  static final recordIDre = RegExp(r'_(\w|\d){15}$');
  static final dummyRecordID = List.generate(15, (_) => '0').join();

  MemoList(
    this.filename,
  )   : entries = [],
        level = 1,
        _score = 0,
        lastQuizEntryCount = 0 {
    // Force set recordID
    recordID ??= null;
  }

  MemoList.fromJson(this.filename, Map<String, dynamic> json)
      : entries = List.from(json['entries'].map((e) => ListEntry.fromJson(e))),
        level = json['level'] ?? 1,
        _score = globalStats.progressWatcher[filename]?.score ?? 0,
        lastQuizEntryCount = json['lqec'] ?? 0 {
    if (level < 1) level = 1;

    recordID ??= null;
  }

  factory MemoList.open(String filename) {
    final file = File(filename);

    assert(file.existsSync());

    return MemoList.fromJson(
      filename,
      jsonDecode(file.readAsStringSync()),
    );
  }

  List<ListEntry> entries;
  String filename;
  int level;
  double _score;
  int lastQuizEntryCount;

  double get score => _score;
  set score(double value) {
    _score = value;
    notifyListeners(MemoListEvent.newScore);
  }

  static final List<MemoListEventListener> _listeners = [];
  static void addListener(MemoListEventListener listener) =>
      _listeners.add(listener);
  static void removeListener(MemoListEventListener listener) =>
      _listeners.remove(listener);

  void notifyListeners(MemoListEvent event, [dynamic data]) {
    for (var e in _listeners) {
      e(this, event, data);
    }
  }

  String get name => extractName(filename);
  String? get recordID {
    final id =
        recordIDre.firstMatch(basename(filename))?[0]?.replaceFirst('_', '');

    return id != dummyRecordID ? id : null;
  }

  set recordID(String? id) {
    File file = File(filename);
    id ??= dummyRecordID;

    String oldFilename = filename;
    String newFilename =
        '${filename.replaceFirst(RegExp('_${recordID ?? dummyRecordID}\$'), '')}_$id';

    file = file.existsSync() ? file.renameSync(newFilename) : File(newFilename);
    filename = file.absolute.path;

    assert(recordID == id || recordID == null && id == dummyRecordID);

    notifyListeners(MemoListEvent.rename, oldFilename);
  }

  static String extractName(String filename) =>
      basename(filename).replaceFirst(recordIDre, '');

  Map<String, dynamic> toJson() => {
        'entries': entries.map((e) => e.toJson()).toList(),
        'level': level,
        'lqec': lastQuizEntryCount
      };

  void save() => File(filename).writeAsStringSync(jsonEncode(toJson()));

  void rename(String newName) {
    final file = File(filename);

    if (!file.existsSync()) return;

    String oldFilename = filename;
    filename =
        join(dirname(filename), '${newName}_${recordID ?? dummyRecordID}');

    file.renameSync(filename);
    notifyListeners(MemoListEvent.rename, oldFilename);
  }

  Future<void> setReminder(int id) async {
    final minutes = 2 * level * appSettings.quizStepMinutes;
    final date = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      "It's quiz time",
      'Start a quiz on $name',
      date,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'my channel id',
          'my channel name',
        ),
      ),
      payload:
          jsonEncode([filename, 'scheduled at ${date.toLocal()} ($minutes)']),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
    );
  }

  Iterable<ListEntry> get wrongEntries => entries.where((e) => e.isWrong);
}

typedef VersionListReviver<T> = T Function(dynamic);

class VersionList<T extends dynamic> extends quiver.DelegatingList<T> {
  VersionList()
      : _list = <T>[],
        _version = null,
        versions = {},
        _headless = false;

  VersionList.from(List<T> list, {int? version, Set<int>? versions})
      : _list = list,
        _version = version,
        versions = versions ?? {},
        _headless = false;

  VersionList.fromJson(Map<String, dynamic> json,
      {VersionListReviver<T>? reviver, int? version, bool forceHead = false})
      : _version = version ?? json['version'],
        versions = {},
        _headless = !json.containsKey('head'),
        _list = <T>[] {
    if (forceHead && version == null) {
      _version = null;
    }

    final versions = Map<String, dynamic>.from(json['versions']);
    final head = _version == null ? json['head'] : null;

    T _reviver(value) {
      if (reviver != null) return reviver(value);
      return value;
    }

    if (versions.isNotEmpty) {
      this.versions.addAll(Set.of(versions.keys.map((e) => int.parse(e))));
    }

    if (_version != null) {
      versions.removeWhere((key, value) => int.parse(key) > _version!);
    }

    versions.forEach((key, value) {
      if (value is List) {
        assert(_list.isEmpty);
        _list.addAll(value.map((e) => _reviver(e)));
      } else {
        _patch(_list, value, reviver: _reviver);
      }
    });

    if (head is List) {
      assert(_list.isEmpty);
      _list.addAll(head.map((e) => _reviver(e)));
    } else if (head != null) {
      _patch(_list, head, reviver: _reviver);
    }
  }

  int? _version;
  int? get version => _version;
  final Set<int> versions;
  bool _headless;
  bool get headless => _headless;
  final List<T> _list;

  @override
  List<T> get delegate => _list;

  Map<String, dynamic> toJson(
      {int? version,
      Map<String, dynamic>? versions,
      VersionListReviver<T>? reviver}) {
    Map<String, dynamic> ret = {
      'version': version,
      'versions': versions?['versions'] ?? {}
    };

    if (version != null) {
      if (this.versions.contains(version) ||
          (this.versions.isNotEmpty && version < this.versions.last)) {
        throw Exception(
            "Revisions are immutable: $version in ${this.versions}");
      }

      this.versions.add(version);
    }

    dynamic data = [];
    _version = version;

    final prevVersion = this.versions.lastOrNull;
    VersionList<T>? oldList = versions != null && prevVersion != null
        ? VersionList.fromJson(versions, reviver: reviver, version: prevVersion)
        : null;

    if (oldList == null) {
      data = _list.map((e) {
        try {
          return e.toJson();
        } on NoSuchMethodError {
          return e;
        }
      }).toList();
    } else {
      // {'+': [...]}
      // {'-': [...]}
      // [...]

      data = _diff(oldList._list, _list);

      if (data.isEmpty) {
        data = _list.map((e) {
          try {
            return e.toJson();
          } on NoSuchMethodError {
            return e;
          }
        }).toList();
      }
    }

    assert(data is List && this.versions.length <= 1 || data is Map);

    if (version == null) {
      ret['head'] = data;
      _headless = false;
    } else {
      _headless = true;
      ret.remove('head');
      ret['versions']['$version'] = data;
      this.versions.add(version);
    }

    return ret;
  }

  Map<String, List> _diff(List<T> oldList, List<T> newList) {
    final add = [];
    final rm = [];
    final diff =
        diffutil.calculateListDiff(oldList, newList).getUpdatesWithData();

    for (var e in diff) {
      if (e is diffutil.DataInsert) {
        var data = (e as diffutil.DataInsert).data;

        try {
          data = data.toJson();
        } on NoSuchMethodError {}

        add.add(data);
      } else if (e is diffutil.DataRemove) {
        var data = (e as diffutil.DataRemove).data;

        try {
          data = data.toJson();
        } on NoSuchMethodError {}

        rm.add(data);
      }
    }

    return {
      if (rm.isNotEmpty) '-': rm,
      if (add.isNotEmpty) '+': add,
    };
  }

  void _patch(List<T> list, Map<String, dynamic> patch,
      {required T Function(dynamic) reviver}) {
    patch.forEach((key, value) {
      for (var e in value) {
        if (key == '-') {
          list.remove(reviver(e));
        } else if (key == '+') {
          list.add(reviver(e));
        }
      }
    });
  }
}
