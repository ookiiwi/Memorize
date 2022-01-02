import 'dart:collection';
import 'dart:math';
import 'dart:io';
import 'dart:convert';

import 'package:tuple/tuple.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

abstract class AFile {
  AFile(this._parent, this.name);

  final dynamic _parent;
  String name;
  get parent => _parent;
}

class ACategory extends AFile {
  ACategory(dynamic parent, String name)
      : _table = {},
        super(parent, name);

  ACategory.fromJson(dynamic parent, String name, Map<String, dynamic> json)
      : _table = Set.from(json['table']),
        super(parent, name);

  Map<String, dynamic> toJson() => {"table": _table.toList()};

  final Set<int> _table;

  bool contains(int id) {
    return _table.contains(id);
  }

  bool add(int id) {
    return _table.add(id);
  }

  bool delete(int id) {
    return _table.remove(id);
  }

  Set getTable() {
    return Set.from(_table);
  }
}

class AList extends AFile {
  AList(dynamic parent, String name) : super(parent, name);
  AList.from(AList list)
      : _content = List.from(list._content),
        super(list.parent, list.name);

  AList.fromJson(dynamic parent, String name, Map<String, dynamic> json)
      : _content = List.from(json["content"]),
        super(parent, name);

  Map<String, dynamic> toJson() => {"content": _content};

  List<Tuple2<String, String>> _content = [];

  bool contains(Tuple2<String, String>? element) {
    return _content.contains(element);
  }

  bool containsAll(List elements) {
    for (var e in elements) {
      if (!_content.contains(e)) {
        return false;
      }
    }

    return true;
  }

  void add(Tuple2<String, String> item) {
    _content.add(item);
  }

  void addAll(List<Tuple2<String, String>> items) {
    _content.addAll(items);
  }

  Tuple2 delete(int index) {
    return _content.removeAt(index);
  }
}

class AQuiz extends AFile {
  AQuiz(dynamic parent, String name, this.lists, Map<String, dynamic> options)
      : _options = options,
        super(parent, name);

  AQuiz.fromJson(dynamic parent, String name, Map<String, dynamic> json)
      : lists = json["lists"],
        _options = json["options"],
        super(parent, name);

  Map<String, dynamic> toJson() => {"lists": lists, "options": _options};

  List lists;
  final Map<String, dynamic> _options;

  // Move to quiz widget
  List<Tuple2<String, String>> mix(bool elt, bool lines,
      {List<Tuple2<String, String>> selection = const []}) {
    if (selection.isEmpty) {
      selection = List.from(lists);
    }

    List _mix(List ls) {
      List it = List.from(ls);
      var dist = Random();
      for (int i = 0; i < it.length; i++) {
        int n = dist.nextInt(it.length);
        var tmp = it[i];
        it[i] = it[n];
        it[n] = tmp;
      }

      return it;
    }

    if (elt) {
      for (var e in selection) {
        List tmp = _mix([e.item1, e.item2]);
        e = Tuple2.fromList(tmp);
      }
    }

    return selection;
  }
}

enum DataType { category, list, quiz }

class FileExplorerData {
  ///if [filename] exist, data in it is used in initialization
  FileExplorerData(String filename, Directory localDir)
      : _itemsHeaders = SplayTreeMap(),
        _idPtr = -1,
        _headersFilename = localDir.path + filename,
        _localDir = localDir {
    _itemsHeaders = SplayTreeMap(compare, (a) => a > 0);
    add(ACategory(null, 'root'));
    FileExplorerData._loadData(this);

    int? maxId = _itemsHeaders.lastKey();
    if (maxId != null) _idPtr = FileExplorerData._removeTypeFromId(maxId);

    assert(_idPtr > -2);
  }

  SplayTreeMap<int, Tuple2<int, String>> _itemsHeaders;
  final Map<int, AFile> _idTable = <int, AFile>{}; // loaded items
  int _idPtr;
  static final int _idTypeShift = 63 - DataType.values.last.index;
  final String _headersFilename;
  final List<int> navHistory = [];
  final Directory _localDir;
  int _wd = 0;
  int get wd => _wd;

  Future<bool> cd(int id) async {
    bool ret = await _loadItem(id);
    if (ret) _wd = id;
    return ret;
  }

  /// Compare ids stripped of their type using 'compareTo' method
  static int compare(int a, int b) {
    return _removeTypeFromId(a).compareTo(_removeTypeFromId(b));
  }

  void clearHistory({int start = 0}) {
    navHistory.removeRange(start, navHistory.length);
  }

  void clearCache() {
    File jsonFile = File(_headersFilename);

    deleteAll(_itemsHeaders.keys.toList());
    jsonFile.deleteSync();
    navHistory.clear();
  }

  static Map<String, dynamic> _headersToJson(
      SplayTreeMap<int, Tuple2<int, String>> headers) {
    Map<String, dynamic> ret = <String, dynamic>{};

    headers.forEach((key, value) {
      ret[key.toString()] = [value.item1.toString(), value.item2];
    });

    return ret;
  }

  static SplayTreeMap<int, Tuple2<int, String>> _headersFromJson(
      Map<String, dynamic> json) {
    SplayTreeMap<int, Tuple2<int, String>> ret = SplayTreeMap(compare);

    json.forEach((key, value) {
      ret[int.parse(key)] = Tuple2(int.parse(value[0]), value[1]);
    });

    return ret;
  }

  /// Load [FileExplorerData] data if the a data file exists
  static Future<bool> _loadData(FileExplorerData data) async {
    File jsonFile = File(data._headersFilename);

    if (!jsonFile.existsSync()) {
      return false;
    }

    //TODO: check file is valid
    Map<String, dynamic> json = jsonDecode(jsonFile.readAsStringSync());
    data._itemsHeaders.addAll(_headersFromJson(json));

    // init root table
    ACategory root = await data.get(0);

    data._itemsHeaders.forEach((key, value) {
      if (value.item1 == 0 && !root.getTable().contains(key)) root.add(key);
    });

    return true;
  }

  /// Save all headers in a single file
  void _saveHeaders() {
    File headerFile = File(_headersFilename);

    headerFile.writeAsStringSync(
        jsonEncode(FileExplorerData._headersToJson(_itemsHeaders)));
  }

  /// Save an item on the disk
  void _saveItem(int id) async {
    assert(id != 0, "Root must not be serialized");

    File dataFile = File("${_localDir.path}/$id");
    AFile? item = _idTable[id];

    if (item != null) {
      if (!_itemsHeaders.containsKey(id)) {
        _itemsHeaders[id] = Tuple2(item.parent, item.name);
        _saveHeaders();
      }

      dataFile.writeAsStringSync(jsonEncode(item));
    }
  }

  /// Delete an item from the disk if it exists
  void _delete(int id) {
    File file = File("${_localDir.path}/$id");

    if (file.existsSync()) file.delete();
  }

  /// Load item from disk and add it to the id table
  Future<bool> _loadItem(int id) async {
    if (_idTable.containsKey(id)) return true;

    File file = File("${_localDir.path}/$id");

    if (!_itemsHeaders.containsKey(id) || !file.existsSync()) {
      print('Cannot load $id');
      return false;
    }

    String jsonString = file.readAsStringSync();
    DataType dt = FileExplorerData.getTypeFromId(id);
    AFile item;

    // TODO: simplify/change this ugly ass bitch
    switch (dt) {
      case DataType.category:
        item = ACategory.fromJson(_itemsHeaders[id]!.item1,
            _itemsHeaders[id]!.item2, jsonDecode(jsonString));

        break;
      case DataType.list:
        item = AList.fromJson(_itemsHeaders[id]!.item1,
            _itemsHeaders[id]!.item2, jsonDecode(jsonString));

        break;
      default:
        item = AQuiz.fromJson(_itemsHeaders[id]!.item1,
            _itemsHeaders[id]!.item2, jsonDecode(jsonString));
    }

    _idTable[id] = item;

    return true;
  }

  bool unloadItem(int id) {
    //Don't remove root from id table !!!
    return (id == 0) || _idTable.remove(id) != null ? true : false;
  }

  void unloadItems(List<int> ids) {
    for (int id in ids) {
      unloadItem(id);
    }
  }

  /// Generate an id on 64 bits
  /// The 'DataType.last.index' last bits are for the type
  int _genId(DataType dt) {
    int ret = ++_idPtr;

    if (ret > pow(2, _idTypeShift)) {
      throw Exception("Id must be $_idTypeShift bits -- $ret");
    }

    ret = (dt.index << _idTypeShift) | ret;

    assert(!_itemsHeaders.containsKey(ret),
        "$ret already assigned to ${_itemsHeaders[ret]!.item2}");

    return ret;
  }

  static int _removeTypeFromId(int id) {
    return (id & -1 << _idTypeShift) ^ id;
  }

  static DataType getTypeFromId(int id) {
    return DataType.values.firstWhere((e) => e.index == id >> _idTypeShift);
  }

  /// Returns a set of invalid ids
  Set checkIds(Set ids) {
    return ids.difference(Set.from(_itemsHeaders.keys));
  }

  Future<int> add(AFile item) async {
    // TODO: guess type outside class
    DataType type = item is ACategory
        ? DataType.category
        : (item is AList ? DataType.list : DataType.quiz);

    int id = _genId(type);
    _idTable[id] = item;

    if (id > 0) _saveItem(id);

    await _updateParent(item.parent, id);

    return id;
  }

  Future<void> _updateParent(int? pid, int id) async {
    // ignore if root
    if (pid != null) {
      ACategory parent = await get(pid);
      parent.add(id);

      if (pid != 0) _saveItem(pid);
    }
  }

  Future<bool> delete(int id) async {
    if (id == 0) {
      throw Exception("Root category must not be removed");
    }

    if (getTypeFromId(id) == DataType.category) {
      ACategory? cat = await get(id);

      if (cat != null) {
        Set table = cat.getTable();
        for (var e in table) {
          await delete(e);
        }
      }
    }

    Tuple2<int, String>? ret = _itemsHeaders.remove(id);

    // remove id from parent
    if (ret != null) {
      _idTable.remove(id);

      ACategory parent = await get(ret.item1);
      parent.delete(id);

      if (navHistory.contains(id)) clearHistory(start: navHistory.indexOf(id));

      ret.item1 != 0
          ? _saveItem(ret.item1)
          : _saveHeaders(); //_saveHeaders already called in _saveItem

      _delete(id);

      return true;
    }

    return false;
  }

  void deleteAll(List<int> ids) {
    for (int id in ids) {
      delete(id);
    }
  }

  Future get(int id) async {
    if (!_idTable.containsKey(id)) {
      await _loadItem(id);
    }
    return _idTable[id];
  }

  String? getName(int id) {
    return (id == 0) ? 'Root' : _itemsHeaders[id]?.item2;
  }

  int? getParent(int id) {
    return _itemsHeaders[id]?.item1;
  }
}

class UserData {
  static FileExplorerData? _listData;
  static FileExplorerData? _quizData;

  static bool _init = false;

  static get listData => _check(_listData);
  static get quizData => _check(_quizData);

  static _check(dynamic value) {
    if (!_init) {
      throw Exception("UserData must be initialized before it can be used");
    }

    return value;
  }

  static Future<void> init() async {
    if (_init) return;

    final localPath = await _getLocalDir();
    _init = true;
    _listData = FileExplorerData("list_data", localPath);
    _quizData = FileExplorerData("quiz_data", localPath);
  }

  static Future<Directory> _getLocalDir() async {
    return await getApplicationDocumentsDirectory();
  }
}

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

Future<void> loadInitialData() async {
  await UserData.init();
}
