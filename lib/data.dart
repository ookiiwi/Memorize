import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:nanoid/nanoid.dart';

class AList {
  AList(this.name)
      : _entries = [],
        _tags = {},
        _stats = AListStats() {
    genId();
  }

  AList.from(AList list)
      : name = list.name,
        _dirPath = list._dirPath,
        _entries = List.from(list._entries),
        _tags = Set.from(list._tags),
        _stats = AListStats() {
    genId();
  }

  AList._(List<Map> entries, Set<String> tags, String path)
      : _entries = List.from(entries),
        _tags = Set.from(tags),
        _stats = AListStats() {
    _readPath(path);
  }

  factory AList.fromJson(String id, String name, String rawData, String path) {
    print(rawData);
    Map data = jsonDecode(rawData);
    AList list =
        AList._(List.from(data['entries']), Set.from(data['tags']), path);

    return list;
  }

  Map<String, dynamic> toJson() =>
      {"entries": _entries, "tags": _tags.toList()};

  String _id = '';
  String name = '';
  final List<Map> _entries;
  final Set<String> _tags;
  final AListStats _stats;
  String _dirPath = '';

  String get uniqueName => "$_id?$name";

  String get path => "$_dirPath$uniqueName";
  set path(String p) => _readPath(p);

  List<Map> get entries => _entries;

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;
  bool get isNotEmpty => _entries.isNotEmpty;

  void _readPath(String path) {
    String rawName = stripPath(path).last;
    var tmp = _splitName(rawName);
    _id = tmp.key;
    name = tmp.value;
    print('path read: $path');
    _dirPath = path.substring(0, path.length - rawName.length);
    print('dirPath read: $_dirPath');
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
}

class AListStats {
  AListStats();

  Map<String, dynamic> toJson() => {"": ""};
}

List<String> stripPath(String path) {
  return (path.split('/'))..removeWhere((e) => e.isEmpty);
}

//deals with mem
abstract class FileExplorer {
  static final List _loadedDirs = [];
  static final List<AList> _loadedListsQueue = [];
  static String _deepestPathOnCurrentBranch = '/';
  static int _currDirIndex = 0;
  static const int _loadedDirsOffsetFromCurrent = 1;
  static const _loadedListsQueueSize = 10;
  static bool _isInit = false;
  static late FileExplorer _fe;
  static late String _rootPath;
  static Uuid uuid = const Uuid();

  static dynamic init(FileExplorer fe) async {
    if (_isInit) return;
    _isInit = true;
    _fe = fe;
    await fe._initRootPath();
    createDirectory(_rootPath, cd: true);
    print('current: $current');
    print('root: $_rootPath');
  }

  dynamic _initRootPath();

  static MapEntry<String, String> _splitName(String name) {
    String id = name.replaceAll(RegExp(r"\?.+"), '');
    String rname = name.replaceFirst(id + '?', '');
    return MapEntry(id, rname);
  }

  static String get current => _fe._current;
  static String get currentRelative => toRelative(current);
  String _toRelative(String path);
  static String toRelative(String path) => _fe._toRelative(path);

  set _current(String path);
  String get _current;

  bool _exists(String path);
  static bool exists(String path) => _fe._exists(path);

  //static List<String> stripPath(String path) {
  //  return (path.split('/'))..removeWhere((e) => e.isEmpty);
  //}

  bool _isDirLoaded(String path);

  void _unloadDir(String path);

  static void _updateDeepestPath(String newPath) {
    if (!_deepestPathOnCurrentBranch.contains(newPath)) {
      _deepestPathOnCurrentBranch = newPath;
    }
  }

  static void _updateCurrentDirIndex(String path) {
    assert(_deepestPathOnCurrentBranch.length >= path.length);
    _currDirIndex = stripPath(path).length;
  }

  void _loadDirs(List dirsToLoad);

  //static
  static void _adjustLoadedDir() {
    List dirs = stripPath(_deepestPathOnCurrentBranch);
    List dirsToLoad = [];

    // get lists to be loaded
    for (int i = _currDirIndex - _loadedDirsOffsetFromCurrent;
        i < _currDirIndex + _loadedDirsOffsetFromCurrent;
        ++i) {
      dirsToLoad.add('/${dirs.sublist(0, i).join('/')}');
    }

    _fe._loadDirs(dirsToLoad);

    assert(_loadedDirs.length <= 2 * _loadedDirsOffsetFromCurrent + 1);
  }

  static bool cd(String path) {
    return _fe._cdDir(Directory(path));
  }

  bool _cdDir(dynamic dir);

  void _sanityCheck(String path) {
    //may need to use absolute path
    _current = path; //+ call current setter from FE
    _updateDeepestPath(path);
    _updateCurrentDirIndex(path);
    _adjustLoadedDir();
  }

  static bool isDirectory(String path) => _fe._isDirectory(path);
  bool _isDirectory(String path);

  static List<String> listCurrentDir({SortType sortType = SortType.rct}) {
    return _fe.listDir(_fe._current, sortType: sortType);
  }

  List<String> _listDir(String path, {SortType sortType = SortType.rct});
  List<String> listDir(String path, {SortType sortType = SortType.rct}) {
    assert(_isInit);
    return _fe._listDir(path, sortType: sortType);
  }

  static void _loadList(AList list) {
    if (_loadedListsQueue.length >= _loadedListsQueueSize) _popList();

    _loadedListsQueue.add(list);
  }

  static void _unloadList(String path) {
    _loadedListsQueue.removeWhere((e) => e.path == path);
  }

  static void _popList() {
    _loadedListsQueue.removeAt(0);
  }

  //load a list
  static AList? getList(String path) {
    int i = _loadedListsQueue.indexWhere((e) => e.path == path);
    AList? list = i >= 0 ? _loadedListsQueue[i] : null;

    if (list == null) {
      var rawList = _fe._loadRawListFromDisk(path);

      if (rawList != null) {
        var splittedName = _splitName(stripPath(path).last);
        list =
            AList.fromJson(splittedName.key, splittedName.value, rawList, path);
        _loadList(list);
      }
    }

    return list;
  }

  String? _loadRawListFromDisk(String path);

  static bool _isListLoaded(String path) =>
      _loadedListsQueue.any((e) => e.path == path);

  void _writeList(String path);
  static void writeList(String path) => _fe._writeList(path);

  void _createList(AList list, {String dirPath = ''});
  static void createList(AList list, {String dirPath = ''}) =>
      _fe._createList(list, dirPath: dirPath);

  static bool canRenameList(AList list, String newName, {bool rename = true}) =>
      _fe._canRenameList(list, newName);
  bool _canRenameList(AList list, String newName, {bool rename = true});

  static void createDirectory(String path, {bool cd = false}) {
    var dir = _fe._createDirectory(path);
    if (cd) _fe._cdDir(dir);
  }

  dynamic _createDirectory(String path);

  static void clearDir(String path) => _fe._clearDir(path);
  void _clearDir(String path);

  static void delete(String path) => _fe._delete(path);
  void _delete(String path);
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

class MobileFileExplorer extends FileExplorer {
  @override
  set _current(String path) => Directory.current = path;

  @override
  String get _current => Directory.current.path;

  @override
  bool _exists(String path) {
    if (Directory(path).existsSync()) return true;
    if (File(path).existsSync()) return true;
    return false;
  }

  @override
  String _toRelative(String path) =>
      '/' + path.replaceFirst(RegExp('.+/root(/|)'), '');

  @override
  dynamic _initRootPath() async {
    var dir = await getApplicationDocumentsDirectory();
    FileExplorer._rootPath = '${dir.path}/fe/root/';
    print('initroot');
  }

  @override
  bool _isDirectory(String path) => Directory(path).existsSync() ? true : false;

  @override
  bool _isDirLoaded(String path) {
    return FileExplorer._loadedDirs
        .firstWhere((e) => e is Directory && e.path == path,
            orElse: () => Directory(''))
        .path
        .isNotEmpty;
  }

  @override
  void _unloadDir(String path) {
    FileExplorer._loadedDirs
        .removeWhere((e) => e is Directory && e.path == path);
  }

  @override
  void _loadDirs(List dirsToLoad) {
    for (var e in FileExplorer._loadedDirs) {
      if (!dirsToLoad.contains(e.path) && dirsToLoad.isNotEmpty) {
        e = Directory(dirsToLoad.removeLast());
      }
    }
  }

  @override
  bool _cdDir(dynamic dir) {
    String path = dir.path;

    if (!dir.existsSync() ||
        (Directory.current.path.endsWith('/root') &&
            !path.contains(Directory.current.path))) {
      return false;
    }
    if (!_isDirLoaded(path)) FileExplorer._loadedDirs.add(dir);

    _sanityCheck(path);

    return true;
  }

  @override
  List<String> _listDir(String path, {SortType sortType = SortType.rct}) {
    List<String> ret = [];
    late Directory dir;
    !_isDirLoaded(path)
        ? dir = Directory(path)
        : dir = FileExplorer._loadedDirs.firstWhere((e) => e.path == path);
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
        stderr.write(e.message);
        stderr.write(Directory.current);
      }
    }
    return ret;
  }

  @override
  String? _loadRawListFromDisk(String path) {
    var tmp = File(path);
    if (tmp.existsSync()) {
      return tmp.readAsStringSync();
    }

    return null;
  }

  @override
  void _createList(AList list, {String dirPath = ''}) {
    File file = File('$dirPath${list.uniqueName}');

    list.path = file.absolute.path;
    print('new list: ${list.path}');
    FileExplorer._loadList(list);
    print('is loaded : ${FileExplorer._isListLoaded(list.path)}');
  }

  @override
  void _writeList(String path) {
    if (!FileExplorer._isListLoaded(path)) return;

    File file = File(path);
    if (!file.existsSync()) {
      file.createSync();
    }
    assert(FileExplorer._isListLoaded(path));
    //we suppose the list is already load
    AList list =
        FileExplorer._loadedListsQueue.firstWhere((e) => e.path == path);
    file.writeAsStringSync(jsonEncode(list.toJson()));
  }

  @override
  bool _canRenameList(AList list, String newName, {bool rename = true}) {
    String oldName = list.name;
    bool ret = true;
    list.name = newName;

    File file = File(list.path);
    ret = (newName == oldName) || !file.existsSync();
    if (!rename || !ret) list.name = oldName;
    print('name: ${list.name} $newName');
    return true;
  }

  @override
  dynamic _createDirectory(String path) =>
      Directory(path)..createSync(recursive: true);
  //dynamic _createDirectory(String path) {
  //  Directory dir = Directory(path);
  //  dir.createSync(recursive: true);
  //  print('path : $path --> ${dir.path}');
//
  //  return dir;
  //}

  @override
  void _clearDir(String path) {
    var dir = Directory(path);
    print('delete path: $path');
    if (dir.existsSync()) {
      dir.listSync().forEach((e) => e.deleteSync());
    }
  }

  @override
  void _delete(String path) {
    var item = _isDirectory(path) ? Directory(path) : File(path);

    if (item is File && FileExplorer._isListLoaded(path)) {
      FileExplorer._unloadList(path);
    } else if (_isDirLoaded(path)) {
      _unloadDir(path);
    }

    item.delete(recursive: true);
  }
}

class WebFileExplorer extends FileExplorer {
  String _curr = '';

  @override
  set _current(String path) => _curr = path;

  @override
  String get _current => _curr;

  @override
  bool _exists(String path) => true;

  @override
  String _toRelative(String path) => _curr;

  @override
  dynamic _initRootPath() async {
    //var dir = await getApplicationDocumentsDirectory();
    //var _rootPath = '${dir.path}/fe/root/';
    //_createDirectory(_rootPath, cd: true);
  }

  @override
  bool _isDirectory(String path) {
    return true;
  }

  @override
  bool _isDirLoaded(String path) {
    return true;
  }

  @override
  void _unloadDir(String path) {}

  @override
  void _loadDirs(List dirsToLoad) {}

  @override
  bool _cdDir(dynamic dir) {
    return true;
  }

  @override
  String? _loadRawListFromDisk(String path) {}

  @override
  List<String> _listDir(String path, {SortType sortType = SortType.rct}) {
    return [];
  }

  void _createList(AList list, {String dirPath = ''}) {}

  @override
  void _writeList(String path) {
    if (FileExplorer._isListLoaded(path)) return;
  }

  bool _canRenameList(AList list, String newName, {bool rename = true}) {
    return true;
  }

  @override
  dynamic _createDirectory(String path, {bool cd = false}) {}
  void _clearDir(String path) {}

  void _delete(String path) {}
}

class DataLoader {
  static bool _isDataLoaded = false;

  static load({bool force = false}) async {
    if (_isDataLoaded && !force) return;
    await FileExplorer.init(kIsWeb ? WebFileExplorer() : MobileFileExplorer());
    _isDataLoaded = true;
    //await Future.delayed(const Duration(seconds: 2));
  }
}
