import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AList {
  AList(this.name)
      : _entries = [],
        _tags = {},
        _stats = AListStats();

  AList.from(AList list)
      : name = list.name,
        path = list.path,
        _entries = List.from(list._entries),
        _tags = Set.from(list._tags),
        _stats = AListStats();

  AList._(this.name, List<Map> entries, Set<String> tags, this.path)
      : _entries = List.from(entries),
        _tags = Set.from(tags),
        _stats = AListStats();

  factory AList.fromJson(String name, String rawData, String path) {
    Map<String, dynamic> data = jsonDecode(rawData);
    AList list = AList._(name, data['entries'], data['tags'], path);

    return list;
  }

  Map<String, dynamic> toJson() =>
      {"entries": _entries, "tags": _tags, "stats": _stats.toJson()};

  String name;
  final List<Map> _entries;
  final Set<String> _tags;
  final AListStats _stats;
  String path = '';

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;
  bool get isNotEmpty => _entries.isNotEmpty;
}

class AListStats {
  AListStats();

  Map<String, dynamic> toJson() => {"": ""};
}

//deals with mem
class FileExplorer {
  static final List<Directory> _loadedDir = [];
  static final Map<String, int> _loadedLists = {};
  static final List<AList> _loadedListsQueue = [];
  static String _deepestPathOnCurrentBranch = '/';
  static int _currDirIndex = 0;
  static const int _loadedDirOffsetFromCurrent = 1;
  static const _loadedListsQueueSize = 10;
  static bool _isInit = false;
  static late String _rootPath;

  static init() async {
    if (_isInit) return;
    _isInit = true;
    var dir = await getApplicationDocumentsDirectory();
    _rootPath = '${dir.path}/fe/root/';
    createDirectory(_rootPath, cd: true);
  }

  static String get current => Directory.current.path;

  static List<String> stripPath(String path) {
    return (path.split('/'))..removeWhere((e) => e.isEmpty);
  }

  static bool _isDirLoaded(String path) {
    return _loadedDir
        .firstWhere((e) => e.path == path, orElse: () => Directory(''))
        .path
        .isNotEmpty;
  }

  static void _updateDeepestPath(String newPath) {
    if (!_deepestPathOnCurrentBranch.contains(newPath)) {
      _deepestPathOnCurrentBranch = newPath;
    }
  }

  static void _updateCurrentDirIndex(String path) {
    assert(_deepestPathOnCurrentBranch.length >= path.length);
    _currDirIndex = stripPath(path).length;
  }

  static void _adjustLoadedDir() {
    List dirs = stripPath(_deepestPathOnCurrentBranch);
    List dirsToLoad = [];

    // get lists to be loaded
    for (int i = _currDirIndex - _loadedDirOffsetFromCurrent;
        i < _currDirIndex + _loadedDirOffsetFromCurrent;
        ++i) {
      dirsToLoad.add('/${dirs.sublist(0, i).join('/')}');
    }

    // load lists if not already loaded
    for (var e in _loadedDir) {
      if (!dirsToLoad.contains(e.path) && dirsToLoad.isNotEmpty) {
        e = Directory(dirsToLoad.removeLast());
      }
    }
  }

  static bool cd(String path) {
    return _cdDir(Directory(path));
  }

  static bool _cdDir(Directory dir) {
    String path = dir.path;

    if (!dir.existsSync() ||
        (Directory.current.path.endsWith('/root') &&
            !path.contains(Directory.current.path))) {
      return false;
    }
    if (!_isDirLoaded(path)) _loadedDir.add(dir);

    //may need to use absolute path
    Directory.current = path;
    _updateDeepestPath(path);
    _updateCurrentDirIndex(path);
    _adjustLoadedDir();

    return true;
  }

  static Type? getFileType(String path) {
    dynamic ret;
    if (Directory(path).existsSync()) {
      ret = Directory;
    } else if (File(path).existsSync()) {
      ret = File;
    }

    return ret;
  }

  static List<String> listCurrentDir({SortType sortType = SortType.rct}) {
    return listDir(Directory.current.path, sortType: sortType);
  }

  static List<String> listDir(String path, {SortType sortType = SortType.rct}) {
    assert(_isInit);

    List<String> ret = [];
    late Directory dir;

    !_isDirLoaded(path)
        ? dir = Directory(path)
        : dir = _loadedDir.firstWhere((e) => e.path == path);

    if (dir.existsSync()) {
      try {
        ret = dir.listSync().map((e) {
          return e.path;
        }).toList();

        switch (sortType) {
          case SortType.asc:
            ret.sort((a, b) => a.compareTo(b));
            break;
          case SortType.dsc:
            ret.sort((a, b) => b.compareTo(a));
            break;
          case SortType.rct:
            //TODO: sort
            break;
        }
      } on FileSystemException catch (e) {
        print(e.message);
        print(Directory.current);
      }
    }

    return ret;
  }

  static void _loadList(AList list) {
    if (_loadedLists.length >= _loadedListsQueueSize &&
        _loadedLists.isNotEmpty) {
      _unloadLists();
    }

    _loadedListsQueue.add(list);
  }

  static void _unloadLists() {
    _loadedListsQueue.removeAt(0);
  }

  //load a list
  static AList? getList(String path) {
    int i = _loadedListsQueue.indexWhere((e) => e.path == path);
    AList? list = i >= 0 ? _loadedListsQueue[i] : null;

    if (list == null) {
      var tmp = File(path);

      if (tmp.existsSync()) {
        list = AList.fromJson(
            stripPath(tmp.path).last, tmp.readAsStringSync(), path);
        _loadList(list);
      }
    }

    return list;
  }

  void writeList(String path) {
    if (_loadedLists[path] == null) return;

    File file = File(path);
    AList list = _loadedListsQueue[_loadedLists[path]!];
    file.writeAsStringSync(jsonEncode(list.toJson()));
  }

  static String createList(AList list, {String dirPath = ''}) {
    File file = File('$dirPath${list.name}');
    file.createSync();
    list.path = file.absolute.path;

    return file.path;
  }

  static void createDirectory(String path, {bool cd = false}) {
    Directory dir = Directory(path);
    dir.createSync(recursive: true);
    if (cd) _cdDir(dir);
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

class ATab {
  ATab(
      {required this.icon,
      required Widget child,
      bool isMain = false,
      this.onWillPop})
      : tabIcon = isMain ? const Icon(Icons.home) : icon,
        tab = child,
        bMain = isMain;

  final Icon icon;
  Icon tabIcon;
  Widget tab;
  bool bMain;
  bool Function()? onWillPop;
}

class DataLoader {
  static bool _isDataLoaded = false;

  static load({bool force = false}) async {
    if (_isDataLoaded && !force) return;
    await FileExplorer.init();
    _isDataLoaded = true;
    //await Future.delayed(const Duration(seconds: 2));
  }
}
